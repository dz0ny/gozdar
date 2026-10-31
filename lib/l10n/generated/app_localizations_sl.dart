// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Slovenian (`sl`).
class AppLocalizationsSl extends AppLocalizations {
  AppLocalizationsSl([String locale = 'sl']) : super(locale);

  @override
  String get appTitle => 'Gozdar';

  @override
  String get commonCancel => 'Prekliči';

  @override
  String get commonSave => 'Shrani';

  @override
  String get commonDelete => 'Izbriši';

  @override
  String get commonClose => 'Zapri';

  @override
  String get commonOk => 'V redu';

  @override
  String get commonEdit => 'Uredi';

  @override
  String get commonAdd => 'Dodaj';

  @override
  String get commonYes => 'Da';

  @override
  String get commonNo => 'Ne';

  @override
  String get commonBack => 'Nazaj';

  @override
  String get commonRetry => 'Poskusi znova';

  @override
  String get commonSearch => 'Iskanje';

  @override
  String get commonShare => 'Deli';

  @override
  String get commonDownload => 'Prenesi';

  @override
  String get commonContinue => 'Naprej';

  @override
  String get commonDone => 'Končano';

  @override
  String get commonSettings => 'Nastavitve';

  @override
  String get commonError => 'Napaka';

  @override
  String get commonLoading => 'Nalaganje …';

  @override
  String get logsHeaderTitle => 'Hlodi';

  @override
  String get logsMoreOptionsTooltip => 'Več možnosti hlodov';

  @override
  String get logsMenuManageSpecies => 'Upravljanje vrst';

  @override
  String get logsMenuExport => 'Izvozi';

  @override
  String get logsMenuDeleteAll => 'Odstrani vse';

  @override
  String get logsSavedTooltip => 'Shranjeni hlodi';

  @override
  String get logsSaved => 'Shranjeno';

  @override
  String get logsSaveError => 'Napaka pri shranjevanju';

  @override
  String get logsEntryUpdated => 'Vnos posodobljen';

  @override
  String logsErrorWithDetail(String error) {
    return 'Napaka: $error';
  }

  @override
  String get logsEntryDeleted => 'Vnos izbrisan';

  @override
  String get logsUndo => 'Razveljavi';

  @override
  String get logsExportTitle => 'Izvozi hlode';

  @override
  String get logsExportExcel => 'Izvozi kot Excel';

  @override
  String get logsExportJson => 'Izvozi kot JSON';

  @override
  String get logsExportSuccess => 'Izvoz uspešen';

  @override
  String get logsNoEntriesToDelete => 'Ni vnosov za brisanje';

  @override
  String get logsDeleteAllTitle => 'Odstrani vse hlode';

  @override
  String logsDeleteAllConfirm(int count, String volume) {
    return 'Ali ste prepričani, da želite odstraniti vseh $count vnosov?\n\nSkupni volumen: $volume m³\n\nShranjeni hlodi ostanejo nespremenjeni. To dejanje ni mogoče razveljaviti.';
  }

  @override
  String get logsAllEntriesRemoved => 'Vsi vnosi odstranjeni';

  @override
  String get logsNoEntriesToSave => 'Ni vnosov za shranjevanje';

