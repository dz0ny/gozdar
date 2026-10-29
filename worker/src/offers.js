// Sale offers for farmland and forest from the e-uprava notice board.
// The board calls them "Ponudba za kmetijsko zemljišče".
// Each administrative unit posts the offer as a scanned PDF.

// A cron run scrapes the list and renders each new PDF to images.
// A Workers AI vision model reads the parcels and the price.
// R2 keeps each result for good, because a posted offer does not change.
// The app reads one small list from GET /api/offers.
import { extractText, getDocumentProxy, getResolvedPDFJS } from 'unpdf';
import { encode as encodePng } from 'fast-png';
import { rasterPage } from './raster.js';

const BASE = 'https://e-uprava.gov.si';
const LIST =
  `${BASE}/si/e-uprava/oglasnadeska/content/singleton.html?lang=si&type=PKZ` +
  '&perioda=-&rijs=-1&offset=0&sentinel_type=ok&sentinel_status=ok' +
  '&is_ajax=1&complete=false&page=';
const DETAIL = `${BASE}/si/e-uprava/oglasnadeska/podrobnosti-objave.html?id=`;
const FILE = `${BASE}/.download/oglasna/datoteka?disposition=attachment&file=`;

const MODEL = '@cf/meta/llama-4-scout-17b-16e-instruct';
const PREFIX = 'offers/';
const INDEX_KEY = `${PREFIX}index.json`;

// List pages to scan per run. Each page has 50 offers, newest first.
const LIST_PAGES = 18;

// New offers to read per run. About 25 offers come each day.
const PER_RUN = 40;

// Reads of one offer before the cron stops to try it.
const MAX_ATTEMPTS = 2;

// The GURS valuation register. It confirms a parcel and gives its area.
const GURS = 'https://vrednotenje.gov.si/EV_Javni_Server';

// Pages of one PDF to send to the model. Notices list parcels early.
const MAX_PAGES = 3;

// Longest side of the image for the model, in pixels.
const MAX_SIDE = 1800;

// Offers stay on the board for 15 to 30 days. This adds a margin.
const ACTIVE_DAYS = 35;

const HEADERS = { 'User-Agent': 'gozdar-proxy (+https://gozdar.app)' };

const SCHEMA = {
  type: 'object',
  properties: {
    kind: { type: 'string', enum: ['prodaja', 'zakup', 'drugo'] },
    parcels: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          ko_code: { type: ['integer', 'null'] },
          ko_name: { type: ['string', 'null'] },
          parcel: { type: 'string' },
          area_m2: { type: ['number', 'null'] },
          land_use: { type: ['string', 'null'] },
        },
        required: ['parcel'],
      },
    },
    price_eur: { type: ['number', 'null'] },
    price_text: { type: ['string', 'null'] },
  },
  required: ['kind', 'parcels'],
};

const PROMPT = `Dokument je slovenski uradni obrazec "Ponudba za prodajo kmetijskega zemljišča, gozda ali kmetije".
Obrazec ima tabelo s stolpci: Parcelna številka | Katastrska občina | Površina (m²) | Cena (EUR) | V zakupu.
Katastrska občina je zapisana kot številka in ime, npr. "432 SP. JABLANE".
Pod tabelo je "Cena skupaj".

Vrni JSON:
- kind: "prodaja", "zakup" ali "drugo"
- parcels: ena vrstica tabele je en element: parcel (samo parcelna številka, npr. "334" ali "610/8"), ko_code (številka k.o.), ko_name (ime k.o.), area_m2 (površina kot število, "9.029" pomeni 9029), land_use (raba, če je navedena)
- price_eur: "Cena skupaj" kot število, "45.200,00" pomeni 45200
- price_text: drugi prodajni pogoji, kratko

Ne prepisuj osebnih podatkov prodajalca. Česar ni v dokumentu, vrni null.`;

// ---------------------------------------------------------------------------
// Scraping

function decodeHtml(s) {
  return s
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

// Change "29. 10. 2026" to "2026-10-29".
function isoDate(s) {
  const m = /(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4})/.exec(s ?? '');
  if (!m) return null;
  return `${m[3]}-${m[2].padStart(2, '0')}-${m[1].padStart(2, '0')}`;
}

