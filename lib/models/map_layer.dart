import 'package:flutter_map/flutter_map.dart';

/// Categories for overlay layers
enum OverlayCategory {
  administrativno,
  infrastruktura,
  gozdnoGospodarstvo,
  zavarovanaObmocja,
  nevarnostiInSkode,
  funkcijeGozda,
  posebno,
}

/// Slovenian display names for overlay categories
const Map<OverlayCategory, String> overlayCategoryNames = {
  OverlayCategory.administrativno: 'Administrativno',
  OverlayCategory.infrastruktura: 'Infrastruktura',
  OverlayCategory.gozdnoGospodarstvo: 'Gozdno gospodarstvo',
  OverlayCategory.zavarovanaObmocja: 'Zavarovana obmocja',
  OverlayCategory.nevarnostiInSkode: 'Nevarnosti in skode',
  OverlayCategory.funkcijeGozda: 'Funkcije gozda',
  OverlayCategory.posebno: 'Posebno',
};

enum MapLayerType {
  // Base layers
  openStreetMap,
  openTopoMap,
  esriWorldImagery,
  googleHybrid,
  googleTerrain,
  ortofoto,
  dofIr,
  dmr,

  // Administrative
  kataster,
  katasterNazivi,
  katastrskObcine,
  obcine,
  upravneEnote,
  statisticneRegije,
  naselja,
  hisnestevilke,
  drzavnaMeja,

  // Infrastructure
  gozdneCeste,
  glavneCeste,
  zeleznice,
  planinskePoti,

  // Forest Management
  sestoji,
  odsekiGozdni,
  revirji,
  gozdnaMaska,
  gge,
  ggo,

  // Protected Areas
  gozdniRezervati,
  varovalniGozdovi,
  natura2000,
  zavarovanaObmocja,
  naravneVrednote,
  ekoloskoObmocja,
  koridorji,
  ekocelice,
  habitatnaDrevesa,

  // Hazards & Disasters
  pozarnaOgrozenost,
  gozdniPozari,
  protipozarnePreseke,
  vetrolom2017,
  vetrolom2018,
  zled2014,
  podlubniki,
  krcitve,

  // Forest Functions
  lesnaProizvodnja,
  varovalnaFunkcija,
  rekreacija,

  // Special
  lovisca,
}

class MapLayer {
  final MapLayerType type;
  final String name;
  final String? urlTemplate;
  final String attribution;
  final double minZoom;
  final double maxZoom;
  final bool isWms;
  final String? wmsBaseUrl;
  final List<String>? wmsLayers;
  final String? wmsFormat;
  final String? wmsStyles;
  final bool isTransparent;
  final bool isOverlay;
  final Crs? crs;
  final bool queryable; // Supports GetFeatureInfo queries
  final OverlayCategory? category; // Category for overlay layers

  const MapLayer({
    required this.type,
    required this.name,
    this.urlTemplate,
    required this.attribution,
    this.minZoom = 0.0,
    required this.maxZoom,
    this.isWms = false,
    this.wmsBaseUrl,
    this.wmsLayers,
    this.wmsFormat,
    this.wmsStyles,
    this.isTransparent = false,
    this.isOverlay = false,
    this.crs,
    this.queryable = false,
    this.category,
  });

  /// Check if this layer is from Slovenian prostor.zgs.gov.si server
  bool get isSlovenian =>
      isWms && (wmsBaseUrl?.contains('prostor.zgs.gov.si') ?? false);

  // ============ BASE LAYERS ============

  static const openStreetMap = MapLayer(
    type: MapLayerType.openStreetMap,
    name: 'OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap contributors',
    maxZoom: 19,
  );

  /// OpenTopoMap - Topographic map
  static const openTopoMap = MapLayer(
    type: MapLayerType.openTopoMap,
    name: 'OpenTopoMap',
    urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
    attribution: '© OpenTopoMap (CC-BY-SA)',
    maxZoom: 17,
  );

  /// ESRI World Imagery - Satellite imagery
  static const esriWorldImagery = MapLayer(
    type: MapLayerType.esriWorldImagery,
    name: 'ESRI Satelit',
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: '© Esri',
    maxZoom: 19,
  );

  /// Google Hybrid - Satellite with labels
  static const googleHybrid = MapLayer(
    type: MapLayerType.googleHybrid,
    name: 'Google Hibrid',
    urlTemplate: 'http://mt0.google.com/vt/lyrs=y&hl=sl&x={x}&y={y}&z={z}',
    attribution: '© Google',
    maxZoom: 20,
  );

