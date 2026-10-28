// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Croatian (`hr`).
class AppLocalizationsHr extends AppLocalizations {
  AppLocalizationsHr([String locale = 'hr']) : super(locale);

  @override
  String get appTitle => 'Gozdar';

  @override
  String get commonCancel => 'Odustani';

  @override
  String get commonSave => 'Spremi';

  @override
  String get commonDelete => 'Izbriši';

  @override
  String get commonClose => 'Zatvori';

  @override
  String get commonOk => 'U redu';

  @override
  String get commonEdit => 'Uredi';

  @override
  String get commonAdd => 'Dodaj';

  @override
  String get commonYes => 'Da';

  @override
  String get commonNo => 'Ne';

  @override
  String get commonBack => 'Natrag';

  @override
  String get commonRetry => 'Pokušaj ponovno';

  @override
  String get commonSearch => 'Pretraživanje';

  @override
  String get commonShare => 'Podijeli';

  @override
  String get commonDownload => 'Preuzmi';

  @override
  String get commonContinue => 'Dalje';

  @override
  String get commonDone => 'Gotovo';

  @override
  String get commonSettings => 'Postavke';

  @override
  String get commonError => 'Pogreška';

  @override
  String get commonLoading => 'Učitavanje …';

  @override
  String get logsHeaderTitle => 'Trupci';

  @override
  String get logsMoreOptionsTooltip => 'Više opcija za trupce';

  @override
  String get logsMenuManageSpecies => 'Upravljanje vrstama';

  @override
  String get logsMenuExport => 'Izvezi';

  @override
  String get logsMenuDeleteAll => 'Ukloni sve';

  @override
  String get logsSavedTooltip => 'Spremljeno';

  @override
  String get logsSaved => 'Spremljeno';

  @override
  String get logsSaveError => 'Pogreška pri spremanju';

  @override
  String get logsEntryUpdated => 'Unos ažuriran';

  @override
  String logsErrorWithDetail(String error) {
    return 'Pogreška: $error';
  }

  @override
  String get logsEntryDeleted => 'Unos izbrisan';

  @override
  String get logsUndo => 'Poništi';

  @override
  String get logsExportTitle => 'Izvezi trupce';

  @override
  String get logsExportExcel => 'Izvezi kao Excel';

  @override
  String get logsExportJson => 'Izvezi kao JSON';

  @override
  String get logsExportSuccess => 'Izvoz uspješan';

  @override
  String get logsNoEntriesToDelete => 'Nema unosa za brisanje';

  @override
  String get logsDeleteAllTitle => 'Ukloni sve trupce';

  @override
  String logsDeleteAllConfirm(int count, String volume) {
    return 'Jeste li sigurni da želite ukloniti svih $count unosa?\n\nUkupni obujam: $volume m³\n\nSpremljeni trupci ostaju nepromijenjeni. Ova radnja se ne može poništiti.';
  }

  @override
  String get logsAllEntriesRemoved => 'Svi unosi uklonjeni';

  @override
  String get logsNoEntriesToSave => 'Nema unosa za spremanje';

