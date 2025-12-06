const GEOSERVER = 'https://prostor.zgs.gov.si/geoserver/wms';
// const GEOWEBCACHE = 'https://prostor.zgs.gov.si/geowebcache/service/wms'; // Not used to allow on-the-fly rendering

// Base layers (mutually exclusive)
export const BASE_LAYERS = {
  'osm': { name: 'OpenStreetMap', external: true, url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png' },
  'otm': { name: 'OpenTopoMap', external: true, url: 'https://tile.opentopomap.org/{z}/{x}/{y}.png' },
  'esri': { name: 'ESRI Satelit', external: true, url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}' },
  'ortofoto': { name: 'Ortofoto 2024', proxy: true },
  'dof-ir': { name: 'Ortofoto IR', proxy: true },
  'dmr': { name: 'DMR (relief)', proxy: true },
};

// Overlay layers organized by category
export const OVERLAY_LAYERS = {
  'Administrativno': {
    'kataster': { name: 'Kataster' },
    'kataster-nazivi': { name: 'Kataster z nazivi' },
    'katastrske-obcine': { name: 'Katastrske obcine' },
    'obcine': { name: 'Obcine' },
    'upravne-enote': { name: 'Upravne enote' },
    'statisticne-regije': { name: 'Statisticne regije' },
    'naselja': { name: 'Naselja' },
    'hisne-stevilke': { name: 'Hisne stevilke' },
    'drzavna-meja': { name: 'Drzavna meja' },
  },
  'Infrastruktura': {
    'gozdne-ceste': { name: 'Gozdne ceste' },
    'glavne-ceste': { name: 'Glavne ceste' },
    'zeleznice': { name: 'Zeleznice' },
    'planinske-poti': { name: 'Planinske poti' },
  },
  'Gozdno gospodarstvo': {
    'sestoji': { name: 'Sestoji' },
    'odseki': { name: 'Odseki' },
    'revirji': { name: 'Revirji' },
    'gozdna-maska': { name: 'Gozdna maska' },
    'gge': { name: 'GGE' },
    'ggo': { name: 'GGO' },
  },
  'Zavarovana obmocja': {
    'gozdni-rezervati': { name: 'Gozdni rezervati' },
    'varovalni-gozdovi': { name: 'Varovalni gozdovi' },
    'natura-2000': { name: 'Natura 2000' },
    'zavarovana-obmocja': { name: 'Zavarovana obmocja' },
    'naravne-vrednote': { name: 'Naravne vrednote' },
    'ekolosko-obmocja': { name: 'Ekolosko pomembna obmocja' },
    'koridorji': { name: 'Ekoloski koridorji' },
    'ekocelice': { name: 'Ekocelice' },
    'habitatna-drevesa': { name: 'Habitatna drevesa' },
  },
  'Nevarnosti in skode': {
    'pozarna-ogrozenost': { name: 'Pozarna ogrozenost' },
    'gozdni-pozari': { name: 'Gozdni pozari' },
    'protipozarne-preseke': { name: 'Protipozarne preseke' },
    'vetrolom-2017': { name: 'Vetrolom 2017' },
    'vetrolom-2018': { name: 'Vetrolom 2018' },
    'zled-2014': { name: 'Zled 2014' },
    'podlubniki': { name: 'Podlubniki 2015-2019' },
    'krcitve': { name: 'Krcitve' },
  },
  'Funkcije gozda': {
    'lesna-proizvodnja': { name: 'Lesna proizvodnja' },
    'varovalna-funkcija': { name: 'Varovalna funkcija' },
    'rekreacija': { name: 'Rekreacija' },
  },
  'Posebno': {
    'lovisca': { name: 'Lovisca' },
  },
};

export const LAYERS = {
  // ============ BASE LAYERS ============
  'ortofoto': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:DOF_2024',
    format: 'image/jpeg',
    transparent: false,
  },
  'dof-ir': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:DOF_IR',
    format: 'image/jpeg',
    transparent: false,
  },
  'dmr': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:DMR',
    format: 'image/jpeg',
    transparent: false,
  },

  // ============ ADMINISTRATIVE ============
  'kataster': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:kn_parcele',
    styles: 'parcele',
    format: 'image/png',
    transparent: true,
  },
  'kataster-nazivi': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:kn_parcele',
    styles: 'parcele_nazivi',
    format: 'image/png',
    transparent: true,
  },
  'katastrske-obcine': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:KN_KATASTRSKE_OBCINE',
    format: 'image/png',
    transparent: true,
  },
  'obcine': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:NEP_RPE_OBCINE',
    format: 'image/png',
    transparent: true,
  },
  'upravne-enote': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:NEP_RPE_UPRAVNE_ENOTE',
    format: 'image/png',
    transparent: true,
  },
  'statisticne-regije': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:NEP_RPE_STATISTICNE_REGIJE',
    format: 'image/png',
    transparent: true,
  },
  'naselja': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:NEP_RPE_NASELJA',
    format: 'image/png',
    transparent: true,
  },
  'hisne-stevilke': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:NEP_HISNE_STEVILKE',
    format: 'image/png',
    transparent: true,
  },
  'drzavna-meja': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:drzavna_meja',
    format: 'image/png',
    transparent: true,
  },

  // ============ INFRASTRUCTURE ============
  'gozdne-ceste': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:gozdne_ceste',
    styles: 'gozdne_ceste',
    format: 'image/png',
    transparent: true,
  },
  'glavne-ceste': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:KGI_LINIJE_CESTE_G',
    format: 'image/png',
    transparent: true,
  },
  'zeleznice': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:LINIJE_ZELEZNICE_G',
    format: 'image/png',
    transparent: true,
  },
  'planinske-poti': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:KGI_LINIJE_PLANINSKE_POTI_G',
    format: 'image/png',
    transparent: true,
  },

  // ============ FOREST MANAGEMENT ============
  'sestoji': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:sestoji',
    format: 'image/png',
    transparent: true,
  },
  'odseki': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:odseki_gozdni',
    format: 'image/png',
    transparent: true,
  },
  'revirji': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:revirji',
    format: 'image/png',
    transparent: true,
  },
  'gozdna-maska': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:gozdna_maska',
    format: 'image/png',
    transparent: true,
  },
  'gge': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:gge',
    format: 'image/png',
    transparent: true,
  },
  'ggo': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:ggo',
    format: 'image/png',
    transparent: true,
  },

  // ============ PROTECTED AREAS ============
  'gozdni-rezervati': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:gozdni_rezervati',
    format: 'image/png',
    transparent: true,
  },
  'varovalni-gozdovi': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:varovalni_gozdovi',
    format: 'image/png',
    transparent: true,
  },
  'natura-2000': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:natura2000',
    format: 'image/png',
    transparent: true,
  },
  'zavarovana-obmocja': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:zavarovana_obmocja_poligoni',
    format: 'image/png',
    transparent: true,
  },
  'naravne-vrednote': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:naravne_vrednote_poligoni',
    format: 'image/png',
    transparent: true,
  },
  'ekolosko-obmocja': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:epo_poligoni',
    format: 'image/png',
    transparent: true,
  },
  'koridorji': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:koridorji',
    format: 'image/png',
    transparent: true,
  },
  'ekocelice': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:gozdni_sklad_ekocelice',
    format: 'image/png',
    transparent: true,
  },
  'habitatna-drevesa': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:gozdni_sklad_habitatna_drevesa',
    format: 'image/png',
    transparent: true,
  },

  // ============ HAZARDS & DISASTERS ============
  'pozarna-ogrozenost': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:pozarna_ogrozenost',
    format: 'image/png',
    transparent: true,
  },
  'gozdni-pozari': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:gozdni_pozari',
    format: 'image/png',
    transparent: true,
  },
  'protipozarne-preseke': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:protipozarne_preseke',
    format: 'image/png',
    transparent: true,
  },
  'vetrolom-2017': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:vetrolom_2017',
    format: 'image/png',
    transparent: true,
  },
  'vetrolom-2018': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:vetrolom_2018',
    format: 'image/png',
    transparent: true,
  },
  'zled-2014': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:zled_2014',
    format: 'image/png',
    transparent: true,
  },
  'podlubniki': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:podlubniki_2015_2019',
    format: 'image/png',
    transparent: true,
  },
  'krcitve': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:krcitve',
    format: 'image/png',
    transparent: true,
  },

  // ============ FOREST FUNCTIONS ============
  'lesna-proizvodnja': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:on21_fun_lesnoproizvodna_p',
    format: 'image/png',
    transparent: true,
  },
  'varovalna-funkcija': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:on21_fun_varovalna_p',
    format: 'image/png',
    transparent: true,
  },
  'rekreacija': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:on21_fun_rekreacijska_p',
    format: 'image/png',
    transparent: true,
  },

  // ============ SPECIAL ============
  'lovisca': {
    baseUrl: GEOSERVER,
    layers: 'pregledovalnik:lovisca',
    format: 'image/png',
    transparent: true,
  }
};