  /// Google Terrain - Terrain map
  static const googleTerrain = MapLayer(
    type: MapLayerType.googleTerrain,
    name: 'Google Teren',
    urlTemplate: 'http://mt0.google.com/vt/lyrs=p&hl=sl&x={x}&y={y}&z={z}',
    attribution: '© Google',
    maxZoom: 20,
  );

  /// Ortofoto 2024 - Aerial imagery (Slovenia)
  static const ortofoto = MapLayer(
    type: MapLayerType.ortofoto,
    name: 'Ortofoto 2024',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geowebcache/service/wms?',
    wmsLayers: ['pregledovalnik:DOF_2024'],
    wmsFormat: 'image/jpeg',
  );

  /// DOF IR - Infrared orthophoto (Slovenia)
  static const dofIr = MapLayer(
    type: MapLayerType.dofIr,
    name: 'Ortofoto IR',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geowebcache/service/wms?',
    wmsLayers: ['pregledovalnik:DOF_IR'],
    wmsFormat: 'image/jpeg',
  );

  /// DMR - Digital elevation model (Slovenia)
  static const dmr = MapLayer(
    type: MapLayerType.dmr,
    name: 'DMR (relief)',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geowebcache/service/wms?',
    wmsLayers: ['pregledovalnik:DMR'],
    wmsFormat: 'image/jpeg',
  );

  // ============ OVERLAY LAYERS ============

  /// Kataster - Cadastral parcels (Katastrske parcele)
  static const kataster = MapLayer(
    type: MapLayerType.kataster,
    name: 'Kataster',
    attribution: '© GURS',
    minZoom: 15,
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geowebcache/service/wms?',
    wmsLayers: ['pregledovalnik:kn_parcele'],
    wmsFormat: 'image/png',
    wmsStyles: 'parcele',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.administrativno,
  );

  /// Katastrske obcine - Cadastral municipalities
  static const katastrskObcine = MapLayer(
    type: MapLayerType.katastrskObcine,
    name: 'Katastrske obcine',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:KN_KATASTRSKE_OBCINE'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.administrativno,
  );

  /// Kataster z nazivi - Cadastral parcels with names
  static const katasterNazivi = MapLayer(
    type: MapLayerType.katasterNazivi,
    name: 'Kataster z nazivi',
    attribution: '© GURS',
    minZoom: 15,
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geowebcache/service/wms?',
    wmsLayers: ['pregledovalnik:kn_parcele'],
    wmsFormat: 'image/png',
    wmsStyles: 'parcele_stevilke',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.administrativno,
  );

  /// Gozdne ceste - Forest roads
  static const gozdneCeste = MapLayer(
    type: MapLayerType.gozdneCeste,
    name: 'Gozdne ceste',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:KGI_LINIJE_CESTE_G'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.infrastruktura,
  );

  /// Glavne ceste - Main roads
  static const glavneCeste = MapLayer(
    type: MapLayerType.glavneCeste,
    name: 'Glavne ceste',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:KGI_LINIJE_CESTE_D'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.infrastruktura,
  );

  /// Zeleznice - Railways
  static const zeleznice = MapLayer(
    type: MapLayerType.zeleznice,
    name: 'Zeleznice',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:LINIJE_ZELEZNICE_G'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.infrastruktura,
  );

  /// Planinske poti - Hiking trails
  static const planinskePoti = MapLayer(
    type: MapLayerType.planinskePoti,
    name: 'Planinske poti',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:KGI_LINIJE_PLANINSKE_POTI_G'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.infrastruktura,
  );

  /// Hisne stevilke - House numbers
  static const hisnestevilke = MapLayer(
    type: MapLayerType.hisnestevilke,
    name: 'Hisne stevilke',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:NEP_HISNE_STEVILKE'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.administrativno,
  );

  /// Naselja - Settlements
  static const naselja = MapLayer(
    type: MapLayerType.naselja,
    name: 'Naselja',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:NEP_RPE_NASELJA'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.administrativno,
  );

  /// Obcine - Municipalities
  static const obcine = MapLayer(
    type: MapLayerType.obcine,
    name: 'Obcine',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:NEP_RPE_OBCINE'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.administrativno,
  );

  /// Upravne enote - Administrative units
  static const upravneEnote = MapLayer(
    type: MapLayerType.upravneEnote,
    name: 'Upravne enote',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:NEP_RPE_UPRAVNE_ENOTE'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.administrativno,
  );

  /// Statisticne regije - Statistical regions
  static const statisticneRegije = MapLayer(
    type: MapLayerType.statisticneRegije,
    name: 'Statisticne regije',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:NEP_RPE_STATISTICNE_REGIJE'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.administrativno,
  );