  @override
  String logsCountLogs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trupaca',
      few: '$count trupca',
      one: '$count trupac',
    );
    return '$_temp0';
  }

  @override
  String logsGroupSummary(int count, String volume) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trupaca',
      few: '$count trupca',
      one: '$count trupac',
    );
    return '$_temp0 • $volume m³';
  }

  @override
  String logsSaveSheetSummary(int count, String volume) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count trupaca',
      few: '$count trupca',
      one: '$count trupac',
    );
    return '$volume m³ • $_temp0';
  }

  @override
  String get logsSpeciesNotSelected => 'Vrsta nije odabrana';

  @override
  String get logsUnknownSpecies => 'Nepoznata vrsta';

  @override
  String get logsEmptyTitle => 'Još nema trupaca';

  @override
  String get logsEmptyHint => 'Unesite promjer i duljinu ispod';

  @override
  String get logsDiameterLabel => 'Promjer (cm)';

  @override
  String get logsLengthLabel => 'Duljina (m)';

  @override
  String get logsVolumeLabel => 'Obujam';

  @override
  String get logsSpeciesLabel => 'Vrsta drveća';

  @override
  String get logsNotSelected => 'Nije odabrano';

  @override
  String get logsLocationLabel => 'Lokacija';

  @override
  String get logsAddLocation => 'Dodaj lokaciju';

  @override
  String get logsNameLabel => 'Naziv';

  @override
  String get logsNameHint => 'npr. Smreka za Novaka';

  @override
  String get logsNotesLabel => 'Bilješke';

  @override
  String get logsNotesEditorHint => 'Unesite bilješke';

  @override
  String get logsLocationPermissionDenied => 'Dopuštenje za lokaciju odbijeno';

  @override
  String logsSaveErrorWithDetail(String error) {
    return 'Pogreška pri spremanju: $error';
  }

  @override
  String logsInlineAdded(int count) {
    return 'Dodano: $count';
  }

  @override
  String get logsSpeciesAddTitle => 'Dodaj novu vrstu';

  @override
  String get logsSpeciesNameLabel => 'Naziv vrste';

  @override
  String get logsSpeciesNameHint => 'Npr. Hrast';

  @override
  String logsSpeciesAdded(String name) {
    return 'Vrsta \"$name\" dodana';
  }

  @override
  String get logsSpeciesRemoveTitle => 'Ukloni vrstu';

  @override
  String logsSpeciesRemoveConfirm(String name) {
    return 'Jeste li sigurni da želite ukloniti \"$name\"?';
  }

  @override
  String get logsSpeciesRemoveButton => 'Ukloni';

  @override
  String logsSpeciesRemoved(String name) {
    return 'Vrsta \"$name\" uklonjena';
  }

  @override
  String get logsSpeciesResetTitle => 'Vrati na zadano';

  @override
  String get logsSpeciesResetConfirm =>
      'Jeste li sigurni da želite vratiti vrste na zadane vrijednosti?\n\nSve dodane vrste bit će uklonjene.';

  @override
  String get logsSpeciesResetButton => 'Vrati';

  @override
  String get logsSpeciesResetDone => 'Vrste vraćene na zadane';

  @override
  String logsSpeciesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vrsta',
      few: '$count vrste',
      one: '$count vrsta',
    );
    return '$_temp0';
  }

  @override
  String get logsSpeciesNone => 'Nema dodanih vrsta';

  @override
  String get logsConvTitle => 'Pretvorba obujma';

  @override
  String get logsConvSpeciesHint => 'Vrsta koju dobivaju novo dodani trupci.';

  @override
  String get logsConvPrmTitle => 'PRM - Prostorni metar drva';

  @override
  String get logsConvPrmDesc =>
      'Složeno drvo (cjepanice). 1 PRM × faktor = m³ čvrste mase.';

  @override
  String get logsConvNmTitle => 'NM - Nasipni metar';

  @override
  String get logsConvNmDesc =>
      'Nasuto drvo (sječka, otpad). 1 NM × faktor = m³ čvrste mase.';

  @override
  String get logsConvDefault => 'Zadano';

  @override
  String get logsConvBeechOak => 'Bukva/Hrast';

  @override
  String get logsConvSpruceFir => 'Smreka/Jela';

  @override
  String get logsConvSoftHardwood => 'Meke listače';

  @override
  String get logsConvHardWood => 'Tvrdo drvo';

  @override
  String get logsConvSoftWood => 'Meko drvo';

  @override
  String get logsConvConfirm => 'Potvrdi';

  @override
  String get logsConvCustomFactor => 'Prilagođeni faktor';

  @override
  String get logsFormLocationServicesDisabled =>
      'Lokacijske usluge su onemogućene';

  @override
  String get logsFormPermissionsDenied => 'Dopuštenja za lokaciju odbijena';

  @override
  String get logsFormPermissionsDeniedForever =>
      'Dopuštenja za lokaciju trajno odbijena';

  @override
  String get logsFormLocationAdded => 'Lokacija dodana';

  @override
  String logsFormLocationError(String error) {
    return 'Pogreška pri dohvaćanju lokacije: $error';
  }

  @override
  String get logsFormInvalidDimensions => 'Molimo unesite valjane dimenzije';

  @override
  String get logsFormTitleNew => 'Novi';

  @override
  String get logsFormVolumeModeTitle => 'Način unosa obujma';

  @override
  String get logsFormModeCalculate => 'Izračunaj iz dimenzija';

  @override
  String get logsFormModeDirect => 'Unesi obujam izravno';

  @override
  String get logsFormDiameterHelper => 'Unesite promjer trupca u centimetrima';

  @override
  String get logsFormDiameterRequired => 'Molimo unesite promjer';

  @override
  String get logsFormDiameterInvalid => 'Molimo unesite valjan promjer';

  @override
  String get logsFormLengthHelper => 'Unesite duljinu trupca u metrima';

  @override
  String get logsFormLengthRequired => 'Molimo unesite duljinu';

  @override
  String get logsFormLengthInvalid => 'Molimo unesite valjanu duljinu';

  @override
  String get logsFormCalculatedVolume => 'Izračunani obujam';

  @override
  String get logsFormVolumeLabel => 'Obujam (m³)';

  @override
  String get logsFormVolumeHelper => 'Unesite obujam u kubnim metrima';

  @override
  String get logsFormVolumeRequired => 'Molimo unesite obujam';

  @override
  String get logsFormVolumeInvalid => 'Molimo unesite valjan obujam';

  @override
  String get logsFormSpeciesOptional => 'Vrsta drveća (neobavezno)';

  @override
  String get logsFormLocating => 'Dohvaćanje lokacije...';

  @override
  String get logsFormAddCurrentLocation => 'Dodaj trenutnu lokaciju';

  @override
  String get logsFormNotesOptional => 'Bilješke (neobavezno)';

  @override
  String get logsFormNotesHelper => 'Dodajte eventualne bilješke';

  @override
  String get logsSaveSheetTitle => 'Spremi trupce';

  @override
  String logsSaveSheetDefaultName(String date) {
    return 'Trupci $date';
  }

  @override
  String get logsSavedSheetTitle => 'Spremljena mjerenja';

  @override
  String get logsSavedSheetEmpty => 'Nema spremljenih mjerenja';

  @override
  String get logsSavedSheetNoName => 'Bez naziva';

  @override
  String get logsSavedDeleteTitle => 'Izbriši spremljene trupce';

  @override
  String get logsSavedDeleteConfirm =>
      'Jeste li sigurni da želite izbrisati ovaj zapis?\n\nTrupci se vraćaju na popis Trupci.';

  @override
  String get logsExportSheetName => 'Trupci';

  @override
  String get logsExportHeaderDiameter => 'Promjer (cm)';

  @override
  String get logsExportHeaderLength => 'Duljina (m)';

  @override
  String get logsExportHeaderVolume => 'Obujam (m³)';

  @override
  String get logsExportHeaderNotes => 'Bilješke';

  @override
  String get logsExportHeaderDate => 'Datum';

  @override
  String get logsExportShareSubject => 'Gozdar Trupci Export';

  @override
  String logsExportShareText(int count) {
    return 'Izvezeno unosa: $count';
  }

  @override
  String get batchDefaultTitle => 'Spremljeni trupci';

  @override
  String batchDeleteConfirm(String name, int count) {
    return 'Jeste li sigurni da želite izbrisati \"$name\"?\n\nTrupci ($count) se vraćaju na popis Trupci.';
  }

  @override
  String get batchDeleteFallbackName => 'spremljene trupce';

  @override
  String get batchLogDeleted => 'Trupac izbrisan';

  @override
  String get batchNoLogsToExport => 'Nema trupaca za izvoz';

  @override
  String get batchEditInfoTooltip => 'Uredi informacije';

  @override
  String get batchEmptyHint => 'Dodirnite + za dodavanje trupca';

  @override
  String batchAddTitleCount(int count) {
    return 'Dodaj (+$count)';
  }

  @override
  String get batchValidatorEnter => 'Unesi';

  @override
  String batchVolumeLine(String volume) {
    return 'Obujam: $volume m³';
  }

  @override
  String get batchNotesHint => 'Dodatne bilješke';

  @override
  String get forestTitle => 'Moja šuma';

  @override
  String get forestFilterByOwner => 'Filtriraj po vlasniku';

  @override
  String get forestMoreOptionsTooltip => 'Više opcija šume';

  @override
  String get forestExportKml => 'Izvezi KML';

  @override
  String get forestSummaryArea => 'Površina';

  @override
  String get forestSummaryParcels => 'Čestica';

  @override
  String get forestSummaryTrees => 'Stabala';

  @override
  String get forestSummaryCut => 'Posječeno';

  @override
  String forestLoadError(String error) {
    return 'Pogreška pri učitavanju: $error';
  }

  @override
  String forestDeleteError(String error) {
    return 'Pogreška pri brisanju: $error';
  }

  @override
  String forestExportError(String error) {
    return 'Pogreška pri izvozu: $error';
  }

  @override
  String get forestDeleteTitle => 'Izbriši česticu';

  @override
  String forestDeleteConfirm(String name) {
    return 'Jeste li sigurni da želite izbrisati \"$name\"?\n\nIzbrisat će se i sve točke, sječe i trupci unutar čestice.';
  }

  @override
  String forestDeleted(String extra) {
    return 'Čestica izbrisana$extra';
  }

  @override
  String forestCountPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count točaka',
      few: '$count točke',
      one: '$count točka',
    );
    return '$_temp0';
  }

  @override
  String forestCountParcels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count čestica',
      few: '$count čestice',
      one: '$count čestica',
    );
    return '$_temp0';
  }

  @override
  String forestCountTrees(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stabala',
      few: '$count stabla',
      one: '$count stablo',
    );
    return '$_temp0';
  }

  @override
  String get forestNoParcelsToExport => 'Nema čestica za izvoz';

  @override
  String get forestKmlExported => 'KML uspješno izvezen';

  @override
  String get forestImportKml => 'Uvezi KML';

  @override
  String get forestImportTitle => 'Uvezi čestice';

  @override
  String forestImportConfirm(String count) {
    return 'Pronađeno: $count. Uvesti ih?';
  }

  @override
  String get forestImportButton => 'Uvezi';

  @override
  String forestImportDone(String count, String area) {
    return 'Uvezeno: $count ($area)';
  }

  @override
  String get forestImportNoParcels => 'U datoteci nema valjanih čestica.';

  @override
  String get forestImportFullTitle => 'Uvezi česticu s podacima';

  @override
  String get forestImportFound => 'Pronađeno:';

  @override
  String forestImportFellings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sječa',
      few: '$count sječe',
      one: '$count sječa',
    );
    return '$_temp0';
  }

  @override
  String forestImportFullDone(String name) {
    return 'Uvezena čestica \"$name\"';
  }

  @override
  String forestImportError(String error) {
    return 'Pogreška pri uvozu: $error';
  }

  @override
  String get forestNoOwners => 'Nema čestica s određenim vlasnicima';

  @override
  String get forestShowAll => 'Prikaži sve';

  @override
  String forestNoParcelsForOwner(String owner) {
    return 'Nema čestica za \"$owner\"';
  }

  @override
  String get forestEmptyTitle => 'Još nema čestica';

  @override
  String get forestEmptyHint =>
      'Pronađite česticu u katastru\nili je uvezite iz KML-a';

  @override
  String get forestSearchParcel => 'Traži česticu';

  @override
  String get forestNoKo => 'Bez KO';

  @override
  String forestKoLabel(String code) {
    return 'KO $code';
  }

  @override
  String mapTabMejnikName(int number, String parcela) {
    return 'Međnik $number ($parcela)';
  }

  @override
  String get mapTabLocationServicesDisabled => 'Usluge lokacije su onemogućene';

  @override
  String get mapTabLocationPermissionDenied =>
      'Dopuštenje za lokaciju odbijeno';

  @override
  String get mapTabLocationPermissionDeniedForever =>
      'Dopuštenje za lokaciju trajno odbijeno';

  @override
  String mapTabLocationError(Object error) {
    return 'Pogreška pri dohvaćanju lokacije: $error';
  }

  @override
  String mapTabLocationAdded(String name) {
    return 'Dodano \"$name\"';
  }

  @override
  String mapTabErrorWithMessage(Object error) {
    return 'Pogreška: $error';
  }

  @override
  String mapTabLocationAddError(Object error) {
    return 'Pogreška pri dodavanju lokacije: $error';
  }

  @override
  String mapTabSecnjaMarked(String name) {
    return 'Sječa \"$name\" označena';
  }

  @override
  String mapTabSecnjaMarkError(Object error) {
    return 'Pogreška pri označavanju sječe: $error';
  }

  @override
  String mapTabLogAdded(String volume) {
    return 'Trupac dodan ($volume m³)';
  }

  @override
  String mapTabLogAddError(Object error) {
    return 'Pogreška pri dodavanju trupca: $error';
  }

  @override
  String mapTabLocationDeleted(String name) {
    return 'Izbrisano \"$name\"';
  }

  @override
  String mapTabLocationDeleteError(Object error) {
    return 'Pogreška pri brisanju lokacije: $error';
  }

  @override
  String mapTabNoCadastreData(String region) {
    return 'Za regiju $region nema podataka katastra.';
  }

  @override
  String mapTabRegionNotInList(String name) {
    return 'Regije $name nema na popisu.';
  }

  @override
  String mapTabRegionDownloaded(String name, int count) {
    return '$name: preuzeto čestica: $count.';
  }

  @override
  String get mapTabDownloadCancelled => 'Preuzimanje otkazano.';

  @override
  String mapTabDownloadFailed(Object error) {
    return 'Preuzimanje nije uspjelo: $error';
  }

  @override
  String get mapTabNoParcelAtLocation =>
      'Na ovoj lokaciji nije pronađena čestica';

  @override
  String mapTabParcelSearchError(Object error) {
    return 'Pogreška pri pretraživanju čestice: $error';
  }

  @override
  String get mapTabUnknownOwner => 'Nepoznati vlasnik';

  @override
  String mapTabParcelKo(String parcela, Object ko) {
    return 'Čestica $parcela (KO $ko)';
  }

  @override
  String get mapTabOwnerOffline => 'Vlasnik (izvan mreže)';

  @override
  String get mapTabApproximateOffline => '≈ približno (izvan mreže)';

  @override
  String get mapTabParcelExistsTitle => 'Čestica već postoji';

  @override
  String mapTabParcelExistsBody(Object ko, Object number) {
    return 'Čestica $ko - $number već je među vašim česticama.';
  }

  @override
  String mapTabParcelExistsLabelBody(String label) {
    return 'Čestica $label već je među vašim česticama.';
  }

  @override
  String get mapTabShowInMyParcels => 'Prikaži u mojim česticama';

  @override
  String get mapTabImportParcelTitle => 'Uvezi česticu';

  @override
  String get mapTabImportParcelQuestion =>
      'Želite li uvesti ovu česticu u \"Moja šuma\"?';

  @override
  String get mapTabPrint => 'Ispiši';

  @override
  String get mapTabImport => 'Uvezi';

  @override
  String mapTabPdfOpenFailed(Object message) {
    return 'PDF nije moguće otvoriti: $message';
  }

  @override
  String mapTabPdfError(Object error) {
    return 'Pogreška pri pripremi PDF-a: $error';
  }

  @override
  String mapTabParcelImported(Object ko, Object number) {
    return 'Čestica $ko - $number uspješno uvezena';
  }

  @override
  String mapTabParcelImportError(Object error) {
    return 'Pogreška pri uvozu čestice: $error';
  }

  @override
  String get mapTabKmlUnsupported =>
      'KML/KMZ uvoz preko karte još nije podržan';

  @override
  String mapTabImportError(Object error) {
    return 'Pogreška pri uvozu: $error';
  }

  @override
  String mapTabParcelTitle(Object number, Object ko) {
    return 'Čest. $number • KO $ko';
  }

  @override
  String mapTabParcelTitleWithKo(Object number, Object ko, String koName) {
    return 'Čest. $number • KO $ko $koName';
  }

  @override
  String mapTabParcelShort(Object number) {
    return 'Čest. $number';
  }

  @override
  String get mapTabSelectedPoint => 'Odabrana točka';

  @override
  String get mapTabMejnikiHint =>
      'Dugo pritisnite na česticu za prikaz međnika.';

  @override
  String get mapTabNoActiveMeasurement => 'Nema aktivnog mjerenja';

  @override
  String get mapTabHintStart => 'Dugo pritisnite na kartu za početak mjerenja.';

  @override
  String get mapTabHintFinished => 'Mjerenje je završeno.';

  @override
  String get mapTabHintMoveMap =>
      'Pomaknite kartu da nišan pokazuje na točku i dodirnite »Dodaj točku«.';

  @override
  String get mapTabHintNextPointDistance =>
      'Sljedeću točku dodajte nišanom ili završite mjerenje.';

  @override
  String get mapTabHintMinPointsArea =>
      'Nišanom dodajte najmanje 3 točke za površinu.';

  @override
  String get mapTabHintNextPointPolygon =>
      'Sljedeću točku dodajte nišanom ili završite poligon.';

  @override
  String get mapTabMeasureArea => 'Mjerenje površine';

  @override
  String get mapTabMeasureDistance => 'Mjerenje udaljenosti';

  @override
  String get mapTabAddPoint => 'Dodaj točku';

  @override
  String get mapTabUndo => 'Poništi';

  @override
  String get mapTabFinish => 'Završi';

  @override
  String get mapTabLoadingMap => 'Učitavam kartu...';

  @override
  String mapTabParcelLabel(String label) {
    return 'Čestica $label';
  }

  @override
  String mapTabTilesDownloadPercent(String percent) {
    return 'Preuzimanje karata $percent%';
  }

  @override
  String mapTabTilesDownloadStats(
    int downloaded,
    int cached,
    int failed,
    int total,
  ) {
    return 'Preuzeto $downloaded, u predmemoriji $cached, pogreške $failed / $total';
  }

  @override
  String get mapTabSearchingParcel => 'Pretraživanje čestice...';

  @override
  String mapTabRegionDownloading(String name, String mb, String totMb) {
    return 'Preuzimam $name… $mb/$totMb MB';
  }

  @override
  String get mapTabParcelImportedSimple => 'Čestica je uvezena';

  @override
  String get mapTabUsageRightsTitle => 'Prava korištenja podataka';

  @override
  String get mapTabUsageGuName => 'Geodetska uprava RS';

  @override
  String get mapTabUsageGuDesc =>
      'Podaci Geodetske uprave Republike Slovenije (ortofoto, katastar, topografske karte) dostupni su pod uvjetima otvorenih podataka. Korištenje je dopušteno u nekomercijalne i komercijalne svrhe uz navođenje izvora.';

  @override
  String get mapTabUsageZgsName => 'Zavod za šume Slovenije';

  @override
  String get mapTabUsageZgsDesc =>
      'Šumarski podaci (šumske zajednice, sastojinska karta, stanišni koeficijenti) javno su dostupni. Korištenje je dopušteno u informativne svrhe. Za komercijalno korištenje potrebno je ishoditi dopuštenje ZGS-a.';

  @override
  String get mapTabUsageOsmDesc =>
      'Kartografski podaci OpenStreetMap dostupni su pod licencijom Open Database License (ODbL). Korištenje je dopušteno uz navođenje \"© OpenStreetMap contributors\".';

  @override
  String get mapTabUsageEsriDesc =>
      'Esri satelitske snimke dostupne su za osobnu i nekomercijalnu uporabu. Za komercijalnu uporabu potrebna je licencija.';

  @override
  String get mapTabUsageDisclaimer =>
      'Ova je aplikacija namijenjena informativnoj uporabi. Za službene podatke obratite se nadležnim institucijama.';

  @override
  String mapTabLocationRenamed(String newName) {
    return 'Lokacija preimenovana u \"$newName\"';
  }

  @override
  String get mapwAddLocationTitle => 'Dodaj lokaciju';

  @override
  String get mapwAddLocationHint =>
      'Koordinate iz dugog pritiska ili unesite vlastite';

  @override
  String get mapwLatLabel => 'Zemljopisna širina (Lat)';

  @override
  String get mapwLngLabel => 'Zemljopisna duljina (Lng)';

  @override
  String get mapwLatExample => 'npr. 46.0569';

  @override
  String get mapwLngExample => 'npr. 14.5058';

  @override
  String get mapwEnterLat => 'Unesite širinu';

  @override
  String get mapwEnterLng => 'Unesite duljinu';

  @override
  String get mapwInvalidNumber => 'Neispravan broj';

  @override
  String get mapwLatRange => 'Širina mora biti između -90 i 90';

  @override
  String get mapwLngRange => 'Duljina mora biti između -180 i 180';

  @override
  String get mapwLatNotInSlovenia =>
      'Lokacija nije u Sloveniji ili Hrvatskoj (42.3-46.9)';

  @override
  String get mapwLngNotInSlovenia =>
      'Lokacija nije u Sloveniji ili Hrvatskoj (13.3-19.5)';

  @override
  String get mapwLocationNameLabel => 'Naziv lokacije';

  @override
  String get mapwLocationNameHint => 'Unesite naziv za ovu lokaciju';

  @override
  String get mapwEnterName => 'Unesite naziv';

  @override
  String get mapwMarkFellingTitle => 'Označi sječu';

  @override
  String get mapwTreeDescLabel => 'Opis stabla';

  @override
  String get mapwTreeDescHint => 'npr. Hrast, Bukva, Smreka...';

  @override
  String get mapwEnterDescription => 'Molimo unesite opis';

  @override
  String get mapwMarkAction => 'Označi';

  @override
  String get mapwDeleteLocationTitle => 'Izbriši lokaciju';

  @override
  String mapwDeleteLocationSure(String name) {
    return 'Jeste li sigurni da želite izbrisati \"$name\"?';
  }

  @override
  String get mapwAddLocationByCoordsTitle => 'Dodaj lokaciju koordinatama';

  @override
  String get mapwEnterWgs84Hint =>
      'Unesite koordinate u WGS84 formatu (decimalni stupnjevi)';

  @override
  String get mapwRenameLocationTitle => 'Preimenuj lokaciju';

  @override
  String get mapwNameLabel => 'Naziv';

  @override
  String mapwParcelTitle(String number) {
    return 'Čestica $number';
  }

  @override
  String get mapwCadastralParcel => 'Katastarska čestica';

  @override
  String get mapwCadastralMunicipality => 'Katastarska općina';

  @override
  String get mapwArea => 'Površina';

  @override
  String get mapwOwner => 'Vlasnik';

  @override
  String mapwDeleteLocationQuestion(String name) {
    return 'Želite li zaista izbrisati lokaciju \"$name\"?';
  }

  @override
  String get mapwResetOnboardingTitle => 'Poništi uvodni vodič';

  @override
  String get mapwResetOnboardingBody =>
      'Želite li zaista poništiti uvodni vodič? Ponovno pokrenite aplikaciju.';

  @override
  String get mapwReset => 'Poništi';

  @override
  String get mapwMenuMeasure => 'Mjerenje';

  @override
  String get mapwMenuNavigate => 'Navigiraj';

  @override
  String get mapwMenuParcel => 'Čestica';

  @override
  String get mapwMenuImport => 'Uvezi';

  @override
  String mapwPublicParcel(String category) {
    return 'Javna čestica • $category';
  }

  @override
  String get mapwMenuPoint => 'Točka';

  @override
  String get mapwMenuLogs => 'Trupci';

  @override
  String get mapwMenuFelling => 'Sječa';

  @override
  String get mapwMenuDistance => 'Udaljenost';

  @override
  String get mapwMenuBoundaries => 'Međaši';

  @override
  String get mapwSelectLayer => 'Odaberi sloj';

  @override
  String get mapwSearchParcelByKo => 'Traži česticu po KO';

  @override
  String get mapwZoomIn => 'Povećaj kartu';

  @override
  String get mapwZoomOut => 'Smanji kartu';

  @override
  String get mapwCenterOnGps => 'Centriraj na GPS lokaciju';

  @override
  String get mapwSavedLocations => 'Spremljene lokacije';

  @override
  String get mapwLayersTitle => 'Slojevi karte';

  @override
  String get mapwTabBase => 'Podloga';

  @override
  String get mapwTabOverlays => 'Prekrivni slojevi';

  @override
  String get mapwInternationalMaps => 'Međunarodne karte';

  @override
  String get mapwSlovenianMaps => 'Slovenske karte';

  @override
  String get mapwDownloadOffline => 'Preuzmi za rad izvan mreže';

  @override
  String get mapwImportGeodata => 'Uvezi geopodatke (KML, KMZ)';

  @override
  String get mapwNoResults => 'Nema rezultata';

  @override
  String mapwActiveCount(int count) {
    return '$count aktivnih';
  }

  @override
  String get mapwPublicParcels => 'Javne čestice';

  @override
  String get mapwVlakeHint => 'Vlake (pri većem povećanju)';

  @override
  String get mapwAddByCoordinates => 'Dodaj koordinatama';

  @override
  String get mapwSectionPoints => 'Točke';

  @override
  String get mapwNoSavedLocations => 'Nema spremljenih lokacija';

  @override
  String get mapwRename => 'Preimenuj';

  @override
  String get mapwNavAppOpenFailed =>
      'Aplikaciju za navigaciju nije bilo moguće otvoriti.';

  @override
  String get mapwGoogleMaps => 'Google karte';

  @override
  String get mapwAppleMaps => 'Apple karte';

  @override
  String get mapwRoadNavigation => 'Navigacija cestom';

  @override
  String get mapwInAppCompass => 'Kompas u aplikaciji';

  @override
  String get mapwInAppCompassHint =>
      'Smjer i udaljenost do cilja, i bez interneta';

  @override
  String get mapwCopyCoordinates => 'Kopiraj koordinate';

  @override
  String get mapwCoordinatesCopied => 'Koordinate kopirane';

  @override
  String get mapwCompassN => 'S';

  @override
  String get mapwCompassE => 'I';

  @override
  String get mapwCompassS => 'J';

  @override
  String get mapwCompassW => 'Z';

  @override
  String get mapwCompassNE => 'SI';

  @override
  String get mapwCompassSE => 'JI';

  @override
  String get mapwCompassSW => 'JZ';

  @override
  String get mapwCompassNW => 'SZ';

  @override
  String mapwCompassLowAccuracy(int degrees) {
    return 'Niska točnost kompasa (±$degrees°). Kalibrirajte uređaj.';
  }

  @override
  String mapwCompassMediumAccuracy(int degrees) {
    return 'Umjerena točnost kompasa (±$degrees°)';
  }

  @override
  String get mapwLocationPermissionDenied =>
      'Dopuštenje za lokaciju odbijeno — udaljenost nije dostupna';

  @override
  String get mapwCompass => 'Kompas';

  @override
  String get mapwDistance => 'Udaljenost';

  @override
  String get mapwAzimuth => 'Azimut';

  @override
  String get mapwDirection => 'Smjer';

  @override
  String get mapwTileTemplateUnavailable => 'URL predloška nije dostupan';

  @override
  String get mapwDownloadComplete => 'Preuzimanje završeno';

  @override
  String get mapwClearCacheTitle => 'Očistiti predmemoriju?';

  @override
  String get mapwClearCacheBody =>
      'Sve preuzete pločice bit će izbrisane. Ova se radnja ne može poništiti.';

  @override
  String get mapwCacheCleared => 'Predmemorija ispražnjena';

  @override
  String mapwSyncing(String name) {
    return 'Sinkroniziram $name';
  }

  @override
  String mapwSyncDownloaded(int done, int total) {
    return 'Preuzeto $done/$total';
  }

  @override
  String mapwSyncFromCache(int done, int total) {
    return 'Iz predmemorije $done/$total';
  }

  @override
  String mapwSyncDone(int downloaded, int skipped, int failed) {
    return 'Gotovo! $downloaded preuzeto, $skipped iz predmemorije, $failed neuspješno';
  }

  @override
  String get mapwSyncCancelled => 'Sinkronizacija otkazana';

  @override
  String get mapwTileSharing => 'Dijeljenje pločica';

  @override
  String get mapwShareMyTiles => 'Dijeli moje pločice';

  @override
  String get mapwSharingOnHint =>
      'Drugi uređaji mogu preuzeti pločice s ovog uređaja';

  @override
  String get mapwSharingOffHint =>
      'Počni dijeliti pločice iz predmemorije s obližnjim uređajima';

  @override
  String get mapwMyCachedMaps => 'Moje karte u predmemoriji';

  @override
  String mapwTilesAndSize(String tiles, String size) {
    return '$tiles pločica, $size';
  }

  @override
  String get mapwNearbyDevices => 'Obližnji uređaji';

  @override
  String get mapwRefresh => 'Osvježi';

  @override
  String get mapwAddDeviceManually => 'Ručno dodaj uređaj';

  @override
  String get mapwNoDevicesFound =>
      'U lokalnoj mreži nema pronađenih uređaja.\nProvjerite imaju li drugi uređaji uključeno dijeljenje pločica.';

  @override
  String get mapwFetchingCatalog => 'Dohvaćam katalog';

  @override
  String get mapwNoCachedTilesOnDevice =>
      'Na ovom uređaju nema pločica u predmemoriji';

  @override
  String mapwYouHave(String count) {
    return ' (imate $count)';
  }

  @override
  String get mapwDownloadAll => 'Preuzmi sve';

  @override
  String get mapwAddDeviceTitle => 'Dodaj uređaj';

  @override
  String get mapwIpAddress => 'IP adresa';

  @override
  String mapwDeleteStyleTitle(String name) {
    return 'Izbriši $name?';
  }

  @override
  String mapwDeleteStyleBody(String tiles, String size) {
    return '$tiles pločica, $size bit će izbrisano.';
  }

  @override
  String get mapwTileDownloadTitle => 'Preuzimanje karata';

  @override
  String get mapwForOfflineWork => 'Za rad izvan mreže';

  @override
  String get mapwSharingEnabled => 'Dijeljenje pločica uključeno';

  @override
  String get mapwSharingDisabled => 'Dijeljenje pločica isključeno';

  @override
  String get mapwLayersShort => 'Slojevi';

  @override
  String get mapwZoomLevel => 'Povećanje';

  @override
  String get mapwEstimate => 'Procjena';

  @override
  String mapwEstimatedTiles(int count) {
    return '~$count pločica';
  }

  @override
  String mapwDownloadingPercent(String percent) {
    return 'Preuzimam... $percent%';
  }

  @override
  String get mapwLayerNotDownloadable => 'Sloj nije dostupan za preuzimanje';

  @override
  String get mapwNoXyzTemplate =>
      'Za ovaj sloj nije bilo moguće odrediti XYZ predložak.';

  @override
  String get mapwCache => 'Predmemorija';

  @override
  String mapwCacheStats(String tiles, String size) {
    return '$tiles pločica ($size MB)';
  }

  @override
  String get mapwClearCache => 'Očisti predmemoriju';

  @override
  String mapwParcelAlreadyInDb(String municipality, String number) {
    return 'Čestica $municipality - $number već je u bazi podataka';
  }

  @override
  String get parcelPointUnknown => 'Točka ?';

  @override
  String parcelPointNumbered(int number) {
    return 'Točka $number';
  }

  @override
  String parcelDetailUpdateError(String error) {
    return 'Pogreška pri ažuriranju: $error';
  }

  @override
  String get parcelDetailPreparingPdf => 'Pripremam PDF …';

  @override
  String parcelDetailPdfOpenError(String message) {
    return 'PDF nije moguće otvoriti: $message';
  }

  @override
  String parcelDetailPdfError(String error) {
    return 'Pogreška pri pripremi PDF-a: $error';
  }

  @override
  String get parcelDetailPreparingExport => 'Pripremam izvoz …';

  @override
  String get parcelDetailExportDone => 'Izvoz je završen';

  @override
  String parcelDetailExportError(String error) {
    return 'Pogreška pri izvozu: $error';
  }

  @override
  String get parcelForestTypeTitle => 'Vrsta šume';

  @override
  String get parcelForestTypeDeciduous => 'Listopadno drveće';

  @override
  String get parcelForestTypeMixed => 'Mješovita šuma';

  @override
  String get parcelForestTypeConiferous => 'Četinjače';

  @override
  String get parcelOwnerTitle => 'Vlasnik';

  @override
  String get parcelOwnerNameLabel => 'Ime vlasnika';

  @override
  String get parcelOwnerNameHint => 'Unesite ime vlasnika';

  @override
  String get parcelNotesTitle => 'Bilješke';

  @override
  String get parcelAllowanceTitle => 'Dopuštena sječa';

  @override
  String get parcelAllowanceAmountLabel => 'Količina (m³)';

  @override
  String get parcelAllowanceAmountHint => 'Unesite dopuštenu količinu';

  @override
  String get parcelInvalidNumber => 'Neispravan broj';

  @override
  String get parcelLogCutTitle => 'Zabilježi sječu';

  @override
  String parcelCutCurrent(String volume) {
    return 'Trenutno posječeno: $volume m³';
  }

  @override
  String parcelCutRemaining(String volume) {
    return 'Još na raspolaganju: $volume m³';
  }

  @override
  String get parcelCutAddLabel => 'Dodaj sječu (m³)';

  @override
  String get parcelCutAddHint => 'Unesite količinu';

  @override
  String get parcelTreesCountLabel => 'Broj stabala';

  @override
  String get parcelTreesCountHint => 'Unesite broj';

  @override
  String get parcelTreesUnit => 'stabala';

  @override
  String get parcelCutInvalidAmount => 'Unesite ispravnu količinu sječe';

  @override
  String parcelCutAddedWithTrees(String volume, int trees) {
    return 'Dodano $volume m³ sječe ($trees stabala)';
  }

  @override
  String parcelCutAdded(String volume) {
    return 'Dodano $volume m³ sječe';
  }

  @override
  String get parcelResetCutTitle => 'Poništi sječu';

  @override
  String get parcelResetCutMessage =>
      'Jeste li sigurni da želite poništiti količinu posječenog drva na 0?';

  @override
  String get parcelReset => 'Poništi';

  @override
  String get parcelAddTreesTitle => 'Dodaj posječena stabla';

  @override
  String get parcelResetTreesTitle => 'Poništi stabla';

  @override
  String get parcelResetTreesMessage =>
      'Jeste li sigurni da želite poništiti broj posječenih stabala na 0?';

  @override
  String get parcelDeleteTitle => 'Izbriši česticu';

  @override
  String parcelDeleteMessage(String name) {
    return 'Jeste li sigurni da želite izbrisati \"$name\"?\n\nIzbrisat će se i sve točke, sječe i trupci unutar čestice.';
  }

  @override
  String parcelDeletedLogsExtra(int count) {
    return '$count trupaca';
  }

  @override
  String parcelDeletedPointsExtra(int count) {
    return '$count točaka';
  }

  @override
  String get parcelDeleted => 'Čestica izbrisana';

  @override
  String parcelDeletedWithExtras(String extras) {
    return 'Čestica izbrisana ($extras)';
  }

  @override
  String parcelDeleteError(String error) {
    return 'Pogreška pri brisanju: $error';
  }

  @override
  String get parcelEditShape => 'Uredi oblik';

  @override
  String get parcelPrint => 'Ispiši';

  @override
  String get parcelExportKml => 'Izvezi KML';

  @override
  String get parcelViewOnMap => 'Pogledaj na karti';

  @override
  String get parcelNavigate => 'Navigiraj';

  @override
  String get parcelEditorNeedThreePoints => 'Nacrtajte barem 3 točke';

  @override
  String get parcelEditorNameRequired => 'Molimo unesite ime';

  @override
  String get parcelEditorBaseLayer => 'Osnovni sloj';

  @override
  String get parcelEditorOverlayLayers => 'Prekrivni slojevi';

  @override
  String get parcelEditorAddTitle => 'Dodaj česticu';

  @override
  String get parcelEditorEditTitle => 'Uredi česticu';

  @override
  String get parcelEditorNameLabel => 'Naziv čestice';

  @override
  String get parcelForestTypeMixedShort => 'Mješovita';

  @override
  String parcelEditorTapToAdd(int count) {
    return 'Dodirnite kartu za dodavanje točaka ($count točaka)';
  }

  @override
  String get parcelEditorDrawingDone => 'Crtanje završeno';

  @override
  String parcelEditorArea(String area) {
    return 'Površina: $area';
  }

  @override
  String get parcelEditorClear => 'Očisti';

  @override
  String parcelLogsCardTitle(int count) {
    return 'Trupci na čestici ($count)';
  }

  @override
  String get parcelManualEntry => 'Ručni unos';

  @override
  String parcelLogName(int id) {
    return 'Trupac $id';
  }

  @override
  String parcelMoreLogs(int count) {
    return '... i još $count trupaca';
  }

  @override
  String parcelSavedPointsTitle(int count) {
    return 'Spremljene točke ($count)';
  }

  @override
  String parcelSecnjaTitle(int count) {
    return 'Sječa ($count)';
  }

  @override
  String parcelFoundTitle(String label) {
    return 'Čestica $label';
  }

  @override
  String parcelFoundKo(String ko) {
    return 'KO $ko';
  }

  @override
  String get parcelFoundOwnersLoading => 'Tražim posjednike …';

  @override
  String ownerAndMore(String first, int count) {
    return '$first i još $count';
  }

  @override
  String ownersTitle(int count) {
    return 'Vlasnici ($count)';
  }

  @override
  String ownersShowAll(int count) {
    return 'Prikaži sve ($count)';
  }

  @override
  String get parcelFoundHide => 'Sakrij';

  @override
  String get parcelFoundOpen => 'Otvori česticu';

  @override
  String get parcelFoundImport => 'Uvezi česticu';

  @override
  String parcelPointsCount(int count) {
    return '$count točaka';
  }

  @override
  String get parcelInfoAdded => 'Dodano';

  @override
  String get parcelInfoParcel => 'Čestica';

  @override
  String get parcelInfoKo => 'Katastarska općina';

  @override
  String get parcelNotSet => 'Nije određen';

  @override
  String get parcelFromCadastre => 'iz katastra (GURS)';

  @override
  String get parcelNoNotes => 'Nema bilješki';

  @override
  String get parcelWoodTitle => 'Sječa drva';

  @override
  String get parcelCutLabel => 'Posječeno';

  @override
  String parcelWoodUsed(String percent) {
    return '$percent% iskorišteno';
  }

  @override
  String get parcelTreesCutLabel => 'Posječenih stabala';

  @override
  String get parcelLogCutButton => 'Sječa m³';

  @override
  String get parcelTreeButton => 'Stablo';

  @override
  String parcelSearchNotFound(String number) {
    return 'Čestica $number nije pronađena.';
  }

  @override
  String parcelSearchError(String error) {
    return 'Pogreška pri pretraživanju: $error';
  }

  @override
  String get parcelSearchTitle => 'Pretraživanje čestica';

  @override
  String get parcelSearchAllKo => 'Sve katastarske općine';

  @override
  String get parcelSearchByMapPosition => 'Prema položaju na karti';

  @override
  String get parcelSearchRemoveKo => 'Ukloni katastarsku općinu';

  @override
  String get parcelSearchHint => 'Čestica, vlasnik, adresa ili k.o.';

  @override
  String get parcelSearchHelper => 'npr. 123/4, Horvat Babno ili Škofja Loka';

  @override
  String get parcelSearchPromptNoKo =>
      'Unesite broj čestice, ime vlasnika, adresu ili katastarsku općinu.';

  @override
  String get parcelSearchPromptWithKo =>
      'Unesite broj čestice (npr. 123/4), ime vlasnika ili adresu.';

  @override
  String parcelSearchNeedsKoHint(String number) {
    return 'Za česticu $number odaberite katastarsku općinu: unesite njezin naziv.';
  }

  @override
  String get parcelSearchNoResults => 'Nema rezultata.';

  @override
  String parcelSearchNeedsKo(String number) {
    return 'Za česticu $number odaberite katastarsku općinu.';
  }

  @override
  String get parcelMapPreviewLabel => 'Karta';

  @override
  String get parcelPdfKo => 'Katastarska općina';

  @override
  String get parcelPdfNumber => 'Broj čestice';

  @override
  String get parcelPdfArea => 'Površina';

  @override
  String get parcelPdfAddress => 'Adresa';

  @override
  String get parcelPdfMunicipality => 'Općina';

  @override
  String get parcelPdfMapFailed => 'Kartu nije bilo moguće učitati';

  @override
  String parcelPdfFooter(String date) {
    return 'Gozdar • Ispisano: $date';
  }

  @override
  String get parcelPdfSource => 'Izvor: © GURS, © ZGS';

  @override
  String parcelSearchKoSubtitle(int sifko) {
    return 'Katastarska općina $sifko';
  }

  @override
  String get svcKmlExportSubject => 'Gozdar izvoz čestica';

  @override
  String svcKmlExportText(int count) {
    return 'Izvezeno čestica: $count';
  }

  @override
  String svcKmlParcelShareSubject(String name) {
    return 'Čestica $name';
  }

  @override
  String svcKmlParcelShareText(
    String name,
    int logs,
    int fellings,
    int points,
  ) {
    return 'Izvoz čestice $name s $logs trupaca, $fellings sječa i $points točaka';
  }

  @override
  String svcDownloadFailedHttp(int status) {
    return 'Preuzimanje nije uspjelo (HTTP $status).';
  }

  @override
  String svcParcelDisplayName(String number, int ko) {
    return 'Čestica $number (KO $ko)';
  }

  @override
  String svcParcelDisplayNameRef(String label, String ref) {
    return 'Čestica $label ($ref)';
  }

  @override
  String get svcLayerParcel => 'Čestica';

  @override
  String get svcLayerStand => 'Sastojina';

  @override
  String get svcLayerSection => 'Odjel';

  @override
  String get svcLayerDistrict => 'Revir';

  @override
  String get svcLayerGge => 'GGE';

  @override
  String get svcLayerGgo => 'GGO';

  @override
  String get svcLayerForestReserve => 'Šumski rezervat';

  @override
  String get svcLayerProtectiveForest => 'Zaštitna šuma';

  @override
  String get svcLayerProtectedArea => 'Zaštićeno područje';

  @override
  String get svcLayerNaturalValue => 'Prirodna vrijednost';

  @override
  String get svcLayerEpo => 'EPO';

  @override
  String get svcLayerHuntingGround => 'Lovište';

  @override
  String get svcLayerFireRisk => 'Opasnost od požara';

  @override
  String get svcLayerMunicipality => 'Općina';

  @override
  String get svcLayerCadastralMunicipality => 'Katastarska općina';

  @override
  String get svcAesBadFormat =>
      'Datoteka nije u očekivanom obliku (neispravno zaglavlje).';

  @override
  String get svcAesCorrupt => 'Datoteka je oštećena ili nepotpuna.';

  @override
  String get svcAesWrongPassword => 'Pogrešna zaporka.';

  @override
  String get svcNetTimeout => 'Veza je istekla. Pokušajte ponovno.';

  @override
  String get svcNetNoConnection => 'Nema internetske veze. Provjerite mrežu.';

  @override
  String get svcNetServerError =>
      'Poslužitelj nije dostupan. Pokušajte kasnije.';

  @override
  String get svcNetUnknown => 'Došlo je do pogreške. Pokušajte ponovno.';

  @override
  String get aboutTitle => 'O aplikaciji';

  @override
  String get aboutSectionMapSources => 'Izvori kartografskih podataka';

  @override
  String get aboutSectionLegal => 'Pravne informacije';

  @override
  String get aboutSectionOpenSource => 'Biblioteke otvorenog koda';

  @override
  String get aboutSectionSupport => 'Podrška';

  @override
  String get aboutSectionGeneral => 'Općenito';

  @override
  String get aboutSectionMapCache => 'Predmemorija karte';

  @override
  String get aboutTagline =>
      'Aplikacija za vlasnike šuma i šumarske radnike u Sloveniji';

  @override
  String get aboutInfoTitle => 'Informacije o aplikaciji';

  @override
  String get aboutVersion => 'Verzija';

  @override
  String get aboutBuildNumber => 'Broj izgradnje';

  @override
  String get aboutPackage => 'Paket';

  @override
  String get aboutDeveloperOptions => 'Opcije za razvojne programere';

  @override
  String get aboutOwnersDb => 'Baza vlasnika (katastar)';

  @override
  String get aboutNotImported => 'Nije uvezena.';

  @override
  String aboutOwnersCount(String count, String size) {
    return '$count vlasnika$size';
  }

  @override
  String get aboutOwnersDownloading => 'Preuzimam bazu vlasnika…';

  @override
  String get aboutOwnersUpdateButton => 'Ažuriraj (~300 MB)';

  @override
  String get aboutOwnersDownloadButton => 'Preuzmi (~300 MB)';

  @override
  String get aboutImportFromFile => 'Uvezi iz datoteke (.sqlite)';

  @override
  String get aboutRemove => 'Ukloni';

  @override
  String get aboutOfflineOwnerSearch => 'Pretraživanje vlasnika izvan mreže';

  @override
  String get aboutOfflineOwnerSearchDesc =>
      'Kada nema veze, vlasnik se određuje iz približnih granica čestica (lokalna baza).';

  @override
  String get aboutVlake => 'Vlake (šumske vlake)';

  @override
  String get aboutVlakeDesc =>
      'Omogući sloj — prikazuje se u izboru slojeva (Infrastruktura)';

  @override
  String get aboutHttpCache => 'HTTP predmemorija';

  @override
  String get aboutHttpCacheDesc =>
      'Sprema odgovore državnih API-ja (prostor.zgs.gov.si) u predmemoriju.';

  @override
  String get aboutTileCache => 'Predmemorija pločica';

  @override
  String get aboutTileCacheDesc =>
      'Sprema karte u predmemoriju (odvojeno od HTTP predmemorije).';

  @override
  String get aboutClearMapCache => 'Očisti predmemoriju karte';

  @override
  String get aboutPickSqlite => 'Odaberi datoteku .sqlite.';

  @override
  String aboutOwnersImported(String count) {
    return 'Uvezeno $count vlasnika.';
  }

  @override
  String aboutImportFailed(String error) {
    return 'Uvoz nije uspio: $error';
  }

  @override
  String get aboutOwnersRemoved => 'Baza vlasnika uklonjena.';

  @override
  String get aboutClearCacheTitle => 'Očistiti predmemoriju karte?';

  @override
  String get aboutClearCacheBody =>
      'Izbrisat će se sve spremljene karte, uključujući one preuzete za rad izvan mreže. Bez signala ih neće biti moguće prikazati dok ih ponovno ne preuzmete.';

  @override
  String get aboutCacheCleared => 'Predmemorija karte očišćena.';

  @override
  String aboutCacheClearFailed(String error) {
    return 'Brisanje predmemorije nije uspjelo: $error';
  }

  @override
  String get aboutOfflineKataster => 'Katastar izvan mreže (čestice)';

  @override
  String get aboutKatasterNotLoaded =>
      'Nije učitan — katastar se prikazuje putem interneta.';

  @override
  String aboutParcelsSummary(
    String regions,
    String count,
    String size,
    String date,
  ) {
    return '$regions$count čestica$size$date • izvan mreže';
  }

  @override
  String get aboutAddRegion => 'Dodaj regiju';

  @override
  String get aboutDownloadRegion => 'Preuzmi regiju';

  @override
  String get aboutDownloadRegionHint =>
      'Preuzmi samo svoju statističku regiju — preporučuje se Wi-Fi veza.';

  @override
  String get aboutShareKataster => 'Podijeli katastar izvan mreže';

  @override
  String aboutShareKatasterActive(int count) {
    return 'Dostupno u lokalnoj mreži • pronađenih uređaja: $count';
  }

  @override
  String get aboutShareKatasterDesc =>
      'Dopusti drugim uređajima u istoj mreži preuzimanje učitanih regija.';

  @override
  String get aboutPublicOwners => 'javni vlasnici';

  @override
  String aboutKatasterUpdateAvailable(String date) {
    return 'Dostupan je noviji katastar ($date)';
  }

  @override
  String aboutKatasterOutdated(String parts, String size) {
    return 'Zastarjelo: $parts$size';
  }

  @override
  String get updateLater => 'Kasnije';

  @override
  String get updateNow => 'Ažuriraj';

  @override
  String get aboutPublicOwnersLabel => 'Javni vlasnici…';

  @override
  String get aboutPublicOwnersFailed =>
      'Preuzimanje javnih vlasnika nije uspjelo.';

  @override
  String aboutErrorWithDetail(String error) {
    return 'Pogreška: $error';
  }

  @override
  String get aboutPickRegionsTitle => 'Odaberi statističke regije';

  @override
  String get aboutCountrySi => 'Slovenija';

  @override
  String get aboutCountryHr => 'Hrvatska';

  @override
  String aboutRegionParcels(String count) {
    return ' • $count čestica';
  }

  @override
  String get aboutRegionLoaded => ' • učitano';

  @override
  String aboutDownloadSelected(int count, String mb) {
    return 'Preuzmi $count (~$mb MB)';
  }

  @override
  String aboutRegionProgress(String name, int index, int total) {
    return '$name ($index/$total)…';
  }

  @override
  String aboutRegionsDownloaded(int count) {
    return 'Preuzetih regija: $count.';
  }

  @override
  String aboutRegionsFailed(String names) {
    return ' Neuspjelo: $names.';
  }

  @override
  String get aboutPasswordLabel => 'Lozinka';

  @override
  String get aboutUnlock => 'Otključaj';

  @override
  String get aboutOwnersPasswordTitle => 'Lozinka za bazu vlasnika';

  @override
  String aboutOwnersDownloaded(String count) {
    return 'Preuzeto $count vlasnika.';
  }

  @override
  String get aboutDownloadCancelled => 'Preuzimanje otkazano.';

  @override
  String aboutDownloadFailed(String error) {
    return 'Preuzimanje nije uspjelo: $error';
  }

  @override
  String aboutParcelsImported(String count) {
    return 'Uvezeno $count čestica.';
  }

  @override
  String get aboutParcelsRemoved => 'Baze čestica uklonjene.';

  @override
  String get aboutWipeSection => 'Izbriši podatke (baze čestica + vlasnika)';

  @override
  String get aboutWipeImported => 'Uvezene';

  @override
  String get aboutWipeDownloaded => 'Preuzete';

  @override
  String get aboutWipeAll => 'Sve';

  @override
  String get aboutWipeScopeAll => 'sve baze';

  @override
  String get aboutWipeScopeImported => 'uvezene baze';

  @override
  String get aboutWipeScopeDownloaded => 'preuzete baze';

  @override
  String get aboutWipeTitle => 'Izbriši podatke';

  @override
  String aboutWipeConfirm(String scope) {
    return 'Želiš li doista izbrisati $scope? Ovo se ne može poništiti.';
  }

  @override
  String get aboutWipeButton => 'Izbriši';

  @override
  String get aboutWipeNone => 'Nema odgovarajućih baza za brisanje.';

  @override
  String aboutWipeDone(int count) {
    return 'Izbrisanih baza: $count.';
  }

  @override
  String get aboutSrcZgsDesc =>
      'Šumarski slojevi, sastojine, odjeli, revire, šumski rezervati, zaštitne šume, opasnost od požara, vjetroizvale, potkornjaci';

  @override
  String get aboutSrcGursDesc =>
      'Ortofoto snimke (2022.-2024.), katastar, katastarske općine, općine, upravne jedinice, DMR';

  @override
  String get aboutSrcOsmDesc => 'Osnovna karta i topografski podaci';

  @override
  String get aboutSrcTopoDesc => 'Topografska karta (Seznam.cz)';

  @override
  String get aboutSrcEsriDesc => 'Satelitske snimke i topografska karta';

  @override
  String get aboutTermsTitle => 'Uvjeti korištenja';

  @override
  String get aboutDisclaimerTitle => 'Ograničenje odgovornosti';

  @override
  String get aboutCopyrightTitle => 'Autorska prava';

  @override
  String get aboutPrivacyTitle => 'Privatnost';

  @override
  String get aboutTermsBody =>
      'Aplikacija Gozdar namijenjena je isključivo informativnim svrhama. Podaci o česticama, šumskim sastojinama i drugim kartografskim slojevima preuzeti su iz javno dostupnih izvora i možda nisu ažurni ili posve točni.';

  @override
  String get aboutDisclaimerBody =>
      'Razvojni programer ne preuzima odgovornost za moguću štetu nastalu korištenjem aplikacije ili podataka u njoj. Za službene podatke o vlasništvu i granicama čestica obratite se nadležnim tijelima (GURS, ZGS).';

  @override
  String get aboutCopyrightBody =>
      'Kartografski podaci ZGS-a i GURS-a vlasništvo su Republike Slovenije. Podaci OpenStreetMapa dostupni su pod licencijom ODbL. ESRI podaci vlasništvo su tvrtke Esri Inc.';

  @override
  String get aboutPrivacyBody =>
      'Aplikacija prikuplja anonimne podatke o korištenju radi poboljšanja rada (Firebase Analytics). Podaci o lokaciji ne šalju se na poslužitelj - svi podaci o česticama i trupcima pohranjuju se lokalno na uređaju.';

  @override
  String get aboutShowLicenses => 'Prikaži licence';

  @override
  String get aboutLicensesDesc => 'Flutter i biblioteke otvorenog koda';

  @override
  String get aboutReportBug => 'Prijavi grešku';

  @override
  String get aboutContact => 'Kontakt';

  @override
  String get aboutContactDesc => 'Pošaljite povratne informacije';

  @override
  String get aboutSourceCode => 'Izvorni kôd';

  @override
  String get aboutSourceCodeDesc => 'Projekt otvorenog koda na GitHubu';

  @override
  String get aboutLanguage => 'Jezik';

  @override
  String get aboutLanguageAuto => 'Automatski';

  @override
  String get aboutDownloadingRegion => 'Preuzimam regiju…';

  @override
  String get updateAvailableTitle => 'Dostupno je novo ažuriranje';

  @override
  String updateVersion(String version) {
    return 'Verzija $version';
  }

  @override
  String get updateDownloading => 'Preuzimanje ažuriranja...';

  @override
  String get updateReadyTitle => 'Ažuriranje je spremno';

  @override
  String get updateReadyHint => 'Dodirni za instalaciju';

  @override
  String get updateInstall => 'Instaliraj';

  @override
  String get updateErrorTitle => 'Pogreška pri ažuriranju';

  @override
  String get updateRetry => 'Ponovi';

  @override
  String updateKatasterBanner(String date, String size) {
    return 'Dostupan je noviji katastar ($date$size).';
  }

  @override
  String get updateErrorAlreadyRunning => 'Preuzimanje je već u tijeku';

  @override
  String get updateErrorPermission => 'Dopuštenje za instalaciju je odbijeno';

  @override
  String get updateErrorInternal => 'Unutarnja pogreška';

  @override
  String get updateErrorDownload => 'Preuzimanje nije uspjelo';

  @override
  String get updateErrorChecksum => 'Provjera kontrolnog zbroja nije uspjela';

  @override
  String get updateErrorInstall => 'Instalacija nije uspjela';

  @override
  String get navTabMap => 'Karta';

  @override
  String get navTabForest => 'Šuma';

  @override
  String get navTabLogs => 'Trupci';

  @override
  String navTabSemantic(String name) {
    return 'Kartica $name';
  }

  @override
  String get navOnboardingReset =>
      'Uvodni vodič je resetiran. Ponovno pokreni aplikaciju.';

  @override
  String get introSkip => 'Preskoči';

  @override
  String get introStart => 'Započni';

  @override
  String get introWelcomeTitle => 'Dobrodošli u Gozdar';

  @override
  String get introWelcomeBody =>
      'Aplikacija za vlasnike šuma i šumarske radnike u Sloveniji.\n\nPratite sječu, bilježite trupce i koristite GPS za rad na terenu.';

  @override
  String get introNavTitle => 'Navigacija';

  @override
  String get introNavMapDesc => 'Interaktivna karta s vašim česticama';

  @override
  String get introNavForestDesc => 'Popis čestica i pretraživanje u katastru';

  @override
  String get introNavLogsDesc => 'Bilježenje trupaca s izračunom obujma';

  @override
  String get introLogsTitle => 'Bilježenje trupaca';

  @override
  String get introLogsDiameter => 'Promjer: 45 cm';

  @override
  String get introLogsLength => 'Duljina: 4.5 m';

  @override
  String get introLogsVolume => 'Obujam: 0.716 m³';

  @override
  String get introLogsSpecies => 'Vrste drveća';

  @override
  String get introLogsSpeciesDesc =>
      'Bilježite vrstu drva (smreka, bukva, jela, ...)';

  @override
  String get introLogsAutoCalc => 'Automatski izračun';

  @override
  String get introLogsAutoCalcDesc =>
      'Aplikacija izračunava obujam iz promjera i duljine';

  @override
  String get introLogsGrouping => 'Razvrstavanje';

  @override
  String get introLogsGroupingDesc =>
      'Trupci se automatski razvrstavaju po vrstama';

  @override
  String get introLogsManage => 'Upravljanje vrstama';

  @override
  String get introLogsManageDesc => 'Dodajte ili uklonite vrste u izborniku ⋮';

  @override
  String get introLongPressTitle => 'Dugi pritisak na karti';

  @override
  String get introLongPressAddPoint => 'Dodaj točku';

  @override
  String get introLongPressAddPointDesc => 'Spremi lokaciju (međaš, skladište)';

  @override
  String get introLongPressAddLogs => 'Dodaj trupce';

  @override
  String get introLongPressAddLogsDesc =>
      'Bilježenje trupca s GPS koordinatama';

  @override
  String get introLongPressMarkCut => 'Označi sječu';

  @override
  String get introLongPressMarkCutDesc => 'Označi stablo za sječu na karti';

  @override
  String get introLongPressImport => 'Uvezi česticu';

  @override
  String get introLongPressImportDesc =>
      'Dohvati česticu iz katastra na trenutnoj lokaciji';

  @override
  String get introLongPressHint => 'Držite prst na karti za prikaz izbornika';

  @override
  String get introMarkersTitle => 'Oznake na karti';

  @override
  String get introMarkerPoint => 'Točka';

  @override
  String get introMarkerLog => 'Trupac';

  @override
  String get introMarkerCut => 'Sječa';

  @override
  String get introMarkersRed => 'Crvene';

  @override
  String get introMarkersRedDesc => 'Spremljene lokacije (međaši, skladišta)';

  @override
  String get introMarkersBrown => 'Smeđe';

  @override
  String get introMarkersBrownDesc => 'Trupci s GPS lokacijom';

  @override
  String get introMarkersOrange => 'Narančaste';

  @override
  String get introMarkersOrangeDesc => 'Stabla označena za sječu';

  @override
  String get introMarkersLinked =>
      'Trupci i sječe automatski se povezuju s česticom';

  @override
  String get introLayersTitle => 'Slojevi na karti';

  @override
  String get introLayersButtonHint => 'Pritisnite za odabir slojeva';

  @override
  String get introLayersOrthoDesc => 'Satelitske snimke Slovenije';

  @override
  String get introLayersCadastreDesc => 'Granice čestica iz katastra';

  @override
  String get introLayersStands => 'Šumske sastojine';

  @override
  String get introLayersStandsDesc => 'Podaci Zavoda za šume';

  @override
  String get introLayersTopo => 'Topografija';

  @override
  String get introLayersTopoDesc => 'DTK i druge karte';

  @override
  String get introOfflineTitle => 'Rad izvan mreže';

  @override
  String get introOfflineAutoCache => 'Automatsko spremanje u predmemoriju';

  @override
  String get introOfflineAutoCacheDesc =>
      'Pregledane karte spremaju se za kasnije korištenje';

  @override
  String get introOfflineOnSearch => 'Pri pretraživanju čestice';

  @override
  String get introOfflineOnSearchDesc =>
      'Karte za područje čestice preuzimaju se automatski';

  @override
  String get introOfflineManual => 'Ručno preuzimanje';

  @override
  String get introOfflineManualDesc =>
      'Za preuzimanje područja koristite gumb za slojeve na karti';

  @override
  String get introOfflineHint => 'Karte rade i u šumi bez signala!';

  @override
  String get introCompassTitle => 'Navigacija do međaša';

  @override
  String get introCompassMarker => 'Međaš 1 • 45m';

  @override
  String get introCompassStep1 => 'Otvorite česticu';

  @override
  String get introCompassStep1Desc => 'U kartici Šuma odaberite česticu';

  @override
  String get introCompassStep2 => 'Dodirnite graničnu točku';

  @override
  String get introCompassStep2Desc => 'Odaberite točku na karti čestice';

  @override
  String get introCompassStep3 => 'Aktivirajte kompas';

  @override
  String get introCompassStep3Desc => 'Dodirnite narančastu navigacijsku traku';

  @override
  String get introCompassStep4 => 'Slijedite smjer';

  @override
  String get introCompassStep4Desc =>
      'Kompas pokazuje smjer i udaljenost do točke';

  @override
  String get introTermsTitle => 'Uvjeti korištenja';

  @override
  String get introTermsBody =>
      'Aplikacija koristi javne podatke Zavoda za šume Slovenije.\n\nKorištenjem ove aplikacije slažete se s uvjetima korištenja podataka:\n\n';
}