  @override
  String logsCountLogs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hlodov',
      few: '$count hlodi',
      two: '$count hloda',
      one: '$count hlod',
    );
    return '$_temp0';
  }

  @override
  String logsGroupSummary(int count, String volume) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hlodov',
      few: '$count hlodi',
      two: '$count hloda',
      one: '$count hlod',
    );
    return '$_temp0 • $volume m³';
  }

  @override
  String logsSaveSheetSummary(int count, String volume) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hlodov',
      few: '$count hlodi',
      two: '$count hloda',
      one: '$count hlod',
    );
    return '$volume m³ • $_temp0';
  }

  @override
  String get logsSpeciesNotSelected => 'Vrsta ni izbrana';

  @override
  String get logsUnknownSpecies => 'Neznana vrsta';

  @override
  String get logsEmptyTitle => 'Ni še hlodov';

  @override
  String get logsEmptyHint => 'Vnesite premer in dolžino spodaj';

  @override
  String get logsDiameterLabel => 'Premer (cm)';

  @override
  String get logsLengthLabel => 'Dolžina (m)';

  @override
  String get logsVolumeLabel => 'Volumen';

  @override
  String get logsSpeciesLabel => 'Drevesna vrsta';

  @override
  String get logsNotSelected => 'Ni izbrano';

  @override
  String get logsLocationLabel => 'Lokacija';

  @override
  String get logsAddLocation => 'Dodaj lokacijo';

  @override
  String get logsNameLabel => 'Ime';

  @override
  String get logsNameHint => 'npr. Smreka za Novaka';

  @override
  String get logsNotesLabel => 'Opombe';

  @override
  String get logsNotesEditorHint => 'Vnesite opombe';

  @override
  String get logsLocationPermissionDenied => 'Dovoljenje za lokacijo zavrnjeno';

  @override
  String logsSaveErrorWithDetail(String error) {
    return 'Napaka pri shranjevanju: $error';
  }

  @override
  String logsInlineAdded(int count) {
    return 'Dodano: $count';
  }

  @override
  String get logsSpeciesAddTitle => 'Dodaj novo vrsto';

  @override
  String get logsSpeciesNameLabel => 'Ime vrste';

  @override
  String get logsSpeciesNameHint => 'Npr. Hrast';

  @override
  String logsSpeciesAdded(String name) {
    return 'Vrsta \"$name\" dodana';
  }

  @override
  String get logsSpeciesRemoveTitle => 'Odstrani vrsto';

  @override
  String logsSpeciesRemoveConfirm(String name) {
    return 'Ali ste prepričani, da želite odstraniti \"$name\"?';
  }

  @override
  String get logsSpeciesRemoveButton => 'Odstrani';

  @override
  String logsSpeciesRemoved(String name) {
    return 'Vrsta \"$name\" odstranjena';
  }

  @override
  String get logsSpeciesResetTitle => 'Ponastavi na privzeto';

  @override
  String get logsSpeciesResetConfirm =>
      'Ali ste prepričani, da želite ponastaviti vrste na privzete vrednosti?\n\nVse dodane vrste bodo odstranjene.';

  @override
  String get logsSpeciesResetButton => 'Ponastavi';

  @override
  String get logsSpeciesResetDone => 'Vrste ponastavljene na privzete';

  @override
  String logsSpeciesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vrst',
      few: '$count vrste',
      two: '$count vrsti',
      one: '$count vrsta',
    );
    return '$_temp0';
  }

  @override
  String get logsSpeciesNone => 'Ni dodanih vrst';

  @override
  String get logsConvTitle => 'Pretvorba volumna';

  @override
  String get logsConvSpeciesHint => 'Vrsta, ki jo dobijo novo dodani hlodi.';

  @override
  String get logsConvPrmTitle => 'PRM - Prostorninski meter drv';

  @override
  String get logsConvPrmDesc =>
      'Zložena drva (polena). 1 PRM × faktor = m³ trdne mase.';

  @override
  String get logsConvNmTitle => 'NM - Nasuti meter';

  @override
  String get logsConvNmDesc =>
      'Nasut les (sekanci, odpadki). 1 NM × faktor = m³ trdne mase.';

  @override
  String get logsConvDefault => 'Privzeto';

  @override
  String get logsConvBeechOak => 'Bukev/Hrast';

  @override
  String get logsConvSpruceFir => 'Smreka/Jelka';

  @override
  String get logsConvSoftHardwood => 'Mehki listavci';

  @override
  String get logsConvHardWood => 'Trdi les';

  @override
  String get logsConvSoftWood => 'Mehki les';

  @override
  String get logsConvConfirm => 'Potrdi';

  @override
  String get logsConvCustomFactor => 'Faktor po meri';

  @override
  String get logsFormLocationServicesDisabled =>
      'Lokacijske storitve so onemogočene';

  @override
  String get logsFormPermissionsDenied => 'Dovoljenja za lokacijo zavrnjena';

  @override
  String get logsFormPermissionsDeniedForever =>
      'Dovoljenja za lokacijo trajno zavrnjena';

  @override
  String get logsFormLocationAdded => 'Lokacija dodana';

  @override
  String logsFormLocationError(String error) {
    return 'Napaka pri pridobivanju lokacije: $error';
  }

  @override
  String get logsFormInvalidDimensions => 'Prosim vnesite veljavne dimenzije';

  @override
  String get logsFormTitleNew => 'Nov';

  @override
  String get logsFormVolumeModeTitle => 'Način vnosa volumna';

  @override
  String get logsFormModeCalculate => 'Izračunaj iz dimenzij';

  @override
  String get logsFormModeDirect => 'Vnesi volumen neposredno';

  @override
  String get logsFormDiameterHelper => 'Vnesite premer hloda v centimetrih';

  @override
  String get logsFormDiameterRequired => 'Prosim vnesite premer';

  @override
  String get logsFormDiameterInvalid => 'Prosim vnesite veljaven premer';

  @override
  String get logsFormLengthHelper => 'Vnesite dolžino hloda v metrih';

  @override
  String get logsFormLengthRequired => 'Prosim vnesite dolžino';

  @override
  String get logsFormLengthInvalid => 'Prosim vnesite veljavno dolžino';

  @override
  String get logsFormCalculatedVolume => 'Izračunan volumen';

  @override
  String get logsFormVolumeLabel => 'Volumen (m³)';

  @override
  String get logsFormVolumeHelper => 'Vnesite volumen v kubičnih metrih';

  @override
  String get logsFormVolumeRequired => 'Prosim vnesite volumen';

  @override
  String get logsFormVolumeInvalid => 'Prosim vnesite veljaven volumen';

  @override
  String get logsFormSpeciesOptional => 'Drevesna vrsta (neobvezno)';

  @override
  String get logsFormLocating => 'Pridobivanje lokacije...';

  @override
  String get logsFormAddCurrentLocation => 'Dodaj trenutno lokacijo';

  @override
  String get logsFormNotesOptional => 'Opombe (neobvezno)';

  @override
  String get logsFormNotesHelper => 'Dodajte morebitne opombe';

  @override
  String get logsSaveSheetTitle => 'Shrani hlode';

  @override
  String logsSaveSheetDefaultName(String date) {
    return 'Hlodi $date';
  }

  @override
  String get logsSavedSheetTitle => 'Shranjeni hlodi';

  @override
  String get logsSavedSheetEmpty => 'Ni shranjenih hlodov';

  @override
  String get logsSavedSheetNoName => 'Brez imena';

  @override
  String get logsSavedDeleteTitle => 'Izbriši shranjene hlode';

  @override
  String get logsSavedDeleteConfirm =>
      'Ali ste prepričani, da želite izbrisati ta zapis?\n\nHlodi se vrnejo na seznam Hlodi.';

  @override
  String get logsExportSheetName => 'Hlodi';

  @override
  String get logsExportHeaderDiameter => 'Premer (cm)';

  @override
  String get logsExportHeaderLength => 'Dolžina (m)';

  @override
  String get logsExportHeaderVolume => 'Volumen (m³)';

  @override
  String get logsExportHeaderNotes => 'Opombe';

  @override
  String get logsExportHeaderDate => 'Datum';

  @override
  String get logsExportShareSubject => 'Gozdar Hlodi Export';

  @override
  String logsExportShareText(int count) {
    return 'Izvoženih $count vnosov';
  }

  @override
  String get batchDefaultTitle => 'Shranjeni hlodi';

  @override
  String batchDeleteConfirm(String name, int count) {
    return 'Ali ste prepričani, da želite izbrisati \"$name\"?\n\nHlodi ($count) se vrnejo na seznam Hlodi.';
  }

  @override
  String get batchDeleteFallbackName => 'shranjene hlode';

  @override
  String get batchLogDeleted => 'Hlod izbrisan';

  @override
  String get batchNoLogsToExport => 'Ni hlodov za izvoz';

  @override
  String get batchEditInfoTooltip => 'Uredi info';

  @override
  String get batchEmptyHint => 'Tapnite + za dodajanje hloda';

  @override
  String batchAddTitleCount(int count) {
    return 'Dodaj (+$count)';
  }

  @override
  String get batchValidatorEnter => 'Vnesi';

  @override
  String batchVolumeLine(String volume) {
    return 'Volumen: $volume m³';
  }

  @override
  String get batchNotesHint => 'Dodatne opombe';

  @override
  String get forestTitle => 'Moj Gozd';

  @override
  String get forestFilterByOwner => 'Filtriraj po lastniku';

  @override
  String get forestMoreOptionsTooltip => 'Več možnosti gozda';

  @override
  String get forestExportKml => 'Izvozi KML';

  @override
  String get forestSummaryArea => 'Površina';

  @override
  String get forestSummaryParcels => 'Parcel';

  @override
  String get forestSummaryTrees => 'Dreves';

  @override
  String get forestSummaryCut => 'Posekano';

  @override
  String forestLoadError(String error) {
    return 'Napaka pri nalaganju: $error';
  }

  @override
  String forestDeleteError(String error) {
    return 'Napaka pri brisanju: $error';
  }

  @override
  String forestExportError(String error) {
    return 'Napaka pri izvozu: $error';
  }

  @override
  String get forestDeleteTitle => 'Izbriši parcelo';

  @override
  String forestDeleteConfirm(String name) {
    return 'Ali ste prepričani, da želite izbrisati \"$name\"?\n\nIzbrisane bodo tudi vse točke, sečnje in hlodovina znotraj parcele.';
  }

  @override
  String forestDeleted(String extra) {
    return 'Parcela izbrisana$extra';
  }

  @override
  String forestCountPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count točk',
      few: '$count točke',
      two: '$count točki',
      one: '$count točka',
    );
    return '$_temp0';
  }

  @override
  String forestCountParcels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parcel',
      few: '$count parcele',
      two: '$count parceli',
      one: '$count parcela',
    );
    return '$_temp0';
  }

  @override
  String forestCountTrees(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dreves',
      few: '$count drevesa',
      two: '$count drevesi',
      one: '$count drevo',
    );
    return '$_temp0';
  }

  @override
  String get forestNoParcelsToExport => 'Ni parcel za izvoz';

  @override
  String get forestKmlExported => 'KML uspešno izvožen';

  @override
  String get forestImportKml => 'Uvozi KML';

  @override
  String get forestImportTitle => 'Uvozi parcele';

  @override
  String forestImportConfirm(String count) {
    return 'Najdeno: $count. Jih uvozim?';
  }

  @override
  String get forestImportButton => 'Uvozi';

  @override
  String forestImportDone(String count, String area) {
    return 'Uvoženo: $count ($area)';
  }

  @override
  String get forestImportNoParcels => 'V datoteki ni veljavnih parcel.';

  @override
  String get forestImportFullTitle => 'Uvozi parcelo s podatki';

  @override
  String get forestImportFound => 'Najdeno:';

  @override
  String forestImportFellings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sečenj',
      few: '$count sečnje',
      two: '$count sečnji',
      one: '$count sečnja',
    );
    return '$_temp0';
  }

  @override
  String forestImportFullDone(String name) {
    return 'Uvožena parcela \"$name\"';
  }

  @override
  String forestImportError(String error) {
    return 'Napaka pri uvozu: $error';
  }

  @override
  String get forestNoOwners => 'Ni parcel z določenimi lastniki';

  @override
  String get forestShowAll => 'Prikaži vse';

  @override
  String forestNoParcelsForOwner(String owner) {
    return 'Ni parcel za \"$owner\"';
  }

  @override
  String get forestEmptyTitle => 'Ni še parcel';

  @override
  String get forestEmptyHint =>
      'Poiščite parcelo v katastru\nali jo uvozite iz KML';

  @override
  String get forestSearchParcel => 'Išči parcelo';

  @override
  String get forestNoKo => 'Brez KO';

  @override
  String forestKoLabel(String code) {
    return 'KO $code';
  }

  @override
  String get logsInlineDiameterHint => 'Premer';

  @override
  String get logsInlineLengthHint => 'Dolžina';

  @override
  String logsInlineDiameterRange(String min, String max) {
    return 'Premer mora biti med $min in $max cm';
  }

  @override
  String logsInlineLengthRange(String min, String max) {
    return 'Dolžina mora biti med $min in $max m';
  }

  @override
  String logsSpeciesExists(String name) {
    return 'Vrsta \"$name\" že obstaja';
  }

  @override
  String logsSavedToBatch(String name) {
    return 'Shranjeno v »$name« (Shranjeni hlodi)';
  }

  @override
  String get logsOpenAction => 'Odpri';

  @override
  String mapTabMejnikName(int number, String parcela) {
    return 'Mejnik $number ($parcela)';
  }

  @override
  String get mapTabLocationServicesDisabled =>
      'Lokacijske storitve so onemogočene';

  @override
  String get mapTabLocationPermissionDenied =>
      'Dovoljenje za lokacijo zavrnjeno';

  @override
  String get mapTabLocationPermissionDeniedForever =>
      'Dovoljenje za lokacijo trajno zavrnjeno';

  @override
  String mapTabLocationError(Object error) {
    return 'Napaka pri pridobivanju lokacije: $error';
  }

  @override
  String mapTabLocationAdded(String name) {
    return 'Dodano \"$name\"';
  }

  @override
  String mapTabErrorWithMessage(Object error) {
    return 'Napaka: $error';
  }

  @override
  String mapTabLocationAddError(Object error) {
    return 'Napaka pri dodajanju lokacije: $error';
  }

  @override
  String mapTabSecnjaMarked(String name) {
    return 'Sečnja \"$name\" označena';
  }

  @override
  String mapTabSecnjaMarkError(Object error) {
    return 'Napaka pri označevanju sečnje: $error';
  }

  @override
  String mapTabLogAdded(String volume) {
    return 'Hlod dodan ($volume m³)';
  }

  @override
  String mapTabLogAddError(Object error) {
    return 'Napaka pri dodajanju hloda: $error';
  }

  @override
  String mapTabLocationDeleted(String name) {
    return 'Izbrisano \"$name\"';
  }

  @override
  String mapTabLocationDeleteError(Object error) {
    return 'Napaka pri brisanju lokacije: $error';
  }

  @override
  String mapTabNoCadastreData(String region) {
    return 'Za regijo $region ni podatkov katastra.';
  }

  @override
  String mapTabRegionNotInList(String name) {
    return 'Regije $name ni v seznamu.';
  }

  @override
  String mapTabRegionDownloaded(String name, int count) {
    return '$name: prenesenih $count parcel.';
  }

  @override
  String get mapTabDownloadCancelled => 'Prenos preklican.';

  @override
  String mapTabDownloadFailed(Object error) {
    return 'Prenos ni uspel: $error';
  }

  @override
  String get mapTabNoParcelAtLocation => 'Na tej lokaciji ni najdene parcele';

  @override
  String mapTabParcelSearchError(Object error) {
    return 'Napaka pri iskanju parcele: $error';
  }

  @override
  String get mapTabUnknownOwner => 'Neznan lastnik';

  @override
  String mapTabParcelKo(String parcela, Object ko) {
    return 'Parcela $parcela (KO $ko)';
  }

  @override
  String get mapTabOwnerOffline => 'Lastnik (offline)';

  @override
  String get mapTabApproximateOffline => '≈ približno (brez povezave)';

  @override
  String get mapTabParcelExistsTitle => 'Parcela že obstaja';

  @override
  String mapTabParcelExistsBody(Object ko, Object number) {
    return 'Parcela $ko - $number je že v vaših parcelah.';
  }

  @override
  String mapTabParcelExistsLabelBody(String label) {
    return 'Parcela $label je že v vaših parcelah.';
  }

  @override
  String get mapTabShowInMyParcels => 'Prikaži v mojih parcelah';

  @override
  String get mapTabImportParcelTitle => 'Uvozi parcelo';

  @override
  String get mapTabImportParcelQuestion =>
      'Ali želite uvoziti to parcelo v \"Moj gozd\"?';

  @override
  String get mapTabPrint => 'Natisni';

  @override
  String get mapTabImport => 'Uvozi';

  @override
  String mapTabPdfOpenFailed(Object message) {
    return 'PDF ni mogoče odpreti: $message';
  }

  @override
  String mapTabPdfError(Object error) {
    return 'Napaka pri pripravi PDF: $error';
  }

  @override
  String mapTabParcelImported(Object ko, Object number) {
    return 'Parcela $ko - $number uspešno uvožena';
  }

  @override
  String mapTabParcelImportError(Object error) {
    return 'Napaka pri uvozu parcele: $error';
  }

  @override
  String get mapTabKmlUnsupported => 'KML/KMZ uvoz še ni podprt preko karte';

  @override
  String mapTabImportError(Object error) {
    return 'Napaka pri uvozu: $error';
  }

  @override
  String mapTabParcelTitle(Object number, Object ko) {
    return 'Parc. $number • KO $ko';
  }

  @override
  String mapTabParcelTitleWithKo(Object number, Object ko, String koName) {
    return 'Parc. $number • KO $ko $koName';
  }

  @override
  String mapTabParcelShort(Object number) {
    return 'Parc. $number';
  }

  @override
  String get mapTabSelectedPoint => 'Izbrana točka';

  @override
  String get mapTabMejnikiHint =>
      'Dolgo pritisnite na parcelo za prikaz mejnikov.';

  @override
  String get mapTabNoActiveMeasurement => 'Ni aktivnega merjenja';

  @override
  String get mapTabHintStart =>
      'Dolgo pritisnite na karto za začetek merjenja.';

  @override
  String get mapTabHintFinished => 'Merjenje je zaključeno.';

  @override
  String get mapTabHintMoveMap =>
      'Premaknite karto, da nitni križ kaže na točko, in tapnite »Dodaj točko«.';

  @override
  String get mapTabHintNextPointDistance =>
      'Naslednjo točko dodajte z nitnim križem ali zaključite merjenje.';

  @override
  String get mapTabHintMinPointsArea =>
      'Z nitnim križem dodajte vsaj 3 točke za površino.';

  @override
  String get mapTabHintNextPointPolygon =>
      'Naslednjo točko dodajte z nitnim križem ali zaključite poligon.';

  @override
  String get mapTabMeasureArea => 'Merjenje površine';

  @override
  String get mapTabMeasureDistance => 'Merjenje razdalje';

  @override
  String get mapTabAddPoint => 'Dodaj točko';

  @override
  String get mapTabUndo => 'Razveljavi';

  @override
  String get mapTabFinish => 'Zaključi';

  @override
  String get mapTabLoadingMap => 'Nalagam karto...';

  @override
  String mapTabParcelLabel(String label) {
    return 'Parcela $label';
  }

  @override
  String mapTabTilesDownloadPercent(String percent) {
    return 'Prenos kart $percent%';
  }

  @override
  String mapTabTilesDownloadStats(
    int downloaded,
    int cached,
    int failed,
    int total,
  ) {
    return 'Preneseno $downloaded, v predpomnilniku $cached, napake $failed / $total';
  }

  @override
  String get mapTabSearchingParcel => 'Iskanje parcele...';

  @override
  String mapTabRegionDownloading(String name, String mb, String totMb) {
    return 'Prenašam $name… $mb/$totMb MB';
  }

  @override
  String get mapTabParcelImportedSimple => 'Parcela je bila uvožena';

  @override
  String get mapTabUsageRightsTitle => 'Pravice uporabe podatkov';

  @override
  String get mapTabUsageGuName => 'Geodetska uprava RS';

  @override
  String get mapTabUsageGuDesc =>
      'Podatki Geodetske uprave Republike Slovenije (ortofoto, kataster, topografske karte) so na voljo pod pogoji odprtih podatkov. Uporaba je dovoljena za nekomercialne in komercialne namene ob navedbi vira.';

  @override
  String get mapTabUsageDguName => 'Državna geodetska uprava RH';

  @override
  String get mapTabUsageDguDesc =>
      'Katastrski podatki in podatki o posestnikih s portala Uređena zemlja so uradni podatki Republike Hrvaške. So informativni in namenjeni le osebni uporabi; ni jih dovoljeno uporabljati v komercialne namene ali jih posredovati naprej.';

  @override
  String get mapTabUsageZgsName => 'Zavod za gozdove Slovenije';

  @override
  String get mapTabUsageZgsDesc =>
      'Gozdarski podatki (gozdne združbe, sestojna karta, rastiščni koeficienti) so javno dostopni. Uporaba je dovoljena za informativne namene. Za komercialno uporabo je potrebno pridobiti dovoljenje ZGS.';

  @override
  String get mapTabUsageOsmDesc =>
      'Kartografski podatki OpenStreetMap so na voljo pod licenco Open Database License (ODbL). Uporaba je dovoljena ob navedbi \"© OpenStreetMap contributors\".';

  @override
  String get mapTabUsageEsriDesc =>
      'Esri satelitski posnetki so na voljo za osebno in nekomercialno uporabo. Za komercialno uporabo je potrebna licenca.';

  @override
  String get mapTabUsageDisclaimer =>
      'Ta aplikacija je namenjena informativni uporabi. Za uradne podatke se obrnite na pristojne institucije.';

  @override
  String mapTabLocationRenamed(String newName) {
    return 'Lokacija preimenovana v \"$newName\"';
  }

  @override
  String get mapwAddLocationTitle => 'Dodaj lokacijo';

  @override
  String get mapwAddLocationHint =>
      'Koordinate iz dolgo-pritiska ali vnesite svoje';

  @override
  String get mapwLatLabel => 'Zemljepisna širina (Lat)';

  @override
  String get mapwLngLabel => 'Zemljepisna dolžina (Lng)';

  @override
  String get mapwLatExample => 'npr. 46.0569';

  @override
  String get mapwLngExample => 'npr. 14.5058';

  @override
  String get mapwEnterLat => 'Vnesite širino';

  @override
  String get mapwEnterLng => 'Vnesite dolžino';

  @override
  String get mapwInvalidNumber => 'Neveljavna številka';

  @override
  String get mapwLatRange => 'Širina mora biti med -90 in 90';

  @override
  String get mapwLngRange => 'Dolžina mora biti med -180 in 180';

  @override
  String get mapwLatNotInSlovenia =>
      'Lokacija ni v Sloveniji ali na Hrvaškem (42.3-46.9)';

  @override
  String get mapwLngNotInSlovenia =>
      'Lokacija ni v Sloveniji ali na Hrvaškem (13.3-19.5)';

  @override
  String get mapwLocationNameLabel => 'Ime lokacije';

  @override
  String get mapwLocationNameHint => 'Vnesite ime za to lokacijo';

  @override
  String get mapwEnterName => 'Vnesite ime';

  @override
  String get mapwMarkFellingTitle => 'Označi sečnjo';

  @override
  String get mapwTreeDescLabel => 'Opis drevesa';

  @override
  String get mapwTreeDescHint => 'npr. Hrast, Bukev, Smreka...';

  @override
  String get mapwEnterDescription => 'Prosim vnesite opis';

  @override
  String get mapwMarkAction => 'Označi';

  @override
  String get mapwDeleteLocationTitle => 'Izbriši lokacijo';

  @override
  String mapwDeleteLocationSure(String name) {
    return 'Ali ste prepričani, da želite izbrisati \"$name\"?';
  }

  @override
  String get mapwAddLocationByCoordsTitle => 'Dodaj lokacijo s koordinatami';

  @override
  String get mapwEnterWgs84Hint =>
      'Vnesite koordinate v WGS84 formatu (decimalne stopinje)';

  @override
  String get mapwRenameLocationTitle => 'Preimenuj lokacijo';

  @override
  String get mapwNameLabel => 'Ime';

  @override
  String mapwParcelTitle(String number) {
    return 'Parcela $number';
  }

  @override
  String get mapwCadastralParcel => 'Katastrska parcela';

  @override
  String get mapwCadastralMunicipality => 'Katastrska občina';

  @override
  String get mapwArea => 'Površina';

  @override
  String get mapwOwner => 'Lastnik';

  @override
  String mapwDeleteLocationQuestion(String name) {
    return 'Ali res želite izbrisati lokacijo \"$name\"?';
  }

  @override
  String get mapwResetOnboardingTitle => 'Ponastavi uvodni vodič';

  @override
  String get mapwResetOnboardingBody =>
      'Ali res želite ponastaviti uvodni vodič? Ponovno zaženite aplikacijo.';

  @override
  String get mapwReset => 'Ponastavi';

  @override
  String get mapwMenuMeasure => 'Merjenje';

  @override
  String get mapwMenuNavigate => 'Navigiraj';

  @override
  String get mapwMenuParcel => 'Parcela';

  @override
  String get mapwMenuImport => 'Uvozi';

  @override
  String mapwPublicParcel(String category) {
    return 'Javna parcela • $category';
  }

  @override
  String get mapwMenuPoint => 'Točka';

  @override
  String get mapwMenuLogs => 'Hlodovina';

  @override
  String get mapwMenuFelling => 'Sečnja';

  @override
  String get mapwMenuDistance => 'Razdalja';

  @override
  String get mapwMenuBoundaries => 'Mejniki';

  @override
  String get mapwSelectLayer => 'Izberi sloj';

  @override
  String get mapwSearchParcelByKo => 'Išči parcelo po KO';

  @override
  String get mapwZoomIn => 'Povečaj karto';

  @override
  String get mapwZoomOut => 'Pomanjšaj karto';

  @override
  String get mapwCenterOnGps => 'Centriraj na GPS lokacijo';

  @override
  String get mapwSavedLocations => 'Shranjene lokacije';

  @override
  String get mapwLayersTitle => 'Sloji karte';

  @override
  String get mapwTabBase => 'Podlaga';

  @override
  String get mapwTabOverlays => 'Prekrivni sloji';

  @override
  String get mapwInternationalMaps => 'Mednarodne karte';

  @override
  String get mapwSlovenianMaps => 'Slovenske karte';

  @override
  String get mapwDownloadOffline => 'Prenesi za delo brez povezave';

  @override
  String get mapwImportGeodata => 'Uvozi geodatke (KML, KMZ)';

  @override
  String get mapwNoResults => 'Ni rezultatov';

  @override
  String mapwActiveCount(int count) {
    return '$count aktivnih';
  }

  @override
  String get mapwPublicParcels => 'Javne parcele';

  @override
  String get mapwVlakeHint => 'Vlake (pri večji povečavi)';

  @override
  String get mapwAddByCoordinates => 'Dodaj s koordinatami';

  @override
  String get mapwSectionPoints => 'Točke';

  @override
  String get mapwNoSavedLocations => 'Ni shranjenih lokacij';

  @override
  String get mapwRename => 'Preimenuj';

  @override
  String get mapwNavAppOpenFailed =>
      'Aplikacije za navigacijo ni bilo mogoče odpreti.';

  @override
  String get mapwGoogleMaps => 'Google Zemljevidi';

  @override
  String get mapwAppleMaps => 'Apple Zemljevidi';

  @override
  String get mapwRoadNavigation => 'Navigacija po cesti';

  @override
  String get mapwInAppCompass => 'Kompas v aplikaciji';

  @override
  String get mapwInAppCompassHint =>
      'Smer in razdalja do cilja, tudi brez spleta';

  @override
  String get mapwCopyCoordinates => 'Kopiraj koordinate';

  @override
  String get mapwCoordinatesCopied => 'Koordinate kopirane';

  @override
  String get mapwCompassN => 'S';

  @override
  String get mapwCompassE => 'V';

  @override
  String get mapwCompassS => 'J';

  @override
  String get mapwCompassW => 'Z';

  @override
  String get mapwCompassNE => 'SV';

  @override
  String get mapwCompassSE => 'JV';

  @override
  String get mapwCompassSW => 'JZ';

  @override
  String get mapwCompassNW => 'SZ';

  @override
  String mapwCompassLowAccuracy(int degrees) {
    return 'Nizka natančnost kompasa (±$degrees°). Kalibrirajte napravo.';
  }

  @override
  String mapwCompassMediumAccuracy(int degrees) {
    return 'Zmerna natančnost kompasa (±$degrees°)';
  }

  @override
  String get mapwLocationPermissionDenied =>
      'Dovoljenje za lokacijo zavrnjeno — razdalja ni na voljo';

  @override
  String get mapwCompass => 'Kompas';

  @override
  String get mapwDistance => 'Razdalja';

  @override
  String get mapwAzimuth => 'Azimut';

  @override
  String get mapwDirection => 'Smer';

  @override
  String get mapwTileTemplateUnavailable => 'URL predloge ni na voljo';

  @override
  String get mapwDownloadComplete => 'Prenos končan';

  @override
  String get mapwClearCacheTitle => 'Počisti predpomnilnik?';

  @override
  String get mapwClearCacheBody =>
      'Vse prenesene ploščice bodo izbrisane. Te operacije ni mogoče razveljaviti.';

  @override
  String get mapwCacheCleared => 'Predpomnilnik izpraznjen';

  @override
  String mapwSyncing(String name) {
    return 'Sinhroniziram $name';
  }

  @override
  String mapwSyncDownloaded(int done, int total) {
    return 'Preneseno $done/$total';
  }

  @override
  String mapwSyncFromCache(int done, int total) {
    return 'Iz predpomnilnika $done/$total';
  }

  @override
  String mapwSyncDone(int downloaded, int skipped, int failed) {
    return 'Končano! $downloaded prenesenih, $skipped iz predpomnilnika, $failed neuspešnih';
  }

  @override
  String get mapwSyncCancelled => 'Sinhronizacija preklicana';

  @override
  String get mapwTileSharing => 'Deljenje ploščic';

  @override
  String get mapwShareMyTiles => 'Deli moje ploščice';

  @override
  String get mapwSharingOnHint =>
      'Druge naprave lahko prenesejo ploščice s te naprave';

  @override
  String get mapwSharingOffHint =>
      'Začni deliti predpomnjene ploščice z bližnjimi napravami';

  @override
  String get mapwMyCachedMaps => 'Moje predpomnjene karte';

  @override
  String mapwTilesAndSize(String tiles, String size) {
    return '$tiles ploščic, $size';
  }

  @override
  String get mapwNearbyDevices => 'Bližnje naprave';

  @override
  String get mapwRefresh => 'Osveži';

  @override
  String get mapwAddDeviceManually => 'Ročno dodaj napravo';

  @override
  String get mapwNoDevicesFound =>
      'V lokalnem omrežju ni najdenih naprav.\nPreverite, da imajo druge naprave vključeno deljenje ploščic.';

  @override
  String get mapwFetchingCatalog => 'Pridobivam katalog';

  @override
  String get mapwNoCachedTilesOnDevice =>
      'Na tej napravi ni predpomnjenih ploščic';

  @override
  String mapwYouHave(String count) {
    return ' (imate $count)';
  }

  @override
  String get mapwDownloadAll => 'Prenesi vse';

  @override
  String get mapwAddDeviceTitle => 'Dodaj napravo';

  @override
  String get mapwIpAddress => 'IP naslov';

  @override
  String mapwDeleteStyleTitle(String name) {
    return 'Izbriši $name?';
  }

  @override
  String mapwDeleteStyleBody(String tiles, String size) {
    return '$tiles ploščic, $size bo izbrisanih.';
  }

  @override
  String get mapwTileDownloadTitle => 'Prenos kart';

  @override
  String get mapwForOfflineWork => 'Za delo brez povezave';

  @override
  String get mapwSharingEnabled => 'Deljenje ploščic vključeno';

  @override
  String get mapwSharingDisabled => 'Deljenje ploščic izklopljeno';

  @override
  String get mapwLayersShort => 'Sloji';

  @override
  String get mapwZoomLevel => 'Povečava';

  @override
  String get mapwEstimate => 'Ocena';

  @override
  String mapwEstimatedTiles(int count) {
    return '~$count ploščic';
  }

  @override
  String mapwDownloadingPercent(String percent) {
    return 'Prenašam... $percent%';
  }

  @override
  String get mapwLayerNotDownloadable => 'Sloj ni na voljo za prenos';

  @override
  String get mapwNoXyzTemplate =>
      'Za ta sloj ni bilo mogoče določiti XYZ predloge.';

  @override
  String get mapwCache => 'Predpomnilnik';

  @override
  String mapwCacheStats(String tiles, String size) {
    return '$tiles ploščic ($size MB)';
  }

  @override
  String get mapwClearCache => 'Počisti predpomnilnik';

  @override
  String mapwParcelAlreadyInDb(String municipality, String number) {
    return 'Parcela $municipality - $number je že v bazi podatkov';
  }

  @override
  String get mapwLegendTitle => 'Legenda';

  @override
  String get mapwLegendOwnParcels => 'Moje parcele';

  @override
  String get mapwLegendCadastre => 'Kataster';

  @override
  String get mapwLegendSelected => 'Izbrana parcela';

  @override
  String get mapwLegendPreview => 'Predogled uvoza';

  @override
  String get mapwLegendSearched => 'Najdena parcela';

  @override
  String get mapwLegendAuctions => 'Dražbe';

  @override
  String get mapwGpsLost => 'Ni GPS signala';

  @override
  String get mapwGpsNoFixYet => 'čakam na položaj';

  @override
  String mapwGpsLastFixAge(int seconds) {
    return 'zadnji položaj pred $seconds s';
  }

  @override
  String mapwEstimatedTilesAndSize(int count, String size) {
    return '~$count ploščic · približno $size';
  }

  @override
  String get auctionsUnavailable =>
      'Seznama dražb ni bilo mogoče naložiti. Preverite povezavo.';

  @override
  String get auctionsLoadError => 'Napaka pri nalaganju dražb.';

  @override
  String get auctionsRetry => 'Poskusi znova';

  @override
  String get parcelSearchShowOnMap => 'Pokaži na karti';

  @override
  String get parcelSearchUseKo => 'Išči v tej k.o.';

  @override
  String get mapwCatAdministrativno => 'Administrativno';

  @override
  String get mapwCatInfrastruktura => 'Infrastruktura';

  @override
  String get mapwCatGozdnoGospodarstvo => 'Gozdno gospodarstvo';

  @override
  String get mapwCatZavarovanaObmocja => 'Zavarovana območja';

  @override
  String get mapwCatNevarnostiInSkode => 'Nevarnosti in škode';

  @override
  String get mapwCatFunkcijeGozda => 'Funkcije gozda';

  @override
  String get mapwCatPosebno => 'Posebno';

  @override
  String get mapwCatHrvatska => 'Hrvaška (DGU)';

  @override
  String get parcelPointUnknown => 'Točka ?';

  @override
  String parcelPointNumbered(int number) {
    return 'Točka $number';
  }

  @override
  String parcelDetailUpdateError(String error) {
    return 'Napaka pri posodabljanju: $error';
  }

  @override
  String get parcelDetailPreparingPdf => 'Pripravljam PDF …';

  @override
  String parcelDetailPdfOpenError(String message) {
    return 'PDF ni mogoče odpreti: $message';
  }

  @override
  String parcelDetailPdfError(String error) {
    return 'Napaka pri pripravi PDF: $error';
  }

  @override
  String get parcelDetailPreparingExport => 'Pripravljam izvoz …';

  @override
  String get parcelDetailExportDone => 'Izvoz zaključen';

  @override
  String parcelDetailExportError(String error) {
    return 'Napaka pri izvozu: $error';
  }

  @override
  String get parcelForestTypeTitle => 'Vrsta gozda';

  @override
  String get parcelForestTypeDeciduous => 'Listavci';

  @override
  String get parcelForestTypeMixed => 'Mešani gozd';

  @override
  String get parcelForestTypeConiferous => 'Iglavci';

  @override
  String get parcelOwnerTitle => 'Lastnik';

  @override
  String get parcelOwnerNameLabel => 'Ime lastnika';

  @override
  String get parcelOwnerNameHint => 'Vnesite ime lastnika';

  @override
  String get parcelNotesTitle => 'Opombe';

  @override
  String get parcelAllowanceTitle => 'Dovoljen posek';

  @override
  String get parcelAllowanceAmountLabel => 'Količina (m³)';

  @override
  String get parcelAllowanceAmountHint => 'Vnesite dovoljeno količino';

  @override
  String get parcelInvalidNumber => 'Neveljavna številka';

  @override
  String get parcelLogCutTitle => 'Zabeleži posek';

  @override
  String parcelCutCurrent(String volume) {
    return 'Trenutno posekano: $volume m³';
  }

  @override
  String parcelCutRemaining(String volume) {
    return 'Še na voljo: $volume m³';
  }

  @override
  String get parcelCutAddLabel => 'Dodaj posek (m³)';

  @override
  String get parcelCutAddHint => 'Vnesite količino';

  @override
  String get parcelTreesCountLabel => 'Število dreves';

  @override
  String get parcelTreesCountHint => 'Vnesite število';

  @override
  String get parcelTreesUnit => 'dreves';

  @override
  String get parcelCutInvalidAmount => 'Vnesite veljavno količino poseka';

  @override
  String parcelCutAddedWithTrees(String volume, int trees) {
    return 'Dodano $volume m³ poseka ($trees dreves)';
  }

  @override
  String parcelCutAdded(String volume) {
    return 'Dodano $volume m³ poseka';
  }

  @override
  String get parcelResetCutTitle => 'Ponastavi posek';

  @override
  String get parcelResetCutMessage =>
      'Ali ste prepričani, da želite ponastaviti količino posekanega lesa na 0?';

  @override
  String get parcelReset => 'Ponastavi';

  @override
  String get parcelAddTreesTitle => 'Dodaj posekana drevesa';

  @override
  String get parcelResetTreesTitle => 'Ponastavi drevesa';

  @override
  String get parcelResetTreesMessage =>
      'Ali ste prepričani, da želite ponastaviti število posekanih dreves na 0?';

  @override
  String get parcelDeleteTitle => 'Izbriši parcelo';

  @override
  String parcelDeleteMessage(String name) {
    return 'Ali ste prepričani, da želite izbrisati \"$name\"?\n\nIzbrisane bodo tudi vse točke, sečnje in hlodovina znotraj parcele.';
  }

  @override
  String parcelDeletedLogsExtra(int count) {
    return '$count hlodov';
  }

  @override
  String parcelDeletedPointsExtra(int count) {
    return '$count točk';
  }

  @override
  String get parcelDeleted => 'Parcela izbrisana';

  @override
  String parcelDeletedWithExtras(String extras) {
    return 'Parcela izbrisana ($extras)';
  }

  @override
  String parcelDeleteError(String error) {
    return 'Napaka pri brisanju: $error';
  }

  @override
  String get parcelEditShape => 'Uredi obliko';

  @override
  String get parcelPrint => 'Natisni';

  @override
  String get parcelExportKml => 'Izvozi KML';

  @override
  String get parcelViewOnMap => 'Na karti';

  @override
  String get parcelNavigate => 'Navigiraj';

  @override
  String get parcelEditorNeedThreePoints => 'Narišite vsaj 3 točke';

  @override
  String get parcelEditorNameRequired => 'Prosim vnesite ime';

  @override
  String get parcelEditorBaseLayer => 'Osnovni sloj';

  @override
  String get parcelEditorOverlayLayers => 'Prekrivni sloji';

  @override
  String get parcelEditorAddTitle => 'Dodaj parcelo';

  @override
  String get parcelEditorEditTitle => 'Uredi parcelo';

  @override
  String get parcelEditorNameLabel => 'Ime parcele';

  @override
  String get parcelForestTypeMixedShort => 'Mešani';

  @override
  String parcelEditorTapToAdd(int count) {
    return 'Tapnite na zemljevid za dodajanje točk ($count točk)';
  }

  @override
  String get parcelEditorDrawingDone => 'Risanje zaključeno';

  @override
  String parcelEditorArea(String area) {
    return 'Površina: $area';
  }

  @override
  String get parcelEditorClear => 'Počisti';

  @override
  String parcelLogsCardTitle(int count) {
    return 'Hlodovina na parceli ($count)';
  }

  @override
  String get parcelManualEntry => 'Ročni vnos';

  @override
  String parcelLogName(int id) {
    return 'Hlod $id';
  }

  @override
  String parcelMoreLogs(int count) {
    return '... in še $count hlodov';
  }

  @override
  String parcelSavedPointsTitle(int count) {
    return 'Shranjene točke ($count)';
  }

  @override
  String parcelSecnjaTitle(int count) {
    return 'Sečnja ($count)';
  }

  @override
  String parcelFoundTitle(String label) {
    return 'Parcela $label';
  }

  @override
  String parcelFoundKo(String ko) {
    return 'KO $ko';
  }

  @override
  String get parcelFoundOwnersLoading => 'Iščem lastnike …';

  @override
  String ownerAndMore(String first, int count) {
    return '$first in še $count';
  }

  @override
  String ownersTitle(int count) {
    return 'Lastniki ($count)';
  }

  @override
  String ownersShowAll(int count) {
    return 'Pokaži vse ($count)';
  }

  @override
  String get parcelFoundHide => 'Skrij';

  @override
  String get parcelFoundOpen => 'Odpri parcelo';

  @override
  String get parcelFoundImport => 'Uvozi parcelo';

  @override
  String parcelPointsCount(int count) {
    return '$count točk';
  }

  @override
  String get parcelInfoAdded => 'Dodano';

  @override
  String get parcelInfoParcel => 'Parcela';

  @override
  String get parcelInfoKo => 'Katastrska občina';

  @override
  String get valuationTitle => 'Vrednost parcele';

  @override
  String get valuationLoading => 'Iščem vrednost pri GURS …';

  @override
  String valuationPerM2(String value) {
    return '$value €/m²';
  }

  @override
  String get valuationUnvalued =>
      'GURS za zemljišče te parcele nima vrednosti.';

  @override
  String valuationLevel(String level) {
    return 'raven $level';
  }

  @override
  String get valuationBoniteta => 'Boniteta';

  @override
  String get valuationSiteIndex => 'Rastiščni koeficient';

  @override
  String get valuationOpenness => 'Odprtost';

  @override
  String get valuationBonitetaHint =>
      'Kakovost tal, od 0 do 100 – več je bolje';

  @override
  String get valuationSiteIndexHint =>
      'Kako dobro na rastišču raste drevje – več je bolje';

  @override
  String get valuationOpennessHint =>
      'Kolikšen del gozda je dostopen s cestami in vlakami';

  @override
  String auctionLine(String price, String date) {
    return 'Na dražbi: $price € · $date';
  }

  @override
  String auctionLineNoPrice(String date) {
    return 'Na dražbi · $date';
  }

  @override
  String get auctionTitle => 'Sodna dražba';

  @override
  String get auctionStarting => 'Izklicna cena';

  @override
  String get auctionEstimated => 'Ocenjena vrednost';

  @override
  String get auctionShare => 'Delež v prodaji';

  @override
  String get auctionDate => 'Začetek prodaje';

  @override
  String get auctionCourt => 'Sodišče';

  @override
  String get auctionActive => 'Dražba poteka';

  @override
  String get auctionOpen => 'Odpri objavo na sodnedrazbe.si';

  @override
  String get auctionSource =>
      'Podatki: sodnedrazbe.si. Pred oddajo ponudbe preverite objavo.';

  @override
  String get auctionLayer => 'Sodne dražbe';

  @override
  String get auctionLayerHint => 'Parcele, ki so trenutno na sodni dražbi';

  @override
  String get searchTabParcels => 'Parcele';

  @override
  String get searchTabAuctions => 'Dražbe';

  @override
  String get auctionsLoading => 'Nalagam sodne dražbe …';

  @override
  String get auctionsEmpty => 'Ni dražb, ki bi ustrezale iskanju.';

  @override
  String get auctionsHint =>
      'Najbližje dražbe so na vrhu. Iščete lahko po katastrski občini ali številki parcele.';

  @override
  String valuationSource(String date) {
    return 'Posplošena tržna vrednost GURS, izračun $date. Podatki so informativni.';
  }

  @override
  String get valuationSourceUndated =>
      'Posplošena tržna vrednost GURS. Podatki so informativni.';

  @override
  String get valuationOpenGurs => 'Odpri v evidenci vrednotenja';

  @override
  String get valuationModelGOZ => 'Gozd';

  @override
  String get valuationModelKME => 'Kmetijsko zemljišče';

  @override
  String get valuationModelSTZ => 'Stavbno zemljišče';

  @override
  String get valuationModelZPS => 'Zemljišče pod stavbo';

  @override
  String get valuationModelDRZ => 'Druga zemljišča';

  @override
  String get parcelNotSet => 'Ni določen';

  @override
  String get parcelFromCadastre => 'iz katastra (GURS)';

  @override
  String get parcelNoNotes => 'Ni opomb';

  @override
  String get parcelWoodTitle => 'Posek lesa';

  @override
  String get parcelCutLabel => 'Posekano';

  @override
  String parcelWoodUsed(String percent) {
    return '$percent% izkoriščeno';
  }

  @override
  String get parcelTreesCutLabel => 'Posekanih dreves';

  @override
  String get parcelLogCutButton => 'Posek m³';

  @override
  String get parcelTreeButton => 'Drevo';

  @override
  String parcelSearchNotFound(String number) {
    return 'Parcela $number ni najdena.';
  }

  @override
  String parcelSearchError(String error) {
    return 'Napaka pri iskanju: $error';
  }

  @override
  String get parcelSearchTitle => 'Iskanje parcele';

  @override
  String get parcelSearchAllKo => 'Vse katastrske občine';

  @override
  String get parcelSearchByMapPosition => 'Po legi na zemljevidu';

  @override
  String get parcelSearchRemoveKo => 'Odstrani katastrsko občino';

  @override
  String get parcelSearchHint => 'Parcela, lastnik, naslov ali k.o.';

  @override
  String get parcelSearchHelper => 'npr. 123/4, Novak Babno ali Škofja Loka';

  @override
  String get parcelSearchPromptNoKo =>
      'Vnesite številko parcele, ime lastnika, naslov ali katastrsko občino.';

  @override
  String get parcelSearchPromptWithKo =>
      'Vnesite številko parcele (npr. 123/4), ime lastnika ali naslov.';

  @override
  String parcelSearchNeedsKoHint(String number) {
    return 'Za parcelo $number izberite katastrsko občino: vnesite njeno ime.';
  }

  @override
  String get parcelSearchNoResults => 'Ni zadetkov.';

  @override
  String parcelSearchNeedsKo(String number) {
    return 'Za parcelo $number izberite katastrsko občino.';
  }

  @override
  String get parcelMapPreviewLabel => 'Karta';

  @override
  String get parcelPdfKo => 'Katastrska občina';

  @override
  String get parcelPdfNumber => 'Parcelna številka';

  @override
  String get parcelPdfArea => 'Površina';

  @override
  String get parcelPdfAddress => 'Naslov';

  @override
  String get parcelPdfMunicipality => 'Občina';

  @override
  String get parcelPdfMapFailed => 'Zemljevida ni bilo mogoče naložiti';

  @override
  String parcelPdfFooter(String date) {
    return 'Gozdar • Izpisano: $date';
  }

  @override
  String get parcelPdfSource => 'Vir: © GURS, © ZGS';

  @override
  String parcelSearchKoSubtitle(int sifko) {
    return 'Katastrska občina $sifko';
  }

  @override
  String get notesDiscardTitle => 'Zavrzi spremembe?';

  @override
  String get notesDiscardMessage => 'Spremembe zapiskov še niso shranjene.';

  @override
  String get notesKeepEditing => 'Nadaljuj urejanje';

  @override
  String get notesDiscard => 'Zavrzi';

  @override
  String get svcKmlExportSubject => 'Gozdar Parcels Export';

  @override
  String svcKmlExportText(int count) {
    return 'Exported $count parcels';
  }

  @override
  String svcKmlParcelShareSubject(String name) {
    return 'Parcela $name';
  }

  @override
  String svcKmlParcelShareText(
    String name,
    int logs,
    int fellings,
    int points,
  ) {
    return 'Izvoz parcele $name z $logs hlodi, $fellings sečnjami in $points točkami';
  }

  @override
  String svcDownloadFailedHttp(int status) {
    return 'Prenos ni uspel (HTTP $status).';
  }

  @override
  String svcParcelDisplayName(String number, int ko) {
    return 'Parcela $number (KO $ko)';
  }

  @override
  String svcParcelDisplayNameRef(String label, String ref) {
    return 'Parcela $label ($ref)';
  }

  @override
  String get svcLayerParcel => 'Parcela';

  @override
  String get svcLayerStand => 'Sestoj';

  @override
  String get svcLayerSection => 'Odsek';

  @override
  String get svcLayerDistrict => 'Revir';

  @override
  String get svcLayerGge => 'GGE';

  @override
  String get svcLayerGgo => 'GGO';

  @override
  String get svcLayerForestReserve => 'Gozdni rezervat';

  @override
  String get svcLayerProtectiveForest => 'Varovalni gozd';

  @override
  String get svcLayerProtectedArea => 'Zavarovano območje';

  @override
  String get svcLayerNaturalValue => 'Naravna vrednota';

  @override
  String get svcLayerEpo => 'EPO';

  @override
  String get svcLayerHuntingGround => 'Lovišče';

  @override
  String get svcLayerFireRisk => 'Požarna ogroženost';

  @override
  String get svcLayerMunicipality => 'Občina';

  @override
  String get svcLayerCadastralMunicipality => 'Katastrska občina';

  @override
  String get svcAesBadFormat =>
      'Datoteka ni v pričakovani obliki (napačna glava).';

  @override
  String get svcAesCorrupt => 'Datoteka je okvarjena ali nepopolna.';

  @override
  String get svcAesWrongPassword => 'Napačno geslo.';

  @override
  String get svcNetTimeout => 'Povezava je potekla. Prosimo, poskusite znova.';

  @override
  String get svcNetNoConnection => 'Ni internetne povezave. Preverite omrežje.';

  @override
  String get svcNetServerError => 'Strežnik ni dosegljiv. Poskusite pozneje.';

  @override
  String get svcNetUnknown => 'Prišlo je do napake. Poskusite znova.';

  @override
  String get aboutTitle => 'Nastavitve';

  @override
  String get aboutSectionMapSources => 'Viri kartografskih podatkov';

  @override
  String get aboutSectionLegal => 'Pravne informacije';

  @override
  String get aboutSectionOpenSource => 'Odprtokodne knjižnice';

  @override
  String get aboutSectionSupport => 'Podpora';

  @override
  String get aboutSectionGeneral => 'Splošno';

  @override
  String get aboutSectionMapCache => 'Shramba';

  @override
  String get aboutTagline =>
      'Aplikacija za lastnike gozdov in gozdarske delavce v Sloveniji';

  @override
  String get aboutInfoTitle => 'Informacije o aplikaciji';

  @override
  String get aboutVersion => 'Verzija';

  @override
  String get aboutBuildNumber => 'Številka gradnje';

  @override
  String get aboutPackage => 'Paket';

  @override
  String get aboutDeveloperOptions => 'Razvijalske moznosti';

  @override
  String get aboutOwnersDb => 'Baza lastnikov (kataster)';

  @override
  String get aboutNotImported => 'Ni uvozena.';

  @override
  String aboutOwnersCount(String count, String size) {
    return '$count lastnikov$size';
  }

  @override
  String get aboutOwnersDownloading => 'Prenašam bazo lastnikov…';

  @override
  String get aboutOwnersUpdateButton => 'Posodobi (~300 MB)';

  @override
  String get aboutOwnersDownloadButton => 'Prenesi (~300 MB)';

  @override
  String get aboutImportFromFile => 'Uvozi iz datoteke (.sqlite)';

  @override
  String get aboutRemove => 'Odstrani';

  @override
  String get aboutOfflineOwnerSearch => 'Iskanje lastnika brez povezave';

  @override
  String get aboutOfflineOwnerSearchDesc =>
      'Ko ni povezave, določi lastnika iz približnih mej parcel (lokalna baza).';

  @override
  String get aboutVlake => 'Vlake (gozdne vlake)';

  @override
  String get aboutVlakeDesc =>
      'Omogoči sloj — prikaže se v izbiri slojev (Infrastruktura)';

  @override
  String get aboutHttpCache => 'Shranjuj podatke o parcelah';

  @override
  String get aboutHttpCacheDesc =>
      'Lastniki, vrednosti in sloji ZGS ostanejo v telefonu, zato se hitreje odprejo in delujejo tudi brez signala.';

  @override
  String get aboutTileCache => 'Shranjuj zemljevide';

  @override
  String get aboutTileCacheDesc =>
      'Ogledani zemljevidi ostanejo v telefonu za delo brez signala.';

  @override
  String get aboutClearMapCache => 'Izbriši shranjene zemljevide';

  @override
  String get aboutPickSqlite => 'Izberi datoteko .sqlite.';

  @override
  String aboutOwnersImported(String count) {
    return 'Uvozenih $count lastnikov.';
  }

  @override
  String aboutImportFailed(String error) {
    return 'Uvoz ni uspel: $error';
  }

  @override
  String get aboutOwnersRemoved => 'Baza lastnikov odstranjena.';

  @override
  String get aboutClearCacheTitle => 'Izbrišem shranjene zemljevide?';

  @override
  String get aboutClearCacheBody =>
      'Izbrisane bodo vse shranjene karte, tudi tiste, prenesene za delo brez povezave. Brez signala jih ne bo mogoče prikazati, dokler jih znova ne prenesete.';

  @override
  String get aboutCacheCleared => 'Shranjeni zemljevidi izbrisani.';

  @override
  String aboutCacheClearFailed(String error) {
    return 'Brisanje ni uspelo: $error';
  }

  @override
  String get aboutOfflineKataster => 'Kataster brez povezave (parcele)';

  @override
  String get aboutKatasterNotLoaded =>
      'Ni naložena — kataster se prikazuje prek spleta.';

  @override
  String aboutParcelsSummary(
    String regions,
    String count,
    String size,
    String date,
  ) {
    return '$regions$count parcel$size$date • brez spleta';
  }

  @override
  String get aboutAddRegion => 'Dodaj regijo';

  @override
  String get aboutDownloadRegion => 'Prenesi regijo';

  @override
  String get aboutDownloadRegionHint =>
      'Prenesi le svojo statistično regijo — priporočena povezava Wi-Fi.';

  @override
  String get aboutShareKataster => 'Deli regije s telefoni v bližini';

  @override
  String aboutShareKatasterActive(int count) {
    return 'Deljenje vključeno • telefonov v bližini: $count';
  }

  @override
  String get aboutShareKatasterDesc =>
      'Telefoni v istem omrežju Wi-Fi lahko regije, ki ste jih že prenesli, dobijo od vas – hitreje in brez mobilnih podatkov.';

  @override
  String get aboutPublicOwners => 'javni lastniki';

  @override
  String aboutKatasterUpdateAvailable(String date) {
    return 'Na voljo je novejši kataster ($date)';
  }

  @override
  String aboutKatasterOutdated(String parts, String size) {
    return 'Zastarelo: $parts$size';
  }

  @override
  String get updateLater => 'Pozneje';

  @override
  String get updateNow => 'Posodobi';

  @override
  String get aboutPublicOwnersLabel => 'Javni lastniki…';

  @override
  String get aboutPublicOwnersFailed => 'Prenos javnih lastnikov ni uspel.';

  @override
  String aboutErrorWithDetail(String error) {
    return 'Napaka: $error';
  }

  @override
  String get aboutPickRegionsTitle => 'Izberi statistične regije';

  @override
  String get aboutCountrySi => 'Slovenija';

  @override
  String get aboutCountryHr => 'Hrvaška';

  @override
  String aboutRegionParcels(String count) {
    return ' • $count parcel';
  }

  @override
  String get aboutRegionLoaded => ' • naloženo';

  @override
  String aboutDownloadSelected(int count, String mb) {
    return 'Prenesi $count (~$mb MB)';
  }

  @override
  String aboutRegionProgress(String name, int index, int total) {
    return '$name ($index/$total)…';
  }

  @override
  String aboutRegionsDownloaded(int count) {
    return 'Prenesenih regij: $count.';
  }

  @override
  String aboutRegionsFailed(String names) {
    return ' Neuspešno: $names.';
  }

  @override
  String get aboutPasswordLabel => 'Geslo';

  @override
  String get aboutUnlock => 'Odkleni';

  @override
  String get aboutOwnersPasswordTitle => 'Geslo za bazo lastnikov';

  @override
  String aboutOwnersDownloaded(String count) {
    return 'Prenesenih $count lastnikov.';
  }

  @override
  String get aboutDownloadCancelled => 'Prenos preklican.';

  @override
  String aboutDownloadFailed(String error) {
    return 'Prenos ni uspel: $error';
  }

  @override
  String aboutParcelsImported(String count) {
    return 'Uvoženih $count parcel.';
  }

  @override
  String get aboutParcelsRemoved => 'Baze parcel odstranjene.';

  @override
  String get aboutWipeSection => 'Pobriši podatke (baze parcel + lastnikov)';

  @override
  String get aboutWipeImported => 'Uvožene';

  @override
  String get aboutWipeDownloaded => 'Prenesene';

  @override
  String get aboutWipeAll => 'Vse';

  @override
  String get aboutWipeScopeAll => 'vse baze';

  @override
  String get aboutWipeScopeImported => 'uvožene baze';

  @override
  String get aboutWipeScopeDownloaded => 'prenesene baze';

  @override
  String get aboutWipeTitle => 'Pobriši podatke';

  @override
  String aboutWipeConfirm(String scope) {
    return 'Ali res želiš pobrisati $scope? Tega ni mogoče razveljaviti.';
  }

  @override
  String get aboutWipeButton => 'Pobriši';

  @override
  String get aboutWipeNone => 'Ni ustreznih baz za brisanje.';

  @override
  String aboutWipeDone(int count) {
    return 'Pobrisanih baz: $count.';
  }

  @override
  String get aboutSrcZgsDesc =>
      'Gozdarski sloji, sestoji, odseki, revirji, gozdni rezervati, varovalni gozdovi, požarna ogroženost, vetrolomi, podlubniki';

  @override
  String get aboutSrcGursDesc =>
      'Ortofoto posnetki (2022-2024), kataster, katastrske občine, občine, upravne enote, DMR, vrednotenje nepremičnin';

  @override
  String get aboutSrcDguDesc =>
      'Hrvaške katastrske parcele, katastrske občine in posestniki parcel (portal Uređena zemlja)';

  @override
  String get aboutSrcOsmDesc => 'Osnovni zemljevid in topografski podatki';

  @override
  String get aboutSrcTopoDesc => 'Topografski zemljevid (Seznam.cz)';

  @override
  String get aboutSrcEsriDesc => 'Satelitski posnetki in topografski zemljevid';

  @override
  String get aboutTermsTitle => 'Pogoji uporabe';

  @override
  String get aboutDisclaimerTitle => 'Omejitev odgovornosti';

  @override
  String get aboutCopyrightTitle => 'Avtorske pravice';

  @override
  String get aboutPrivacyTitle => 'Zasebnost';

  @override
  String get aboutTermsBody =>
      'Aplikacija Gozdar je namenjena izključno informativnim namenom. Podatki o parcelah, gozdnih sestojih in drugih kartografskih slojih so povzeti iz javno dostopnih virov in morda niso posodobljeni ali popolnoma točni.';

  @override
  String get aboutDisclaimerBody =>
      'Razvijalec ne prevzema odgovornosti za morebitno škodo, ki bi nastala zaradi uporabe aplikacije ali podatkov v njej. Za uradne podatke o lastništvu in mejah parcel se obrnite na pristojne organe (v Sloveniji GURS in ZGS, na Hrvaškem DGU).';

  @override
  String get aboutCopyrightBody =>
      'Kartografski podatki ZGS in GURS so last Republike Slovenije. Katastrski podatki in podatki o posestnikih DGU so last Republike Hrvaške in so namenjeni le osebni uporabi. OpenStreetMap podatki so na voljo pod licenco ODbL. ESRI podatki so last Esri Inc.';

  @override
  String get aboutPrivacyBody =>
      'Aplikacija zbira anonimne podatke o uporabi za izboljšanje delovanja (Firebase Analytics). Lokacijski podatki se ne pošiljajo na strežnik - vsi podatki o parcelah in hlodih se hranijo lokalno na napravi.';

  @override
  String get aboutShowLicenses => 'Prikaži licence';

  @override
  String get aboutLicensesDesc => 'Flutter in odprtokodne knjižnice';

  @override
  String get aboutReportBug => 'Prijavi napako';

  @override
  String get aboutContact => 'Kontakt';

  @override
  String get aboutContactDesc => 'Pošljite povratne informacije';

  @override
  String get aboutSourceCode => 'Izvorna koda';

  @override
  String get aboutSourceCodeDesc => 'Odprtokodni projekt na GitHub';

  @override
  String get aboutLanguage => 'Jezik';

  @override
  String get aboutLanguageAuto => 'Samodejno';

  @override
  String get aboutDownloadingRegion => 'Prenašam regijo…';

  @override
  String get updateAvailableTitle => 'Nova posodobitev na voljo';

  @override
  String updateVersion(String version) {
    return 'Verzija $version';
  }

  @override
  String get updateDownloading => 'Prenašanje posodobitve...';

  @override
  String get updateReadyTitle => 'Posodobitev pripravljena';

  @override
  String get updateReadyHint => 'Tapni za namestitev';

  @override
  String get updateInstall => 'Namesti';

  @override
  String get updateErrorTitle => 'Napaka pri posodobitvi';

  @override
  String get updateRetry => 'Ponovi';

  @override
  String updateKatasterBanner(String date, String size) {
    return 'Na voljo je novejši kataster ($date$size).';
  }

  @override
  String get updateErrorAlreadyRunning => 'Prenos že poteka';

  @override
  String get updateErrorPermission => 'Dovoljenje za namestitev je zavrnjeno';

  @override
  String get updateErrorInternal => 'Notranja napaka';

  @override
  String get updateErrorDownload => 'Prenos ni uspel';

  @override
  String get updateErrorChecksum => 'Preverjanje kontrolne vsote ni uspelo';

  @override
  String get updateErrorInstall => 'Namestitev ni uspela';

  @override
  String get navTabMap => 'Karta';

  @override
  String get navTabForest => 'Gozd';

  @override
  String get navTabLogs => 'Hlodi';

  @override
  String navTabSemantic(String name) {
    return 'Tab $name';
  }

  @override
  String get navOnboardingReset =>
      'Uvodni vodič ponastavljen. Ponovno zaženi aplikacijo.';

  @override
  String get introSkip => 'Preskoči';

  @override
  String get introStart => 'Začni';

  @override
  String get introWelcomeTitle => 'Dobrodošli v Gozdar';

  @override
  String get introWelcomeBody =>
      'Aplikacija za lastnike gozdov in gozdarske delavce v Sloveniji.\n\nSledite poseku, beležite hlodovino in uporabljajte GPS za delo na terenu.';

  @override
  String get introNavTitle => 'Navigacija';

  @override
  String get introNavMapDesc => 'Interaktivni zemljevid z vašimi parcelami';

  @override
  String get introNavForestDesc => 'Seznam parcel in iskanje v katastru';

  @override
  String get introNavLogsDesc => 'Beleženje hlodovine z izračunom volumna';

  @override
  String get introLogsTitle => 'Beleženje hlodovine';

  @override
  String get introLogsDiameter => 'Premer: 45 cm';

  @override
  String get introLogsLength => 'Dolžina: 4.5 m';

  @override
  String get introLogsVolume => 'Volumen: 0.716 m³';

  @override
  String get introLogsSpecies => 'Drevesne vrste';

  @override
  String get introLogsSpeciesDesc =>
      'Beležite vrsto lesa (Smreka, Bukev, Jelka, ...)';

  @override
  String get introLogsAutoCalc => 'Samodejni izračun';

  @override
  String get introLogsAutoCalcDesc =>
      'Aplikacija izračuna volumen iz premera in dolžine';

  @override
  String get introLogsGrouping => 'Razvrščanje';

  @override
  String get introLogsGroupingDesc => 'Hlodi se samodejno razvrstijo po vrstah';

  @override
  String get introLogsManage => 'Upravljanje vrst';

  @override
  String get introLogsManageDesc => 'Dodajte ali odstranite vrste v meniju ⋮';

  @override
  String get introLongPressTitle => 'Dolg pritisk na karti';

  @override
  String get introLongPressAddPoint => 'Dodaj točko';

  @override
  String get introLongPressAddPointDesc =>
      'Shrani lokacijo (mejnik, skladišče)';

  @override
  String get introLongPressAddLogs => 'Dodaj hlodovino';

  @override
  String get introLongPressAddLogsDesc => 'Beleženje hloda z GPS koordinatami';

  @override
  String get introLongPressMarkCut => 'Označi sečnjo';

  @override
  String get introLongPressMarkCutDesc => 'Označi drevo za posek na karti';

  @override
  String get introLongPressImport => 'Uvozi parcelo';

  @override
  String get introLongPressImportDesc =>
      'Pridobi parcelo iz katastra na trenutni lokaciji';

  @override
  String get introLongPressHint => 'Držite prst na karti za prikaz menija';

  @override
  String get introMarkersTitle => 'Označbe na karti';

  @override
  String get introMarkerPoint => 'Točka';

  @override
  String get introMarkerLog => 'Hlod';

  @override
  String get introMarkerCut => 'Sečnja';

  @override
  String get introMarkersRed => 'Rdeče';

  @override
  String get introMarkersRedDesc => 'Shranjene lokacije (mejniki, skladišča)';

  @override
  String get introMarkersBrown => 'Rjave';

  @override
  String get introMarkersBrownDesc => 'Hlodovina z GPS lokacijo';

  @override
  String get introMarkersOrange => 'Oranžne';

  @override
  String get introMarkersOrangeDesc => 'Drevesa označena za sečnjo';

  @override
  String get introMarkersLinked =>
      'Hlodi in sečnje se samodejno povežejo s parcelo';

  @override
  String get introLayersTitle => 'Sloji na karti';

  @override
  String get introLayersButtonHint => 'Pritisnite za izbiro slojev';

  @override
  String get introLayersOrthoDesc => 'Satelitski posnetki Slovenije';

  @override
  String get introLayersCadastreDesc => 'Meje parcel iz katastra';

  @override
  String get introLayersStands => 'Gozdni sestoji';

  @override
  String get introLayersStandsDesc => 'Podatki Zavoda za gozdove';

  @override
  String get introLayersTopo => 'Topografija';

  @override
  String get introLayersTopoDesc => 'DTK in druge karte';

  @override
  String get introOfflineTitle => 'Delo brez povezave';

  @override
  String get introOfflineAutoCache => 'Samodejno predpomnjenje';

  @override
  String get introOfflineAutoCacheDesc =>
      'Ogledane karte se shranijo za kasnejšo uporabo';

  @override
  String get introOfflineOnSearch => 'Ob iskanju parcele';

  @override
  String get introOfflineOnSearchDesc =>
      'Karte za območje parcele se prenesejo samodejno';

  @override
  String get introOfflineManual => 'Ročni prenos';

  @override
  String get introOfflineManualDesc =>
      'Uporabite gumb za sloje na karti za prenos območja';

  @override
  String get introOfflineHint => 'Karte delujejo tudi v gozdu brez signala!';

  @override
  String get introCompassTitle => 'Navigacija do mejnika';

  @override
  String get introCompassMarker => 'Mejnik 1 • 45m';

  @override
  String get introCompassStep1 => 'Odprite parcelo';

  @override
  String get introCompassStep1Desc => 'V zavihku Gozd izberite parcelo';

  @override
  String get introCompassStep2 => 'Tapnite mejno točko';

  @override
  String get introCompassStep2Desc => 'Izberite točko na karti parcele';

  @override
  String get introCompassStep3 => 'Aktivirajte kompas';

  @override
  String get introCompassStep3Desc => 'Tapnite oranžni navigacijski trak';

  @override
  String get introCompassStep4 => 'Sledite smeri';

  @override
  String get introCompassStep4Desc => 'Kompas kaže smer in razdaljo do točke';

  @override
  String get introTermsTitle => 'Pogoji uporabe';

  @override
  String get introTermsBody =>
      'Aplikacija uporablja javne podatke Zavoda za gozdove Slovenije.\n\nZ uporabo te aplikacije se strinjate s pogoji uporabe podatkov:\n\n';

  @override
  String get introTermsLinkLabel => 'prostor.zgs.gov.si/pregledovalnik';

  @override
  String get introTermsUrl => 'https://prostor.zgs.gov.si/pregledovalnik/';

  @override
  String get aboutShowIntro => 'Uvodni vodič';

  @override
  String get aboutShowIntroDesc => 'Ponovno si oglejte predstavitev aplikacije';
}