  /// Drzavna meja - State border
  static const drzavnaMeja = MapLayer(
    type: MapLayerType.drzavnaMeja,
    name: 'Drzavna meja',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:drzavna_meja'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.administrativno,
  );

  // ============ FOREST MANAGEMENT LAYERS ============

  /// Sestoji - Forest stands
  static const sestoji = MapLayer(
    type: MapLayerType.sestoji,
    name: 'Sestoji',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:sestoji'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.gozdnoGospodarstvo,
  );

  /// Odseki gozdni - Forest sections
  static const odsekiGozdni = MapLayer(
    type: MapLayerType.odsekiGozdni,
    name: 'Odseki',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:odseki_gozdni'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.gozdnoGospodarstvo,
  );

  /// Revirji - Forest districts
  static const revirji = MapLayer(
    type: MapLayerType.revirji,
    name: 'Revirji',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:revirji'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.gozdnoGospodarstvo,
  );

  /// Gozdna maska - Forest mask
  static const gozdnaMaska = MapLayer(
    type: MapLayerType.gozdnaMaska,
    name: 'Gozdna maska',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:gozdna_maska'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.gozdnoGospodarstvo,
  );

  /// GGE - Forest management units (Gozdnogospodarske enote)
  static const gge = MapLayer(
    type: MapLayerType.gge,
    name: 'GGE',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:gge'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.gozdnoGospodarstvo,
  );

  /// GGO - Forest management areas (Gozdnogospodarska obmocja)
  static const ggo = MapLayer(
    type: MapLayerType.ggo,
    name: 'GGO',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:ggo'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.gozdnoGospodarstvo,
  );

  // ============ PROTECTED AREAS ============

  /// Gozdni rezervati - Forest reserves
  static const gozdniRezervati = MapLayer(
    type: MapLayerType.gozdniRezervati,
    name: 'Gozdni rezervati',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:gozdni_rezervati'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.zavarovanaObmocja,
  );

  /// Varovalni gozdovi - Protective forests
  static const varovalniGozdovi = MapLayer(
    type: MapLayerType.varovalniGozdovi,
    name: 'Varovalni gozdovi',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:varovalni_gozdovi'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.zavarovanaObmocja,
  );

  /// Natura 2000 - EU protected areas
  static const natura2000 = MapLayer(
    type: MapLayerType.natura2000,
    name: 'Natura 2000',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:natura2000'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.zavarovanaObmocja,
  );

  /// Zavarovana obmocja - Protected areas
  static const zavarovanaObmocja = MapLayer(
    type: MapLayerType.zavarovanaObmocja,
    name: 'Zavarovana obmocja',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:zavarovana_obmocja_poligoni'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.zavarovanaObmocja,
  );

  /// Naravne vrednote - Natural values
  static const naravneVrednote = MapLayer(
    type: MapLayerType.naravneVrednote,
    name: 'Naravne vrednote',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:naravne_vrednote_poligoni'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.zavarovanaObmocja,
  );

  /// Ekolosko pomembna obmocja - Ecologically important areas
  static const ekoloskoObmocja = MapLayer(
    type: MapLayerType.ekoloskoObmocja,
    name: 'Ekolosko pomembna obmocja',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:epo_poligoni'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.zavarovanaObmocja,
  );

  /// Koridorji - Ecological corridors
  static const koridorji = MapLayer(
    type: MapLayerType.koridorji,
    name: 'Ekoloski koridorji',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:koridorji'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.zavarovanaObmocja,
  );

  /// Ekocelice - Eco-cells
  static const ekocelice = MapLayer(
    type: MapLayerType.ekocelice,
    name: 'Ekocelice',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:gozdni_sklad_ekocelice'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.zavarovanaObmocja,
  );

  /// Habitatna drevesa - Habitat trees
  static const habitatnaDrevesa = MapLayer(
    type: MapLayerType.habitatnaDrevesa,
    name: 'Habitatna drevesa',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:gozdni_sklad_habitatna_drevesa'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.zavarovanaObmocja,
  );

  // ============ HAZARDS & DISASTERS ============

  /// Pozarna ogrozenost - Fire hazard zones
  static const pozarnaOgrozenost = MapLayer(
    type: MapLayerType.pozarnaOgrozenost,
    name: 'Pozarna ogrozenost',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:pozarna_ogrozenost'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.nevarnostiInSkode,
  );

  /// Gozdni pozari - Historical forest fires
  static const gozdniPozari = MapLayer(
    type: MapLayerType.gozdniPozari,
    name: 'Gozdni pozari',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:gozdni_pozari'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.nevarnostiInSkode,
  );

  /// Protipozarne preseke - Firebreaks
  static const protipozarnePreseke = MapLayer(
    type: MapLayerType.protipozarnePreseke,
    name: 'Protipozarne preseke',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:protipozarne_preseke'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.nevarnostiInSkode,
  );

