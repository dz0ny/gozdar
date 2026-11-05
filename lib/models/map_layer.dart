import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Categories for overlay layers
enum OverlayCategory {
  administrativno,
  infrastruktura,
  gozdnoGospodarstvo,
  zavarovanaObmocja,
  nevarnostiInSkode,
  funkcijeGozda,
  posebno,
  hrvatska,
}

enum MapLayerType {
  // Base layers
  openStreetMap,
  openTopoMap,
  esriWorldImagery,
  esriTopoMap,
  ortofoto,
  ortofoto2023,
  ortofoto2022,
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

  // Croatia (DGU). Appended: preferences store layers by name, but keep the
  // Slovenian groups together above.
  hrKataster,
  hrKatasterNazivi,
  hrKatastarskeOpcine,

  // Croatian orthophoto base layers (DGU, INSPIRE WMS).
  hrDof2023,
  hrDof2021,
  hrDof2019,
}

class MapLayer {
  static const double appMaxZoom = 22.0;
  static const double tileSourceMaxZoom = 19.0;

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
  final String? proxySlugOverride;

  /// CRS a [isDirectWms] layer is requested in: EPSG:3857 unless set. DGU's
  /// INSPIRE orthophotos offer EPSG:4326 but not Web Mercator; over one tile
  /// the difference is far below a pixel.
  final String? wmsCrs;