// Get the offers on one list page: id, unit, number, title and date.
export function parseList(html) {
  const out = [];
  const box =
    /<div class="lessImportant allCaps">([^<]+)<\/div>\s*<div class="allCaps"><a href="[^"]*id=(\d+)">([^<]+)<\/a><\/div>\s*<div class="allCaps">([^<]*)<\/div>\s*<div[^>]*>\s*Objavljeno:\s*([\d. ]+)/g;
  for (const m of html.matchAll(box)) {
    out.push({
      id: m[2],
      unit: decodeHtml(m[1]),
      number: decodeHtml(m[3]).replace(/^Ponudba za kmetijsko zemljišče št\.\s*/i, ''),
      title: decodeHtml(m[4]),
      published: isoDate(m[5]),
    });
  }
  return out;
}

// Get the "objava do" date and the attachment ids from an offer page.
export function parseDetail(html) {
  const until = /objava do\s*([\d. ]+)/i.exec(html);
  const files = [...new Set([...html.matchAll(/datoteka\?file=(\d+)/g)].map((m) => m[1]))];
  return { until: isoDate(until?.[1]), files };
}

// Get the KO codes and names from a title, for example "k.o. 2596 Tinjan".
export function kosFromTitle(title) {
  const kos = [];
  const re = /k\.\s*o\.\s*(\d{3,4})?\s*[-–]?\s*([A-ZČŠŽĆĐ][A-ZČŠŽĆĐa-zčšžćđ .]*?)(?=,|\s+in\s+|\s+ter\s+|\)|;|$)/gi;
  for (const m of title.matchAll(re)) {
    const name = m[2]?.trim().replace(/\.$/, '');
    kos.push({ code: m[1] ? Number(m[1]) : null, name: name || null });
  }
  return kos;
}

async function fetchText(url) {
  const res = await fetch(url, { headers: HEADERS });
  if (!res.ok) throw new Error(`${url} -> ${res.status}`);
  return res.text();
}

// ---------------------------------------------------------------------------
// PDF to images to model

// Encode grey pixels as a PNG data URI.
function toPngDataUri(img) {
  const png = encodePng({ ...img, channels: 1, depth: 8 });
  let bin = '';
  for (let i = 0; i < png.length; i += 0x8000) {
    bin += String.fromCharCode(...png.subarray(i, i + 0x8000));
  }
  return `data:image/png;base64,${btoa(bin)}`;
}

// Get the text of a PDF, or an image of each of its first pages.
async function readPdf(bytes) {
  const pdf = await getDocumentProxy(new Uint8Array(bytes));
  const { text } = await extractText(pdf, { mergePages: true });
  // Some notices have a text layer. They do not need the vision model.
  if (text && text.replace(/\s/g, '').length > 200) {
    return { text: text.slice(0, 20000), images: [] };
  }
  const pdfjs = await getResolvedPDFJS();
  const images = [];
  for (let p = 1; p <= Math.min(pdf.numPages, MAX_PAGES); p++) {
    const raster = await rasterPage(pdfjs, await pdf.getPage(p), MAX_SIDE);
    if (raster) images.push(toPngDataUri(raster));
  }
  return { text: null, images };
}

function parseAnswer(result) {
  const raw =
    result?.response ?? result?.choices?.[0]?.message?.content ?? result;
  if (raw && typeof raw === 'object') return raw;
  const s = String(raw ?? '');
  try {
    return JSON.parse(s.slice(s.indexOf('{'), s.lastIndexOf('}') + 1));
  } catch {
    throw new Error(`model answer is not JSON: ${JSON.stringify(result).slice(0, 400)}`);
  }
}

async function askModel(env, content, model = MODEL) {
  const result = await env.AI.run(model, {
    messages: [
      { role: 'system', content: PROMPT },
      { role: 'user', content },
    ],
    guided_json: SCHEMA,
    max_tokens: 2048,
    temperature: 0,
    // Long parcel numbers like "334/1" can make a model repeat "/1" forever.
    frequency_penalty: 0.3,
  });
  return parseAnswer(result);
}

// Keep a parcel only when its number looks like "334" or "610/8".
// The model can add text or repeat parts, so this takes the first match.
export function cleanParcel(p) {
  const m = /\d{1,5}(?:\/\d{1,4})?/.exec(String(p?.parcel ?? ''));
  if (!m) return null;
  const code = Number.parseInt(p.ko_code, 10);
  const area = typeof p.area_m2 === 'number' ? p.area_m2 : Number.parseFloat(p.area_m2);
  return {
    parcel: m[0],
    ko_code: Number.isFinite(code) && code > 0 && code < 10000 ? code : null,
    ko_name: p.ko_name ? String(p.ko_name).trim() : null,
    area_m2: Number.isFinite(area) && area > 0 ? area : null,
    land_use: p.land_use ? String(p.land_use).trim() : null,
  };
}