  /// Vetrolom 2017 - Windthrow 2017
  static const vetrolom2017 = MapLayer(
    type: MapLayerType.vetrolom2017,
    name: 'Vetrolom 2017',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:vetrolom_2017'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.nevarnostiInSkode,
  );

  /// Vetrolom 2018 - Windthrow 2018
  static const vetrolom2018 = MapLayer(
    type: MapLayerType.vetrolom2018,
    name: 'Vetrolom 2018',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:vetrolom_2018'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.nevarnostiInSkode,
  );

  /// Zled 2014 - Ice storm damage 2014
  static const zled2014 = MapLayer(
    type: MapLayerType.zled2014,
    name: 'Zled 2014',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:zled_2014'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.nevarnostiInSkode,
  );

  /// Podlubniki - Bark beetle damage
  static const podlubniki = MapLayer(
    type: MapLayerType.podlubniki,
    name: 'Podlubniki 2015-2019',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:podlubniki_2015_2019'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.nevarnostiInSkode,
  );

  /// Krcitve - Forest clearings
  static const krcitve = MapLayer(
    type: MapLayerType.krcitve,
    name: 'Krcitve',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:krcitve'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.nevarnostiInSkode,
  );

  // ============ FOREST FUNCTIONS ============

  /// Lesna proizvodnja - Wood production function
  static const lesnaProizvodnja = MapLayer(
    type: MapLayerType.lesnaProizvodnja,
    name: 'Lesna proizvodnja',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:on21_fun_lesnoproizvodna_p'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.funkcijeGozda,
  );

  /// Varovalna funkcija - Protective function
  static const varovalnaFunkcija = MapLayer(
    type: MapLayerType.varovalnaFunkcija,
    name: 'Varovalna funkcija',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:on21_fun_varovalna_p'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.funkcijeGozda,
  );

  /// Rekreacija - Recreation areas
  static const rekreacija = MapLayer(
    type: MapLayerType.rekreacija,
    name: 'Rekreacija',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:on21_fun_rekreacijska_p'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.funkcijeGozda,
  );

  // ============ SPECIAL ============

  /// Lovisca - Hunting grounds
  static const lovisca = MapLayer(
    type: MapLayerType.lovisca,
    name: 'Lovisca',
    attribution: '© ZGS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:lovisca'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    queryable: true,
    category: OverlayCategory.posebno,
  );

  /// Base layers (mutually exclusive)
  static const List<MapLayer> baseLayers = [
    openStreetMap,
    openTopoMap,
    esriWorldImagery,
    googleHybrid,
    googleTerrain,
    ortofoto,
    dofIr,
    dmr,
  ];

  /// Overlay layers (can be toggled on/off) - organized by category
  static const List<MapLayer> overlayLayers = [
    // Administrative
    kataster,
    katasterNazivi,
    katastrskObcine,
    obcine,
    upravneEnote,
    statisticneRegije,
    naselja,
    hisnestevilke,
    drzavnaMeja,
    // Infrastructure
    gozdneCeste,
    glavneCeste,
    zeleznice,
    planinskePoti,
    // Forest Management
    sestoji,
    odsekiGozdni,
    revirji,
    gozdnaMaska,
    gge,
    ggo,
    // Protected Areas & Nature
    gozdniRezervati,
    varovalniGozdovi,
    natura2000,
    zavarovanaObmocja,
    naravneVrednote,
    ekoloskoObmocja,
    koridorji,
    ekocelice,
    habitatnaDrevesa,
    // Hazards & Disasters
    pozarnaOgrozenost,
    gozdniPozari,
    protipozarnePreseke,
    vetrolom2017,
    vetrolom2018,
    zled2014,
    podlubniki,
    krcitve,
    // Forest Functions
    lesnaProizvodnja,
    varovalnaFunkcija,
    rekreacija,
    // Special
    lovisca,
  ];

  /// All layers for backwards compatibility
  static const List<MapLayer> allLayers = [...baseLayers, ...overlayLayers];

  /// Get all queryable layers (support GetFeatureInfo)
  static List<MapLayer> get queryableLayers =>
      overlayLayers.where((l) => l.queryable).toList();

  /// Get overlay layers grouped by category
  static Map<OverlayCategory, List<MapLayer>> get overlaysByCategory {
    final result = <OverlayCategory, List<MapLayer>>{};
    for (final category in OverlayCategory.values) {
      final layers = overlayLayers
          .where((l) => l.category == category)
          .toList();
      if (layers.isNotEmpty) {
        result[category] = layers;
      }
    }
    return result;
  }
}