  /// Extra HTTP headers the tile source requires (e.g. mapy.cz rejects
  /// requests without a mapy.com Referer with 403).
  final Map<String, String> httpHeaders;

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
    this.proxySlugOverride,
    this.httpHeaders = const {},
    this.wmsCrs,
  });

  static const _mapyHeaders = {'Referer': 'https://mapy.com/'};

  /// Extra headers required by known tile hosts, for fetch paths that only
  /// have a tile URL (offline downloader) instead of a [MapLayer].
  static Map<String, String> httpHeadersForUrl(String url) {
    if (url.contains('mapserver.mapy.cz')) return _mapyHeaders;
    return const {};
  }

  /// Check if this layer is from Slovenian prostor.zgs.gov.si server
  bool get isSlovenian =>
      isWms && (wmsBaseUrl?.contains('prostor.zgs.gov.si') ?? false);

  /// Croatian DGU layer: cadastre from the portal Uređena zemlja or an
  /// orthophoto from geoportal.dgu.hr.
  bool get isCroatian =>
      category == OverlayCategory.hrvatska ||
      (wmsBaseUrl?.contains('dgu.hr') ?? false);

  /// Kebab-case slug used by the worker tile proxy.
  String get proxySlug =>
      proxySlugOverride ??
      type.name
          .replaceAllMapped(
            RegExp(r'(?<!^)(?=[A-Z])|(?<=[a-z])(?=[0-9])'),
            (match) => '-',
          )
          .toLowerCase();

  int get nativeMaxZoom {
    final cappedMaxZoom = maxZoom < tileSourceMaxZoom
        ? maxZoom
        : tileSourceMaxZoom;
    return cappedMaxZoom.toInt();
  }

  int get downloadMaxZoom => nativeMaxZoom;

  /// WMS layer the app requests itself: the server speaks EPSG:3857, so a
  /// map tile is one GetMap of the tile's bounding box (DGU). Slovenian
  /// layers need EPSG:3794 and go through the worker instead.
  bool get isDirectWms => isWms && isCroatian;

  /// GetMap template for a [isDirectWms] layer; `{bbox}` is filled per tile
  /// by [webMercatorTileBbox], `{bbox4326}` by [geographicTileBbox].
  String get _directWmsTemplate {
    if (wmsCrs == 'EPSG:4326') {
      final params = {
        'SERVICE': 'WMS',
        'VERSION': '1.3.0',
        'REQUEST': 'GetMap',
        'LAYERS': wmsLayers!.join(','),
        'STYLES': wmsStyles ?? '',
        'FORMAT': wmsFormat ?? 'image/png',
        'TRANSPARENT': '$isTransparent'.toUpperCase(),
        'CRS': 'EPSG:4326',
        'WIDTH': '256',
        'HEIGHT': '256',
      };
      final query = params.entries
          .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');
      return '$wmsBaseUrl$query&BBOX={bbox4326}';
    }
    final params = {
      'SERVICE': 'WMS',
      'VERSION': '1.1.1',
      'REQUEST': 'GetMap',
      'LAYERS': wmsLayers!.join(','),
      'STYLES': wmsStyles ?? '',
      'FORMAT': wmsFormat ?? 'image/png',
      'TRANSPARENT': '$isTransparent'.toUpperCase(),
      'SRS': 'EPSG:3857',
      'WIDTH': '256',
      'HEIGHT': '256',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$wmsBaseUrl$query&BBOX={bbox}';
  }

  /// EPSG:3857 bounding box of XYZ tile z/x/y as "minx,miny,maxx,maxy".
  static String webMercatorTileBbox(int z, int x, int y) {
    const origin = 20037508.342789244;
    final size = 2 * origin / (1 << z);
    final minX = -origin + x * size;
    final maxY = origin - y * size;
    return [
      minX,
      maxY - size,
      minX + size,
      maxY,
    ].map((v) => v.toStringAsFixed(2)).join(',');
  }

  /// WGS84 bounding box of XYZ tile z/x/y in WMS 1.3.0 EPSG:4326 axis order,
  /// "minLat,minLon,maxLat,maxLon".
  static String geographicTileBbox(int z, int x, int y) {
    final n = 1 << z;
    double lon(int x) => x / n * 360 - 180;
    double lat(int y) =>
        math.atan(_sinh(math.pi * (1 - 2 * y / n))) * 180 / math.pi;
    return [
      lat(y + 1),
      lon(x),
      lat(y),
      lon(x + 1),
    ].map((v) => v.toStringAsFixed(8)).join(',');
  }

  static double _sinh(double v) => (math.exp(v) - math.exp(-v)) / 2;

  /// Fills a tile's `{bbox}` and `{bbox4326}` in [template].
  static String fillTileBbox(String template, int z, int x, int y) {
    var url = template;
    if (url.contains('{bbox}')) {
      url = url.replaceAll('{bbox}', webMercatorTileBbox(z, x, y));
    }
    if (url.contains('{bbox4326}')) {
      url = url.replaceAll('{bbox4326}', geographicTileBbox(z, x, y));
    }
    return url;
  }

  /// Orthophotos of the neighbouring country drawn with [base], so the map
  /// is imagery on both sides of the border. Each country's service draws
  /// only its own territory: the Slovenian one white elsewhere, so it goes
  /// underneath; the Croatian one transparent, so it goes on top.
  ///
  /// Slovenian orthophotos pair with HR 2019/20: the keyless 2021/22 and
  /// 2023/24 services stamp "GEOPORTAL" on every tile, even outside Croatia,
  /// which would cover all of Slovenia.
  static const _orthoPartners = {
    MapLayerType.ortofoto: MapLayerType.hrDof2019,
    MapLayerType.ortofoto2023: MapLayerType.hrDof2019,
    MapLayerType.ortofoto2022: MapLayerType.hrDof2019,
    MapLayerType.hrDof2023: MapLayerType.ortofoto,
    MapLayerType.hrDof2021: MapLayerType.ortofoto2022,
    MapLayerType.hrDof2019: MapLayerType.ortofoto2022,
  };

  /// The base layers to draw for [base], bottom first: the orthophoto pair
  /// for Slovenian and Croatian orthophotos, [base] alone otherwise.
  static List<MapLayer> stackFor(MapLayer base) {
    final partnerType = _orthoPartners[base.type];
    if (partnerType == null) return [base];
    final partner = baseLayers.firstWhere((l) => l.type == partnerType);
    return base.isCroatian ? [partner, base] : [base, partner];
  }

  static final _slovenia = LatLngBounds(
    const LatLng(45.40, 13.35),
    const LatLng(46.90, 16.65),
  );
  static final _croatia = LatLngBounds(
    const LatLng(42.35, 13.45),
    const LatLng(46.60, 19.50),
  );

  /// Bounding box of the country an orthophoto covers, so a partner layer
  /// ([stackFor]) asks for no tiles beyond it; null for the rest. Only a
  /// box: Croatia's still holds most of Slovenia, where its tiles come back
  /// empty and transparent.
  LatLngBounds? get orthoCoverage {
    if (!_orthoPartners.containsKey(type)) return null;
    return isCroatian ? _croatia : _slovenia;
  }

  /// Resolve the layer to an XYZ template.
  /// Direct tile sources keep their own template, [isDirectWms] layers get a
  /// GetMap template with `{bbox}`, Slovenian layers use the proxy.
  String? resolveUrlTemplate(String? workerUrl) {
    if (urlTemplate != null && urlTemplate!.isNotEmpty) {
      return urlTemplate;
    }
    if (isDirectWms) return _directWmsTemplate;
    if (workerUrl == null || workerUrl.isEmpty) {
      return null;
    }
    return '$workerUrl/tiles/$proxySlug/{z}/{x}/{y}.png';
  }

  // ============ BASE LAYERS ============

  static const openStreetMap = MapLayer(
    type: MapLayerType.openStreetMap,
    name: 'OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap contributors',
    maxZoom: 19,
  );

  /// Mapy.cz Turist - Tourist/hiking map
  /// (enum value kept as openTopoMap for saved-preferences compatibility)
  static const openTopoMap = MapLayer(
    type: MapLayerType.openTopoMap,
    name: 'Topo LIDAR + OSM',
    urlTemplate: 'https://mapserver.mapy.cz/turist-en/retina/{z}-{x}-{y}',
    attribution: '© Seznam.cz, © OpenStreetMap contributors',
    maxZoom: 19,
    httpHeaders: _mapyHeaders,
  );

  /// ESRI World Imagery - Satellite imagery
  static const esriWorldImagery = MapLayer(
    type: MapLayerType.esriWorldImagery,
    name: 'ESRI Satelit',
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: '© Esri',
    maxZoom: 21,
  );

  /// ESRI World Topo Map - Topographic map
  static const esriTopoMap = MapLayer(
    type: MapLayerType.esriTopoMap,
    name: 'ESRI Topo',
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
    attribution: '© Esri',
    maxZoom: 21,
  );

  /// Ortofoto 2024 - Aerial imagery (Slovenia)
  static const ortofoto = MapLayer(
    type: MapLayerType.ortofoto,
    name: 'Ortofoto 2024',
    attribution: '© GURS',
    maxZoom: 21,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geowebcache/service/wms?',
    wmsLayers: ['pregledovalnik:DOF25'],
    wmsFormat: 'image/jpeg',
  );

  /// Ortofoto 2023 - Aerial imagery (Slovenia)
  static const ortofoto2023 = MapLayer(
    type: MapLayerType.ortofoto2023,
    name: 'Ortofoto 2023',
    attribution: '© GURS',
    maxZoom: 21,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geowebcache/service/wms?',
    wmsLayers: ['pregledovalnik:DOF_2023'],
    wmsFormat: 'image/jpeg',
  );

  /// Ortofoto 2022 - Aerial imagery (Slovenia)
  static const ortofoto2022 = MapLayer(
    type: MapLayerType.ortofoto2022,
    name: 'Ortofoto 2022',
    attribution: '© GURS',
    maxZoom: 21,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geowebcache/service/wms?',
    wmsLayers: ['pregledovalnik:DOF_2022'],
    wmsFormat: 'image/jpeg',
  );

  /// DOF IR - Infrared orthophoto (Slovenia)
  static const dofIr = MapLayer(
    type: MapLayerType.dofIr,
    name: 'Ortofoto IR',
    attribution: '© GURS',
    maxZoom: 21,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geowebcache/service/wms?',
    wmsLayers: ['pregledovalnik:DOF_IR'],
    wmsFormat: 'image/jpeg',
  );

  /// DGU orthophoto 1:5000 (Croatia), keyless INSPIRE WMS under the open
  /// licence (data.gov.hr/otvorena-dozvola). PNG so that outside Croatia the
  /// tile is transparent and the Slovenian orthophoto shows through. The
  /// keyless 2021/22 and 2023/24 images carry a "GEOPORTAL" stamp.
  static const hrDof2023 = MapLayer(
    type: MapLayerType.hrDof2023,
    name: 'Ortofoto HR 2023/24',
    attribution: '© DGU',
    maxZoom: 21,
    isWms: true,
    wmsBaseUrl:
        'https://geoportal.dgu.hr/services/inspire/orthophoto_2023_2024/wms?',
    wmsLayers: ['OI.OrthoimageCoverage'],
    wmsFormat: 'image/png',
    wmsCrs: 'EPSG:4326',
    isTransparent: true,
  );

  static const hrDof2021 = MapLayer(
    type: MapLayerType.hrDof2021,
    name: 'Ortofoto HR 2021/22',
    attribution: '© DGU',
    maxZoom: 21,
    isWms: true,
    wmsBaseUrl:
        'https://geoportal.dgu.hr/services/inspire/orthophoto_2021_2022/wms?',
    wmsLayers: ['OI.OrthoimageCoverage'],
    wmsFormat: 'image/png',
    wmsCrs: 'EPSG:4326',
    isTransparent: true,
  );

  /// The newest keyless year without the stamp.
  static const hrDof2019 = MapLayer(
    type: MapLayerType.hrDof2019,
    name: 'Ortofoto HR 2019/20',
    attribution: '© DGU',
    maxZoom: 21,
    isWms: true,
    wmsBaseUrl:
        'https://geoportal.dgu.hr/services/inspire/orthophoto_2019_2020/wms?',
    wmsLayers: ['OI.OrthoimageCoverage'],
    wmsFormat: 'image/png',
    wmsCrs: 'EPSG:4326',
    isTransparent: true,
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

  /// Katastrske občine - Cadastral municipalities
  static const katastrskObcine = MapLayer(
    type: MapLayerType.katastrskObcine,
    name: 'Katastrske občine',
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
    proxySlugOverride: 'katastrske-obcine',
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

  /// Železnice - Railways
  static const zeleznice = MapLayer(
    type: MapLayerType.zeleznice,
    name: 'Železnice',
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

  /// Hišne številke - House numbers
  static const hisnestevilke = MapLayer(
    type: MapLayerType.hisnestevilke,
    name: 'Hišne številke',
    attribution: '© GURS',
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://prostor.zgs.gov.si/geoserver/wms?',
    wmsLayers: ['pregledovalnik:NEP_HISNE_STEVILKE'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.administrativno,
    proxySlugOverride: 'hisne-stevilke',
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

  /// Občine - Municipalities
  static const obcine = MapLayer(
    type: MapLayerType.obcine,
    name: 'Občine',
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

  /// Statistične regije - Statistical regions
  static const statisticneRegije = MapLayer(
    type: MapLayerType.statisticneRegije,
    name: 'Statistične regije',
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

  /// Državna meja - State border
  static const drzavnaMeja = MapLayer(
    type: MapLayerType.drzavnaMeja,
    name: 'Državna meja',
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
    proxySlugOverride: 'odseki',
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

  /// GGO - Forest management areas (Gozdnogospodarska območja)
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

  /// Zavarovana območja - Protected areas
  static const zavarovanaObmocja = MapLayer(
    type: MapLayerType.zavarovanaObmocja,
    name: 'Zavarovana območja',
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

  /// Ekološko pomembna območja - Ecologically important areas
  static const ekoloskoObmocja = MapLayer(
    type: MapLayerType.ekoloskoObmocja,
    name: 'Ekološko pomembna območja',
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
    name: 'Ekološki koridorji',
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

  /// Požarna ogroženost - Fire hazard zones
  static const pozarnaOgrozenost = MapLayer(
    type: MapLayerType.pozarnaOgrozenost,
    name: 'Požarna ogroženost',
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

  /// Gozdni požari - Historical forest fires
  static const gozdniPozari = MapLayer(
    type: MapLayerType.gozdniPozari,
    name: 'Gozdni požari',
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

  /// Protipožarne preseke - Firebreaks
  static const protipozarnePreseke = MapLayer(
    type: MapLayerType.protipozarnePreseke,
    name: 'Protipožarne preseke',
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

  /// Žled 2014 - Ice storm damage 2014
  static const zled2014 = MapLayer(
    type: MapLayerType.zled2014,
    name: 'Žled 2014',
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

  /// Krčitve - Forest clearings
  static const krcitve = MapLayer(
    type: MapLayerType.krcitve,
    name: 'Krčitve',
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

  /// Lovišča - Hunting grounds
  static const lovisca = MapLayer(
    type: MapLayerType.lovisca,
    name: 'Lovišča',
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

  // ============ CROATIA (DGU) ============
  // Served through the worker like the Slovenian layers; DGU's WMS takes
  // Web Mercator directly, so the worker skips reprojection for them.

  /// Katastarske čestice - Croatian cadastral parcels
  static const hrKataster = MapLayer(
    type: MapLayerType.hrKataster,
    name: 'Katastarske čestice',
    attribution: '© DGU',
    minZoom: 15,
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://wms1-gs-oss.uredjenazemlja.hr/ows2-m/wms?',
    wmsLayers: ['oss:BZP_CESTICE'],
    wmsFormat: 'image/png',
    wmsStyles: 'jis_cestice_kathr',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.hrvatska,
  );

  /// Katastarske čestice s brojevima - Croatian parcels with numbers
  static const hrKatasterNazivi = MapLayer(
    type: MapLayerType.hrKatasterNazivi,
    name: 'Katastarske čestice s brojevima',
    attribution: '© DGU',
    minZoom: 15,
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://wms1-gs-oss.uredjenazemlja.hr/ows2-m/wms?',
    wmsLayers: ['oss:BZP_CESTICE'],
    wmsFormat: 'image/png',
    wmsStyles: 'jis_cestice_nazivi_kathr',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.hrvatska,
  );

  /// Katastarske općine - Croatian cadastral municipalities
  static const hrKatastarskeOpcine = MapLayer(
    type: MapLayerType.hrKatastarskeOpcine,
    name: 'Katastarske općine',
    attribution: '© DGU',
    minZoom: 14,
    maxZoom: 19,
    isWms: true,
    wmsBaseUrl: 'https://wms1-gs-oss.uredjenazemlja.hr/ows2-m/wms?',
    wmsLayers: ['oss:SIF_KATASTARSKE_OPCINE'],
    wmsFormat: 'image/png',
    isTransparent: true,
    isOverlay: true,
    category: OverlayCategory.hrvatska,
  );

  /// Base layers (mutually exclusive)
  static const List<MapLayer> baseLayers = [
    openStreetMap,
    openTopoMap,
    esriWorldImagery,
    esriTopoMap,
    ortofoto,
    ortofoto2023,
    ortofoto2022,
    dofIr,
    hrDof2023,
    hrDof2021,
    hrDof2019,
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
    // Croatia
    hrKataster,
    hrKatasterNazivi,
    hrKatastarskeOpcine,
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