// Read the parcels, the kind and the price from the attachments of an offer.
export async function readOffer(env, fileIds, model = MODEL) {
  const parcels = [];
  let kind = null;
  let price = null;
  let priceText = null;
  for (const fid of fileIds.slice(0, 2)) {
    const res = await fetch(FILE + fid, { headers: HEADERS });
    if (!res.ok) continue;
    const doc = await readPdf(await res.arrayBuffer());
    const parts = doc.text
      ? [[{ type: 'text', text: doc.text }]]
      : doc.images.map((url) => [
          { type: 'text', text: 'Stran objave:' },
          { type: 'image_url', image_url: { url } },
        ]);
    for (const content of parts) {
      const a = await askModel(env, content, model);
      kind ??= a.kind ?? null;
      price ??= typeof a.price_eur === 'number' ? a.price_eur : null;
      priceText ??= a.price_text ?? null;
      for (const p of a.parcels ?? []) {
        const clean = cleanParcel(p);
        if (clean) parcels.push(clean);
      }
    }
  }
  // A row can lose its KO. The other rows of the same offer give it.
  const known = parcels.find((p) => p.ko_code);
  for (const p of parcels) {
    if (!p.ko_code && known) {
      p.ko_code = known.ko_code;
      p.ko_name ??= known.ko_name;
    }
  }
  return { kind, parcels, price_eur: price, price_text: priceText };
}

// ---------------------------------------------------------------------------
// Check the parcels against the GURS register

const koCache = new Map();

// Get the KO code for a KO name, for example "TRBOJE" gives 2126.
async function koCode(name) {
  const key = String(name ?? '').trim().toUpperCase();
  if (!key) return null;
  if (!koCache.has(key)) {
    const res = await fetch(`${GURS}/system/obcina/search?ime=${encodeURIComponent(key)}`, {
      headers: { ...HEADERS, Accept: 'application/json' },
    });
    const rows = res.ok ? await res.json() : [];
    const hit = rows.find((r) => r.ime === key) ?? (rows.length === 1 ? rows[0] : null);
    koCache.set(key, hit?.koId ?? null);
  }
  return koCache.get(key);
}

// Get the GURS row for a parcel in a KO, or null if the parcel is not there.
async function gursParcel(ko, parcel) {
  const q = new URLSearchParams({ count: '5', offset: '0', parcela: parcel, koSifko: String(ko) });
  const res = await fetch(`${GURS}/podatki/parcela/search?${q}`, {
    headers: { ...HEADERS, Accept: 'application/json' },
  });
  if (!res.ok) return null;
  const rows = await res.json();
  return rows.find((r) => String(r.parcela).trim() === parcel) ?? null;
}

