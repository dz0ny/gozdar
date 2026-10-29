// Draw the images of one PDF page onto one grey raster.
// Scanned notices are only images, so this replaces a full PDF renderer.
// Office scanners split a page into a background image and black text masks.
// This file draws both, in page order, with the page transforms.

// Multiply two PDF matrices [a, b, c, d, e, f].
function mul(m, n) {
  return [
    m[0] * n[0] + m[2] * n[1],
    m[1] * n[0] + m[3] * n[1],
    m[0] * n[2] + m[2] * n[3],
    m[1] * n[2] + m[3] * n[3],
    m[0] * n[4] + m[2] * n[5] + m[4],
    m[1] * n[4] + m[3] * n[5] + m[5],
  ];
}

// Get the grey value of one source pixel, or null for a pixel to skip.
function sampler(img, isMask) {
  const { width, data } = img;
  if (isMask) {
    // A mask has 1 bit per pixel, rows padded to bytes. A 0 bit makes black.
    const row = (width + 7) >> 3;
    return (x, y) => ((data[y * row + (x >> 3)] >> (7 - (x & 7))) & 1 ? null : 0);
  }
  if (img.kind === 1) {
    const row = (width + 7) >> 3;
    return (x, y) => ((data[y * row + (x >> 3)] >> (7 - (x & 7))) & 1 ? 255 : 0);
  }
  const ch = img.kind === 3 ? 4 : 3;
  return (x, y) => {
    const i = (y * width + x) * ch;
    return (data[i] * 299 + data[i + 1] * 587 + data[i + 2] * 114) / 1000;
  };
}

// Draw one image into the raster. The matrix maps the unit square to pixels.
// Each target pixel keeps the darkest source pixel, so thin text stays black.
function draw(out, W, H, m, img, isMask) {
  const get = sampler(img, isMask);
  const { width: iw, height: ih } = img;
  const xs = [m[4], m[0] + m[4], m[2] + m[4], m[0] + m[2] + m[4]];
  const ys = [m[5], m[1] + m[5], m[3] + m[5], m[1] + m[3] + m[5]];
  const x0 = Math.max(0, Math.floor(Math.min(...xs)));
  const x1 = Math.min(W, Math.ceil(Math.max(...xs)));
  const y0 = Math.max(0, Math.floor(Math.min(...ys)));
  const y1 = Math.min(H, Math.ceil(Math.max(...ys)));
  const det = m[0] * m[3] - m[1] * m[2];
  if (!det || x0 >= x1 || y0 >= y1) return;
  // The inverse matrix maps a pixel back to unit coordinates.
  const ia = m[3] / det, ib = -m[1] / det, ic = -m[2] / det, id = m[0] / det;
  // Source pixels that one target pixel covers, along each axis.
  const spanX = Math.max(1, Math.ceil(iw / Math.abs(m[0] || m[2] || 1)));
  const spanY = Math.max(1, Math.ceil(ih / Math.abs(m[3] || m[1] || 1)));
  for (let py = y0; py < y1; py++) {
    for (let px = x0; px < x1; px++) {
      const dx = px - m[4], dy = py - m[5];
      const u = ia * dx + ic * dy;
      const v = ib * dx + id * dy;
      if (u < 0 || u >= 1 || v < 0 || v >= 1) continue;
      // Image row 0 is at the top of the unit square, where v is 1.
      const sx = Math.floor(u * iw);
      const sy = Math.floor((1 - v) * ih);
      let dark = null;
      for (let y = sy; y < Math.min(ih, sy + spanY); y++) {
        for (let x = sx; x < Math.min(iw, sx + spanX); x++) {
          const g = get(x, y);
          if (g !== null && (dark === null || g < dark)) dark = g;
        }
      }
      if (dark === null) continue;
      const i = py * W + px;
      // A mask paints black on top. An image replaces what is below it.
      out[i] = isMask ? Math.min(out[i], dark) : dark;
    }
  }
}

// Get a decoded object of the page by its name.
function getObj(page, name) {
  return new Promise((resolve) => {
    if (page.objs.has(name)) resolve(page.objs.get(name));
    else page.objs.get(name, resolve);
  });
}

// Draw one page as grey pixels. The longest side gets `maxSide` pixels.
export async function rasterPage(pdfjs, page, maxSide) {
  const { OPS } = pdfjs;
  const [vx0, vy0, vx1, vy1] = page.view;
  const s = maxSide / Math.max(vx1 - vx0, vy1 - vy0);
  const W = Math.round((vx1 - vx0) * s);
  const H = Math.round((vy1 - vy0) * s);
  const out = new Uint8Array(W * H).fill(255);
  const ops = await page.getOperatorList();
  // PDF space has y up. The raster has y down.
  let ctm = [s, 0, 0, -s, -vx0 * s, vy1 * s];
  const stack = [];
  let drawn = 0;
  for (let i = 0; i < ops.fnArray.length; i++) {
    const fn = ops.fnArray[i];
    const args = ops.argsArray[i];
    if (fn === OPS.save) stack.push(ctm);
    else if (fn === OPS.restore) ctm = stack.pop() ?? ctm;
    else if (fn === OPS.transform) ctm = mul(ctm, args);
    else if (fn === OPS.paintImageXObject) {
      draw(out, W, H, ctm, await getObj(page, args[0]), false);
      drawn++;
    } else if (fn === OPS.paintImageMaskXObject) {
      const m = args[0];
      const obj = typeof m.data === 'string' ? await getObj(page, m.data) : m;
      draw(out, W, H, ctm, obj, true);
      drawn++;
    }
  }
  return drawn ? { width: W, height: H, data: out } : null;
}