// Find each parcel in the GURS register. Try each KO the offer names.
// The model sometimes adds "/1", so try the number without it too.
// A found parcel gets the KO code and the area from GURS.
export async function verifyParcels(parcels, titleKos) {
  const kos = [];
  const add = (code) => {
    if (code && !kos.includes(code)) kos.push(code);
  };
  for (const k of titleKos) add(k.code ?? (await koCode(k.name)));
  for (const p of parcels) add(p.ko_code ?? (await koCode(p.ko_name)));
  const out = [];
  for (const p of parcels) {
    const numbers = [p.parcel];
    const base = p.parcel.replace(/\/1$/, '');
    if (base !== p.parcel) numbers.push(base);
    const order = p.ko_code ? [p.ko_code, ...kos.filter((k) => k !== p.ko_code)] : kos;
    let hit = null;
    for (const ko of order) {
      for (const n of numbers) {
        const row = await gursParcel(ko, n);
        if (row) {
          hit = { ...p, parcel: n, ko_code: ko, area_m2: Number(row.povrsina), verified: true };
          break;
        }
      }
      if (hit) break;
    }
    out.push(hit ?? { ...p, verified: false });
  }
  // The same parcel can come from two pages or two attachments.
  const seen = new Set();
  return out.filter((p) => {
    const key = `${p.ko_code}/${p.parcel}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

// ---------------------------------------------------------------------------
// R2 store and cron

async function getJson(env, key) {
  const obj = await env.TILES_BUCKET.get(key);
  return obj ? obj.json() : null;
}

async function putJson(env, key, value) {
  await env.TILES_BUCKET.put(key, JSON.stringify(value), {
    httpMetadata: { contentType: 'application/json' },
  });
}

// Do one cron run. Scan the newest list pages.
// Read each new offer once. A failed read gets MAX_ATTEMPTS tries in all.
// Then make the index of active offers again from R2.
export async function refreshOffers(env) {
  const listed = [];
  for (let p = 0; p < LIST_PAGES; p++) {
    const page = parseList(await fetchText(LIST + p));
    listed.push(...page);
    if (page.length === 0) break;
  }
  const cutoff = new Date(Date.now() - ACTIVE_DAYS * 864e5).toISOString().slice(0, 10);
  const active = listed.filter((o) => !o.published || o.published >= cutoff);

  let read = 0;
  let failed = 0;
  const offers = [];
  for (const o of active) {
    const key = `${PREFIX}${o.id}.json`;
    let stored = await getJson(env, key);
    const retry = stored?.status === 'failed' && (stored.attempts ?? 0) < MAX_ATTEMPTS;
    if ((!stored || retry) && read < PER_RUN) {
      read++;
      const attempts = (stored?.attempts ?? 0) + 1;
      const kos = kosFromTitle(o.title);
      try {
        const detail = parseDetail(await fetchText(DETAIL + o.id));
        const content = await readOffer(env, detail.files);
        const parcels = await verifyParcels(content.parcels, kos);
        stored = {
          ...o,
          until: detail.until,
          files: detail.files,
          kos,
          ...content,
          parcels,
          status: 'read',
          attempts,
          read_at: new Date().toISOString(),
          model: MODEL,
        };
      } catch (e) {
        failed++;
        console.error(`offer ${o.id}: ${e.message}`);
        stored = { ...o, kos, parcels: null, status: 'failed', attempts, error: e.message };
      }
      await putJson(env, key, stored);
    }
    // An offer that is not read yet shows the title data. Parcels come later.
    offers.push(stored ?? { ...o, kos: kosFromTitle(o.title), parcels: null, status: 'new' });
  }
  const index = { updated: new Date().toISOString(), offers };
  await putJson(env, INDEX_KEY, index);
  return { listed: listed.length, active: offers.length, read, failed };
}

// ---------------------------------------------------------------------------
// HTTP

export async function getOffers(c) {
  const index = await getJson(c.env, INDEX_KEY);
  if (!index) return c.json({ updated: null, offers: [] });
  c.header('Cache-Control', 'public, max-age=1800');
  return c.json(index);
}

// Read one offer now, to check the reading by hand. There is no cache.
export async function debugOffer(c) {
  const id = c.req.param('id');
  const detail = parseDetail(await fetchText(DETAIL + id));
  // With ?md=1, show what Workers AI toMarkdown makes of the PDF.
  if (c.req.query('md')) {
    const res = await fetch(FILE + detail.files[0], { headers: HEADERS });
    const blob = new Blob([await res.arrayBuffer()], { type: 'application/pdf' });
    const out = await c.env.AI.toMarkdown([{ name: 'offer.pdf', blob }]);
    return c.json(out);
  }
  // With ?page=N, show the image of page N that the model gets.
  const page = Number(c.req.query('page'));
  if (page > 0) {
    const res = await fetch(FILE + detail.files[0], { headers: HEADERS });
    const doc = await readPdf(await res.arrayBuffer());
    const url = doc.images[page - 1];
    if (!url) return c.json({ text: doc.text, images: doc.images.length });
    const bytes = Uint8Array.from(atob(url.split(',')[1]), (ch) => ch.charCodeAt(0));
    return c.body(bytes, 200, { 'Content-Type': 'image/png' });
  }
  const model = c.req.query('model') ?? MODEL;
  const started = Date.now();
  const content = await readOffer(c.env, detail.files, model);
  const html = await fetchText(DETAIL + id);
  const title = /<h3[^>]*>([^<]*k\.\s*o\.[^<]*)</i.exec(html)?.[1] ?? c.req.query('title') ?? '';
  const parcels = await verifyParcels(content.parcels, kosFromTitle(decodeHtml(title)));
  return c.json({ id, model, ms: Date.now() - started, ...detail, ...content, parcels });
}
