import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_hr.dart';
import 'app_localizations_sl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('hr'),
    Locale('sl'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In sl, this message translates to:
  /// **'Gozdar'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In sl, this message translates to:
  /// **'Prekliči'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In sl, this message translates to:
  /// **'Shrani'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In sl, this message translates to:
  /// **'Izbriši'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In sl, this message translates to:
  /// **'Zapri'**
  String get commonClose;

  /// No description provided for @commonOk.
  ///
  /// In sl, this message translates to:
  /// **'V redu'**
  String get commonOk;

  /// No description provided for @commonEdit.
  ///
  /// In sl, this message translates to:
  /// **'Uredi'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj'**
  String get commonAdd;

  /// No description provided for @commonYes.
  ///
  /// In sl, this message translates to:
  /// **'Da'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In sl, this message translates to:
  /// **'Ne'**
  String get commonNo;

  /// No description provided for @commonBack.
  ///
  /// In sl, this message translates to:
  /// **'Nazaj'**
  String get commonBack;

  /// No description provided for @commonRetry.
  ///
  /// In sl, this message translates to:
  /// **'Poskusi znova'**
  String get commonRetry;

  /// No description provided for @commonSearch.
  ///
  /// In sl, this message translates to:
  /// **'Iskanje'**
  String get commonSearch;

  /// No description provided for @commonShare.
  ///
  /// In sl, this message translates to:
  /// **'Deli'**
  String get commonShare;

  /// No description provided for @commonDownload.
  ///
  /// In sl, this message translates to:
  /// **'Prenesi'**
  String get commonDownload;

  /// No description provided for @commonContinue.
  ///
  /// In sl, this message translates to:
  /// **'Naprej'**
  String get commonContinue;

  /// No description provided for @commonDone.
  ///
  /// In sl, this message translates to:
  /// **'Končano'**
  String get commonDone;

  /// No description provided for @commonSettings.
  ///
  /// In sl, this message translates to:
  /// **'Nastavitve'**
  String get commonSettings;

  /// No description provided for @commonError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka'**
  String get commonError;

  /// No description provided for @commonLoading.
  ///
  /// In sl, this message translates to:
  /// **'Nalaganje …'**
  String get commonLoading;

  /// No description provided for @logsHeaderTitle.
  ///
  /// In sl, this message translates to:
  /// **'Hlodi'**
  String get logsHeaderTitle;

  /// No description provided for @logsMoreOptionsTooltip.
  ///
  /// In sl, this message translates to:
  /// **'Več možnosti hlodov'**
  String get logsMoreOptionsTooltip;

  /// No description provided for @logsMenuManageSpecies.
  ///
  /// In sl, this message translates to:
  /// **'Upravljanje vrst'**
  String get logsMenuManageSpecies;

  /// No description provided for @logsMenuExport.
  ///
  /// In sl, this message translates to:
  /// **'Izvozi'**
  String get logsMenuExport;

  /// No description provided for @logsMenuDeleteAll.
  ///
  /// In sl, this message translates to:
  /// **'Odstrani vse'**
  String get logsMenuDeleteAll;

  /// No description provided for @logsSavedTooltip.
  ///
  /// In sl, this message translates to:
  /// **'Shranjeno'**
  String get logsSavedTooltip;

  /// No description provided for @logsSaved.
  ///
  /// In sl, this message translates to:
  /// **'Shranjeno'**
  String get logsSaved;

  /// No description provided for @logsSaveError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri shranjevanju'**
  String get logsSaveError;

  /// No description provided for @logsEntryUpdated.
  ///
  /// In sl, this message translates to:
  /// **'Vnos posodobljen'**
  String get logsEntryUpdated;

  /// No description provided for @logsErrorWithDetail.
  ///
  /// In sl, this message translates to:
  /// **'Napaka: {error}'**
  String logsErrorWithDetail(String error);

  /// No description provided for @logsEntryDeleted.
  ///
  /// In sl, this message translates to:
  /// **'Vnos izbrisan'**
  String get logsEntryDeleted;

  /// No description provided for @logsUndo.
  ///
  /// In sl, this message translates to:
  /// **'Razveljavi'**
  String get logsUndo;

  /// No description provided for @logsExportTitle.
  ///
  /// In sl, this message translates to:
  /// **'Izvozi hlode'**
  String get logsExportTitle;

  /// No description provided for @logsExportExcel.
  ///
  /// In sl, this message translates to:
  /// **'Izvozi kot Excel'**
  String get logsExportExcel;

  /// No description provided for @logsExportJson.
  ///
  /// In sl, this message translates to:
  /// **'Izvozi kot JSON'**
  String get logsExportJson;

  /// No description provided for @logsExportSuccess.
  ///
  /// In sl, this message translates to:
  /// **'Izvoz uspešen'**
  String get logsExportSuccess;

  /// No description provided for @logsNoEntriesToDelete.
  ///
  /// In sl, this message translates to:
  /// **'Ni vnosov za brisanje'**
  String get logsNoEntriesToDelete;

  /// No description provided for @logsDeleteAllTitle.
  ///
  /// In sl, this message translates to:
  /// **'Odstrani vse hlode'**
  String get logsDeleteAllTitle;

  /// No description provided for @logsDeleteAllConfirm.
  ///
  /// In sl, this message translates to:
  /// **'Ali ste prepričani, da želite odstraniti vseh {count} vnosov?\n\nSkupni volumen: {volume} m³\n\nShranjeni hlodi ostanejo nespremenjeni. To dejanje ni mogoče razveljaviti.'**
  String logsDeleteAllConfirm(int count, String volume);

  /// No description provided for @logsAllEntriesRemoved.
  ///
  /// In sl, this message translates to:
  /// **'Vsi vnosi odstranjeni'**
  String get logsAllEntriesRemoved;

  /// No description provided for @logsNoEntriesToSave.
  ///
  /// In sl, this message translates to:
  /// **'Ni vnosov za shranjevanje'**
  String get logsNoEntriesToSave;

  /// No description provided for @logsCountLogs.
  ///
  /// In sl, this message translates to:
  /// **'{count, plural, one{{count} hlod} two{{count} hloda} few{{count} hlodi} other{{count} hlodov}}'**
  String logsCountLogs(int count);

  /// No description provided for @logsGroupSummary.
  ///
  /// In sl, this message translates to:
  /// **'{count, plural, one{{count} hlod} two{{count} hloda} few{{count} hlodi} other{{count} hlodov}} • {volume} m³'**
  String logsGroupSummary(int count, String volume);

  /// No description provided for @logsSaveSheetSummary.
  ///
  /// In sl, this message translates to:
  /// **'{volume} m³ • {count, plural, one{{count} hlod} two{{count} hloda} few{{count} hlodi} other{{count} hlodov}}'**
  String logsSaveSheetSummary(int count, String volume);

  /// No description provided for @logsSpeciesNotSelected.
  ///
  /// In sl, this message translates to:
  /// **'Vrsta ni izbrana'**
  String get logsSpeciesNotSelected;

  /// No description provided for @logsUnknownSpecies.
  ///
  /// In sl, this message translates to:
  /// **'Neznana vrsta'**
  String get logsUnknownSpecies;

  /// No description provided for @logsEmptyTitle.
  ///
  /// In sl, this message translates to:
  /// **'Ni še hlodov'**
  String get logsEmptyTitle;

  /// No description provided for @logsEmptyHint.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite premer in dolžino spodaj'**
  String get logsEmptyHint;

  /// No description provided for @logsDiameterLabel.
  ///
  /// In sl, this message translates to:
  /// **'Premer (cm)'**
  String get logsDiameterLabel;

  /// No description provided for @logsLengthLabel.
  ///
  /// In sl, this message translates to:
  /// **'Dolžina (m)'**
  String get logsLengthLabel;

  /// No description provided for @logsVolumeLabel.
  ///
  /// In sl, this message translates to:
  /// **'Volumen'**
  String get logsVolumeLabel;

  /// No description provided for @logsSpeciesLabel.
  ///
  /// In sl, this message translates to:
  /// **'Drevesna vrsta'**
  String get logsSpeciesLabel;

  /// No description provided for @logsNotSelected.
  ///
  /// In sl, this message translates to:
  /// **'Ni izbrano'**
  String get logsNotSelected;

  /// No description provided for @logsLocationLabel.
  ///
  /// In sl, this message translates to:
  /// **'Lokacija'**
  String get logsLocationLabel;

  /// No description provided for @logsAddLocation.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj lokacijo'**
  String get logsAddLocation;

  /// No description provided for @logsNameLabel.
  ///
  /// In sl, this message translates to:
  /// **'Ime'**
  String get logsNameLabel;

  /// No description provided for @logsNameHint.
  ///
  /// In sl, this message translates to:
  /// **'npr. Smreka za Novaka'**
  String get logsNameHint;

  /// No description provided for @logsNotesLabel.
  ///
  /// In sl, this message translates to:
  /// **'Opombe'**
  String get logsNotesLabel;

  /// No description provided for @logsNotesEditorHint.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite opombe'**
  String get logsNotesEditorHint;

  /// No description provided for @logsLocationPermissionDenied.
  ///
  /// In sl, this message translates to:
  /// **'Dovoljenje za lokacijo zavrnjeno'**
  String get logsLocationPermissionDenied;

  /// No description provided for @logsSaveErrorWithDetail.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri shranjevanju: {error}'**
  String logsSaveErrorWithDetail(String error);

  /// No description provided for @logsInlineAdded.
  ///
  /// In sl, this message translates to:
  /// **'Dodano: {count}'**
  String logsInlineAdded(int count);

  /// No description provided for @logsSpeciesAddTitle.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj novo vrsto'**
  String get logsSpeciesAddTitle;

  /// No description provided for @logsSpeciesNameLabel.
  ///
  /// In sl, this message translates to:
  /// **'Ime vrste'**
  String get logsSpeciesNameLabel;

  /// No description provided for @logsSpeciesNameHint.
  ///
  /// In sl, this message translates to:
  /// **'Npr. Hrast'**
  String get logsSpeciesNameHint;

  /// No description provided for @logsSpeciesAdded.
  ///
  /// In sl, this message translates to:
  /// **'Vrsta \"{name}\" dodana'**
  String logsSpeciesAdded(String name);

  /// No description provided for @logsSpeciesRemoveTitle.
  ///
  /// In sl, this message translates to:
  /// **'Odstrani vrsto'**
  String get logsSpeciesRemoveTitle;

  /// No description provided for @logsSpeciesRemoveConfirm.
  ///
  /// In sl, this message translates to:
  /// **'Ali ste prepričani, da želite odstraniti \"{name}\"?'**
  String logsSpeciesRemoveConfirm(String name);

  /// No description provided for @logsSpeciesRemoveButton.
  ///
  /// In sl, this message translates to:
  /// **'Odstrani'**
  String get logsSpeciesRemoveButton;

  /// No description provided for @logsSpeciesRemoved.
  ///
  /// In sl, this message translates to:
  /// **'Vrsta \"{name}\" odstranjena'**
  String logsSpeciesRemoved(String name);

  /// No description provided for @logsSpeciesResetTitle.
  ///
  /// In sl, this message translates to:
  /// **'Ponastavi na privzeto'**
  String get logsSpeciesResetTitle;

  /// No description provided for @logsSpeciesResetConfirm.
  ///
  /// In sl, this message translates to:
  /// **'Ali ste prepričani, da želite ponastaviti vrste na privzete vrednosti?\n\nVse dodane vrste bodo odstranjene.'**
  String get logsSpeciesResetConfirm;

  /// No description provided for @logsSpeciesResetButton.
  ///
  /// In sl, this message translates to:
  /// **'Ponastavi'**
  String get logsSpeciesResetButton;

  /// No description provided for @logsSpeciesResetDone.
  ///
  /// In sl, this message translates to:
  /// **'Vrste ponastavljene na privzete'**
  String get logsSpeciesResetDone;

  /// No description provided for @logsSpeciesCount.
  ///
  /// In sl, this message translates to:
  /// **'{count, plural, one{{count} vrsta} two{{count} vrsti} few{{count} vrste} other{{count} vrst}}'**
  String logsSpeciesCount(int count);

  /// No description provided for @logsSpeciesNone.
  ///
  /// In sl, this message translates to:
  /// **'Ni dodanih vrst'**
  String get logsSpeciesNone;

  /// No description provided for @logsConvTitle.
  ///
  /// In sl, this message translates to:
  /// **'Pretvorba volumna'**
  String get logsConvTitle;

  /// No description provided for @logsConvSpeciesHint.
  ///
  /// In sl, this message translates to:
  /// **'Vrsta, ki jo dobijo novo dodani hlodi.'**
  String get logsConvSpeciesHint;

  /// No description provided for @logsConvPrmTitle.
  ///
  /// In sl, this message translates to:
  /// **'PRM - Prostorninski meter drv'**
  String get logsConvPrmTitle;

  /// No description provided for @logsConvPrmDesc.
  ///
  /// In sl, this message translates to:
  /// **'Zložena drva (polena). 1 PRM × faktor = m³ trdne mase.'**
  String get logsConvPrmDesc;

  /// No description provided for @logsConvNmTitle.
  ///
  /// In sl, this message translates to:
  /// **'NM - Nasuti meter'**
  String get logsConvNmTitle;

  /// No description provided for @logsConvNmDesc.
  ///
  /// In sl, this message translates to:
  /// **'Nasut les (sekanci, odpadki). 1 NM × faktor = m³ trdne mase.'**
  String get logsConvNmDesc;

  /// No description provided for @logsConvDefault.
  ///
  /// In sl, this message translates to:
  /// **'Privzeto'**
  String get logsConvDefault;

  /// No description provided for @logsConvBeechOak.
  ///
  /// In sl, this message translates to:
  /// **'Bukev/Hrast'**
  String get logsConvBeechOak;

  /// No description provided for @logsConvSpruceFir.
  ///
  /// In sl, this message translates to:
  /// **'Smreka/Jelka'**
  String get logsConvSpruceFir;

  /// No description provided for @logsConvSoftHardwood.
  ///
  /// In sl, this message translates to:
  /// **'Mehki listavci'**
  String get logsConvSoftHardwood;

  /// No description provided for @logsConvHardWood.
  ///
  /// In sl, this message translates to:
  /// **'Trdi les'**
  String get logsConvHardWood;

  /// No description provided for @logsConvSoftWood.
  ///
  /// In sl, this message translates to:
  /// **'Mehki les'**
  String get logsConvSoftWood;

  /// No description provided for @logsConvConfirm.
  ///
  /// In sl, this message translates to:
  /// **'Potrdi'**
  String get logsConvConfirm;

  /// No description provided for @logsConvCustomFactor.
  ///
  /// In sl, this message translates to:
  /// **'Faktor po meri'**
  String get logsConvCustomFactor;

  /// No description provided for @logsFormLocationServicesDisabled.
  ///
  /// In sl, this message translates to:
  /// **'Lokacijske storitve so onemogočene'**
  String get logsFormLocationServicesDisabled;

  /// No description provided for @logsFormPermissionsDenied.
  ///
  /// In sl, this message translates to:
  /// **'Dovoljenja za lokacijo zavrnjena'**
  String get logsFormPermissionsDenied;

  /// No description provided for @logsFormPermissionsDeniedForever.
  ///
  /// In sl, this message translates to:
  /// **'Dovoljenja za lokacijo trajno zavrnjena'**
  String get logsFormPermissionsDeniedForever;

  /// No description provided for @logsFormLocationAdded.
  ///
  /// In sl, this message translates to:
  /// **'Lokacija dodana'**
  String get logsFormLocationAdded;

  /// No description provided for @logsFormLocationError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri pridobivanju lokacije: {error}'**
  String logsFormLocationError(String error);

  /// No description provided for @logsFormInvalidDimensions.
  ///
  /// In sl, this message translates to:
  /// **'Prosim vnesite veljavne dimenzije'**
  String get logsFormInvalidDimensions;

  /// No description provided for @logsFormTitleNew.
  ///
  /// In sl, this message translates to:
  /// **'Nov'**
  String get logsFormTitleNew;

  /// No description provided for @logsFormVolumeModeTitle.
  ///
  /// In sl, this message translates to:
  /// **'Način vnosa volumna'**
  String get logsFormVolumeModeTitle;

  /// No description provided for @logsFormModeCalculate.
  ///
  /// In sl, this message translates to:
  /// **'Izračunaj iz dimenzij'**
  String get logsFormModeCalculate;

  /// No description provided for @logsFormModeDirect.
  ///
  /// In sl, this message translates to:
  /// **'Vnesi volumen neposredno'**
  String get logsFormModeDirect;

  /// No description provided for @logsFormDiameterHelper.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite premer hloda v centimetrih'**
  String get logsFormDiameterHelper;

  /// No description provided for @logsFormDiameterRequired.
  ///
  /// In sl, this message translates to:
  /// **'Prosim vnesite premer'**
  String get logsFormDiameterRequired;

  /// No description provided for @logsFormDiameterInvalid.
  ///
  /// In sl, this message translates to:
  /// **'Prosim vnesite veljaven premer'**
  String get logsFormDiameterInvalid;

  /// No description provided for @logsFormLengthHelper.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite dolžino hloda v metrih'**
  String get logsFormLengthHelper;

  /// No description provided for @logsFormLengthRequired.
  ///
  /// In sl, this message translates to:
  /// **'Prosim vnesite dolžino'**
  String get logsFormLengthRequired;

  /// No description provided for @logsFormLengthInvalid.
  ///
  /// In sl, this message translates to:
  /// **'Prosim vnesite veljavno dolžino'**
  String get logsFormLengthInvalid;

  /// No description provided for @logsFormCalculatedVolume.
  ///
  /// In sl, this message translates to:
  /// **'Izračunan volumen'**
  String get logsFormCalculatedVolume;

  /// No description provided for @logsFormVolumeLabel.
  ///
  /// In sl, this message translates to:
  /// **'Volumen (m³)'**
  String get logsFormVolumeLabel;

  /// No description provided for @logsFormVolumeHelper.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite volumen v kubičnih metrih'**
  String get logsFormVolumeHelper;

  /// No description provided for @logsFormVolumeRequired.
  ///
  /// In sl, this message translates to:
  /// **'Prosim vnesite volumen'**
  String get logsFormVolumeRequired;

  /// No description provided for @logsFormVolumeInvalid.
  ///
  /// In sl, this message translates to:
  /// **'Prosim vnesite veljaven volumen'**
  String get logsFormVolumeInvalid;

  /// No description provided for @logsFormSpeciesOptional.
  ///
  /// In sl, this message translates to:
  /// **'Drevesna vrsta (neobvezno)'**
  String get logsFormSpeciesOptional;

  /// No description provided for @logsFormLocating.
  ///
  /// In sl, this message translates to:
  /// **'Pridobivanje lokacije...'**
  String get logsFormLocating;

  /// No description provided for @logsFormAddCurrentLocation.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj trenutno lokacijo'**
  String get logsFormAddCurrentLocation;

  /// No description provided for @logsFormNotesOptional.
  ///
  /// In sl, this message translates to:
  /// **'Opombe (neobvezno)'**
  String get logsFormNotesOptional;

  /// No description provided for @logsFormNotesHelper.
  ///
  /// In sl, this message translates to:
  /// **'Dodajte morebitne opombe'**
  String get logsFormNotesHelper;

  /// No description provided for @logsSaveSheetTitle.
  ///
  /// In sl, this message translates to:
  /// **'Shrani hlode'**
  String get logsSaveSheetTitle;

  /// No description provided for @logsSaveSheetDefaultName.
  ///
  /// In sl, this message translates to:
  /// **'Hlodi {date}'**
  String logsSaveSheetDefaultName(String date);

  /// No description provided for @logsSavedSheetTitle.
  ///
  /// In sl, this message translates to:
  /// **'Shranjene meritve'**
  String get logsSavedSheetTitle;

  /// No description provided for @logsSavedSheetEmpty.
  ///
  /// In sl, this message translates to:
  /// **'Ni shranjenih meritev'**
  String get logsSavedSheetEmpty;

  /// No description provided for @logsSavedSheetNoName.
  ///
  /// In sl, this message translates to:
  /// **'Brez imena'**
  String get logsSavedSheetNoName;

  /// No description provided for @logsSavedDeleteTitle.
  ///
  /// In sl, this message translates to:
  /// **'Izbriši shranjene hlode'**
  String get logsSavedDeleteTitle;

  /// No description provided for @logsSavedDeleteConfirm.
  ///
  /// In sl, this message translates to:
  /// **'Ali ste prepričani, da želite izbrisati ta zapis?\n\nHlodi se vrnejo na seznam Hlodi.'**
  String get logsSavedDeleteConfirm;

  /// No description provided for @logsExportSheetName.
  ///
  /// In sl, this message translates to:
  /// **'Hlodi'**
  String get logsExportSheetName;

  /// No description provided for @logsExportHeaderDiameter.
  ///
  /// In sl, this message translates to:
  /// **'Premer (cm)'**
  String get logsExportHeaderDiameter;

  /// No description provided for @logsExportHeaderLength.
  ///
  /// In sl, this message translates to:
  /// **'Dolžina (m)'**
  String get logsExportHeaderLength;

  /// No description provided for @logsExportHeaderVolume.
  ///
  /// In sl, this message translates to:
  /// **'Volumen (m³)'**
  String get logsExportHeaderVolume;

  /// No description provided for @logsExportHeaderNotes.
  ///
  /// In sl, this message translates to:
  /// **'Opombe'**
  String get logsExportHeaderNotes;

  /// No description provided for @logsExportHeaderDate.
  ///
  /// In sl, this message translates to:
  /// **'Datum'**
  String get logsExportHeaderDate;

  /// No description provided for @logsExportShareSubject.
  ///
  /// In sl, this message translates to:
  /// **'Gozdar Hlodi Export'**
  String get logsExportShareSubject;

  /// No description provided for @logsExportShareText.
  ///
  /// In sl, this message translates to:
  /// **'Izvoženih {count} vnosov'**
  String logsExportShareText(int count);

  /// No description provided for @batchDefaultTitle.
  ///
  /// In sl, this message translates to:
  /// **'Shranjeni hlodi'**
  String get batchDefaultTitle;

  /// No description provided for @batchDeleteConfirm.
  ///
  /// In sl, this message translates to:
  /// **'Ali ste prepričani, da želite izbrisati \"{name}\"?\n\nHlodi ({count}) se vrnejo na seznam Hlodi.'**
  String batchDeleteConfirm(String name, int count);

  /// No description provided for @batchDeleteFallbackName.
  ///
  /// In sl, this message translates to:
  /// **'shranjene hlode'**
  String get batchDeleteFallbackName;

  /// No description provided for @batchLogDeleted.
  ///
  /// In sl, this message translates to:
  /// **'Hlod izbrisan'**
  String get batchLogDeleted;

  /// No description provided for @batchNoLogsToExport.
  ///
  /// In sl, this message translates to:
  /// **'Ni hlodov za izvoz'**
  String get batchNoLogsToExport;

  /// No description provided for @batchEditInfoTooltip.
  ///
  /// In sl, this message translates to:
  /// **'Uredi info'**
  String get batchEditInfoTooltip;

  /// No description provided for @batchEmptyHint.
  ///
  /// In sl, this message translates to:
  /// **'Tapnite + za dodajanje hloda'**
  String get batchEmptyHint;

  /// No description provided for @batchAddTitleCount.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj (+{count})'**
  String batchAddTitleCount(int count);

  /// No description provided for @batchValidatorEnter.
  ///
  /// In sl, this message translates to:
  /// **'Vnesi'**
  String get batchValidatorEnter;

  /// No description provided for @batchVolumeLine.
  ///
  /// In sl, this message translates to:
  /// **'Volumen: {volume} m³'**
  String batchVolumeLine(String volume);

  /// No description provided for @batchNotesHint.
  ///
  /// In sl, this message translates to:
  /// **'Dodatne opombe'**
  String get batchNotesHint;

  /// No description provided for @forestTitle.
  ///
  /// In sl, this message translates to:
  /// **'Moj Gozd'**
  String get forestTitle;

  /// No description provided for @forestFilterByOwner.
  ///
  /// In sl, this message translates to:
  /// **'Filtriraj po lastniku'**
  String get forestFilterByOwner;

  /// No description provided for @forestMoreOptionsTooltip.
  ///
  /// In sl, this message translates to:
  /// **'Več možnosti gozda'**
  String get forestMoreOptionsTooltip;

  /// No description provided for @forestExportKml.
  ///
  /// In sl, this message translates to:
  /// **'Izvozi KML'**
  String get forestExportKml;

  /// No description provided for @forestSummaryArea.
  ///
  /// In sl, this message translates to:
  /// **'Površina'**
  String get forestSummaryArea;

  /// No description provided for @forestSummaryParcels.
  ///
  /// In sl, this message translates to:
  /// **'Parcel'**
  String get forestSummaryParcels;

  /// No description provided for @forestSummaryTrees.
  ///
  /// In sl, this message translates to:
  /// **'Dreves'**
  String get forestSummaryTrees;

  /// No description provided for @forestSummaryCut.
  ///
  /// In sl, this message translates to:
  /// **'Posekano'**
  String get forestSummaryCut;

  /// No description provided for @forestLoadError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri nalaganju: {error}'**
  String forestLoadError(String error);

  /// No description provided for @forestDeleteError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri brisanju: {error}'**
  String forestDeleteError(String error);

  /// No description provided for @forestExportError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri izvozu: {error}'**
  String forestExportError(String error);

  /// No description provided for @forestDeleteTitle.
  ///
  /// In sl, this message translates to:
  /// **'Izbriši parcelo'**
  String get forestDeleteTitle;

  /// No description provided for @forestDeleteConfirm.
  ///
  /// In sl, this message translates to:
  /// **'Ali ste prepričani, da želite izbrisati \"{name}\"?\n\nIzbrisane bodo tudi vse točke, sečnje in hlodovina znotraj parcele.'**
  String forestDeleteConfirm(String name);

  /// No description provided for @forestDeleted.
  ///
  /// In sl, this message translates to:
  /// **'Parcela izbrisana{extra}'**
  String forestDeleted(String extra);

  /// No description provided for @forestCountPoints.
  ///
  /// In sl, this message translates to:
  /// **'{count, plural, one{{count} točka} two{{count} točki} few{{count} točke} other{{count} točk}}'**
  String forestCountPoints(int count);

  /// No description provided for @forestCountParcels.
  ///
  /// In sl, this message translates to:
  /// **'{count, plural, one{{count} parcela} two{{count} parceli} few{{count} parcele} other{{count} parcel}}'**
  String forestCountParcels(int count);

  /// No description provided for @forestCountTrees.
  ///
  /// In sl, this message translates to:
  /// **'{count, plural, one{{count} drevo} two{{count} drevesi} few{{count} drevesa} other{{count} dreves}}'**
  String forestCountTrees(int count);

  /// No description provided for @forestNoParcelsToExport.
  ///
  /// In sl, this message translates to:
  /// **'Ni parcel za izvoz'**
  String get forestNoParcelsToExport;

  /// No description provided for @forestKmlExported.
  ///
  /// In sl, this message translates to:
  /// **'KML uspešno izvožen'**
  String get forestKmlExported;

  /// No description provided for @forestNoOwners.
  ///
  /// In sl, this message translates to:
  /// **'Ni parcel z določenimi lastniki'**
  String get forestNoOwners;

  /// No description provided for @forestShowAll.
  ///
  /// In sl, this message translates to:
  /// **'Prikaži vse'**
  String get forestShowAll;

  /// No description provided for @forestNoParcelsForOwner.
  ///
  /// In sl, this message translates to:
  /// **'Ni parcel za \"{owner}\"'**
  String forestNoParcelsForOwner(String owner);

  /// No description provided for @forestEmptyTitle.
  ///
  /// In sl, this message translates to:
  /// **'Ni še parcel'**
  String get forestEmptyTitle;

  /// No description provided for @forestEmptyHint.
  ///
  /// In sl, this message translates to:
  /// **'Poiščite parcelo v katastru\nali jo uvozite iz KML'**
  String get forestEmptyHint;

  /// No description provided for @forestSearchParcel.
  ///
  /// In sl, this message translates to:
  /// **'Išči parcelo'**
  String get forestSearchParcel;

  /// No description provided for @forestNoKo.
  ///
  /// In sl, this message translates to:
  /// **'Brez KO'**
  String get forestNoKo;

  /// No description provided for @forestKoLabel.
  ///
  /// In sl, this message translates to:
  /// **'KO {code}'**
  String forestKoLabel(String code);

  /// No description provided for @mapTabMejnikName.
  ///
  /// In sl, this message translates to:
  /// **'Mejnik {number} ({parcela})'**
  String mapTabMejnikName(int number, String parcela);

  /// No description provided for @mapTabLocationServicesDisabled.
  ///
  /// In sl, this message translates to:
  /// **'Lokacijske storitve so onemogočene'**
  String get mapTabLocationServicesDisabled;

  /// No description provided for @mapTabLocationPermissionDenied.
  ///
  /// In sl, this message translates to:
  /// **'Dovoljenje za lokacijo zavrnjeno'**
  String get mapTabLocationPermissionDenied;

  /// No description provided for @mapTabLocationPermissionDeniedForever.
  ///
  /// In sl, this message translates to:
  /// **'Dovoljenje za lokacijo trajno zavrnjeno'**
  String get mapTabLocationPermissionDeniedForever;

  /// No description provided for @mapTabLocationError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri pridobivanju lokacije: {error}'**
  String mapTabLocationError(Object error);

  /// No description provided for @mapTabLocationAdded.
  ///
  /// In sl, this message translates to:
  /// **'Dodano \"{name}\"'**
  String mapTabLocationAdded(String name);

  /// No description provided for @mapTabErrorWithMessage.
  ///
  /// In sl, this message translates to:
  /// **'Napaka: {error}'**
  String mapTabErrorWithMessage(Object error);

  /// No description provided for @mapTabLocationAddError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri dodajanju lokacije: {error}'**
  String mapTabLocationAddError(Object error);

  /// No description provided for @mapTabSecnjaMarked.
  ///
  /// In sl, this message translates to:
  /// **'Sečnja \"{name}\" označena'**
  String mapTabSecnjaMarked(String name);

  /// No description provided for @mapTabSecnjaMarkError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri označevanju sečnje: {error}'**
  String mapTabSecnjaMarkError(Object error);

  /// No description provided for @mapTabLogAdded.
  ///
  /// In sl, this message translates to:
  /// **'Hlod dodan ({volume} m³)'**
  String mapTabLogAdded(String volume);

  /// No description provided for @mapTabLogAddError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri dodajanju hloda: {error}'**
  String mapTabLogAddError(Object error);

  /// No description provided for @mapTabLocationDeleted.
  ///
  /// In sl, this message translates to:
  /// **'Izbrisano \"{name}\"'**
  String mapTabLocationDeleted(String name);

  /// No description provided for @mapTabLocationDeleteError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri brisanju lokacije: {error}'**
  String mapTabLocationDeleteError(Object error);

  /// No description provided for @mapTabNoCadastreData.
  ///
  /// In sl, this message translates to:
  /// **'Za regijo {region} ni podatkov katastra.'**
  String mapTabNoCadastreData(String region);

  /// No description provided for @mapTabRegionNotInList.
  ///
  /// In sl, this message translates to:
  /// **'Regije {name} ni v seznamu.'**
  String mapTabRegionNotInList(String name);

  /// No description provided for @mapTabRegionDownloaded.
  ///
  /// In sl, this message translates to:
  /// **'{name}: prenesenih {count} parcel.'**
  String mapTabRegionDownloaded(String name, int count);

  /// No description provided for @mapTabDownloadCancelled.
  ///
  /// In sl, this message translates to:
  /// **'Prenos preklican.'**
  String get mapTabDownloadCancelled;

  /// No description provided for @mapTabDownloadFailed.
  ///
  /// In sl, this message translates to:
  /// **'Prenos ni uspel: {error}'**
  String mapTabDownloadFailed(Object error);

  /// No description provided for @mapTabNoParcelAtLocation.
  ///
  /// In sl, this message translates to:
  /// **'Na tej lokaciji ni najdene parcele'**
  String get mapTabNoParcelAtLocation;

  /// No description provided for @mapTabParcelSearchError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri iskanju parcele: {error}'**
  String mapTabParcelSearchError(Object error);

  /// No description provided for @mapTabUnknownOwner.
  ///
  /// In sl, this message translates to:
  /// **'Neznan lastnik'**
  String get mapTabUnknownOwner;

  /// No description provided for @mapTabParcelKo.
  ///
  /// In sl, this message translates to:
  /// **'Parcela {parcela} (KO {ko})'**
  String mapTabParcelKo(String parcela, Object ko);

  /// No description provided for @mapTabOwnerOffline.
  ///
  /// In sl, this message translates to:
  /// **'Lastnik (offline)'**
  String get mapTabOwnerOffline;

  /// No description provided for @mapTabApproximateOffline.
  ///
  /// In sl, this message translates to:
  /// **'≈ približno (brez povezave)'**
  String get mapTabApproximateOffline;

  /// No description provided for @mapTabParcelExistsTitle.
  ///
  /// In sl, this message translates to:
  /// **'Parcela že obstaja'**
  String get mapTabParcelExistsTitle;

  /// No description provided for @mapTabParcelExistsBody.
  ///
  /// In sl, this message translates to:
  /// **'Parcela {ko} - {number} je že v vaših parcelah.'**
  String mapTabParcelExistsBody(Object ko, Object number);

  /// No description provided for @mapTabParcelExistsLabelBody.
  ///
  /// In sl, this message translates to:
  /// **'Parcela {label} je že v vaših parcelah.'**
  String mapTabParcelExistsLabelBody(String label);

  /// No description provided for @mapTabShowInMyParcels.
  ///
  /// In sl, this message translates to:
  /// **'Prikaži v mojih parcelah'**
  String get mapTabShowInMyParcels;

  /// No description provided for @mapTabImportParcelTitle.
  ///
  /// In sl, this message translates to:
  /// **'Uvozi parcelo'**
  String get mapTabImportParcelTitle;

  /// No description provided for @mapTabImportParcelQuestion.
  ///
  /// In sl, this message translates to:
  /// **'Ali želite uvoziti to parcelo v \"Moj gozd\"?'**
  String get mapTabImportParcelQuestion;

  /// No description provided for @mapTabPrint.
  ///
  /// In sl, this message translates to:
  /// **'Natisni'**
  String get mapTabPrint;

  /// No description provided for @mapTabImport.
  ///
  /// In sl, this message translates to:
  /// **'Uvozi'**
  String get mapTabImport;

  /// No description provided for @mapTabPdfOpenFailed.
  ///
  /// In sl, this message translates to:
  /// **'PDF ni mogoče odpreti: {message}'**
  String mapTabPdfOpenFailed(Object message);

  /// No description provided for @mapTabPdfError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri pripravi PDF: {error}'**
  String mapTabPdfError(Object error);

  /// No description provided for @mapTabParcelImported.
  ///
  /// In sl, this message translates to:
  /// **'Parcela {ko} - {number} uspešno uvožena'**
  String mapTabParcelImported(Object ko, Object number);

  /// No description provided for @mapTabParcelImportError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri uvozu parcele: {error}'**
  String mapTabParcelImportError(Object error);

  /// No description provided for @mapTabKmlUnsupported.
  ///
  /// In sl, this message translates to:
  /// **'KML/KMZ uvoz še ni podprt preko karte'**
  String get mapTabKmlUnsupported;

  /// No description provided for @mapTabImportError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri uvozu: {error}'**
  String mapTabImportError(Object error);

  /// No description provided for @mapTabParcelTitle.
  ///
  /// In sl, this message translates to:
  /// **'Parc. {number} • KO {ko}'**
  String mapTabParcelTitle(Object number, Object ko);

  /// No description provided for @mapTabParcelTitleWithKo.
  ///
  /// In sl, this message translates to:
  /// **'Parc. {number} • KO {ko} {koName}'**
  String mapTabParcelTitleWithKo(Object number, Object ko, String koName);

  /// No description provided for @mapTabParcelShort.
  ///
  /// In sl, this message translates to:
  /// **'Parc. {number}'**
  String mapTabParcelShort(Object number);

  /// No description provided for @mapTabSelectedPoint.
  ///
  /// In sl, this message translates to:
  /// **'Izbrana točka'**
  String get mapTabSelectedPoint;

  /// No description provided for @mapTabMejnikiHint.
  ///
  /// In sl, this message translates to:
  /// **'Dolgo pritisnite na parcelo za prikaz mejnikov.'**
  String get mapTabMejnikiHint;

  /// No description provided for @mapTabNoActiveMeasurement.
  ///
  /// In sl, this message translates to:
  /// **'Ni aktivnega merjenja'**
  String get mapTabNoActiveMeasurement;

  /// No description provided for @mapTabHintStart.
  ///
  /// In sl, this message translates to:
  /// **'Dolgo pritisnite na karto za začetek merjenja.'**
  String get mapTabHintStart;

  /// No description provided for @mapTabHintFinished.
  ///
  /// In sl, this message translates to:
  /// **'Merjenje je zaključeno.'**
  String get mapTabHintFinished;

  /// No description provided for @mapTabHintMoveMap.
  ///
  /// In sl, this message translates to:
  /// **'Premaknite karto, da nitni križ kaže na točko, in tapnite »Dodaj točko«.'**
  String get mapTabHintMoveMap;

  /// No description provided for @mapTabHintNextPointDistance.
  ///
  /// In sl, this message translates to:
  /// **'Naslednjo točko dodajte z nitnim križem ali zaključite merjenje.'**
  String get mapTabHintNextPointDistance;

  /// No description provided for @mapTabHintMinPointsArea.
  ///
  /// In sl, this message translates to:
  /// **'Z nitnim križem dodajte vsaj 3 točke za površino.'**
  String get mapTabHintMinPointsArea;

  /// No description provided for @mapTabHintNextPointPolygon.
  ///
  /// In sl, this message translates to:
  /// **'Naslednjo točko dodajte z nitnim križem ali zaključite poligon.'**
  String get mapTabHintNextPointPolygon;

  /// No description provided for @mapTabMeasureArea.
  ///
  /// In sl, this message translates to:
  /// **'Merjenje površine'**
  String get mapTabMeasureArea;

  /// No description provided for @mapTabMeasureDistance.
  ///
  /// In sl, this message translates to:
  /// **'Merjenje razdalje'**
  String get mapTabMeasureDistance;

  /// No description provided for @mapTabAddPoint.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj točko'**
  String get mapTabAddPoint;

  /// No description provided for @mapTabUndo.
  ///
  /// In sl, this message translates to:
  /// **'Razveljavi'**
  String get mapTabUndo;

  /// No description provided for @mapTabFinish.
  ///
  /// In sl, this message translates to:
  /// **'Zaključi'**
  String get mapTabFinish;

  /// No description provided for @mapTabLoadingMap.
  ///
  /// In sl, this message translates to:
  /// **'Nalagam karto...'**
  String get mapTabLoadingMap;

  /// No description provided for @mapTabParcelLabel.
  ///
  /// In sl, this message translates to:
  /// **'Parcela {label}'**
  String mapTabParcelLabel(String label);

  /// No description provided for @mapTabTilesDownloadPercent.
  ///
  /// In sl, this message translates to:
  /// **'Prenos kart {percent}%'**
  String mapTabTilesDownloadPercent(String percent);

  /// No description provided for @mapTabTilesDownloadStats.
  ///
  /// In sl, this message translates to:
  /// **'Preneseno {downloaded}, v predpomnilniku {cached}, napake {failed} / {total}'**
  String mapTabTilesDownloadStats(
    int downloaded,
    int cached,
    int failed,
    int total,
  );

  /// No description provided for @mapTabSearchingParcel.
  ///
  /// In sl, this message translates to:
  /// **'Iskanje parcele...'**
  String get mapTabSearchingParcel;

  /// No description provided for @mapTabRegionDownloading.
  ///
  /// In sl, this message translates to:
  /// **'Prenašam {name}… {mb}/{totMb} MB'**
  String mapTabRegionDownloading(String name, String mb, String totMb);

  /// No description provided for @mapTabParcelImportedSimple.
  ///
  /// In sl, this message translates to:
  /// **'Parcela je bila uvožena'**
  String get mapTabParcelImportedSimple;

  /// No description provided for @mapTabUsageRightsTitle.
  ///
  /// In sl, this message translates to:
  /// **'Pravice uporabe podatkov'**
  String get mapTabUsageRightsTitle;

  /// No description provided for @mapTabUsageGuName.
  ///
  /// In sl, this message translates to:
  /// **'Geodetska uprava RS'**
  String get mapTabUsageGuName;

  /// No description provided for @mapTabUsageGuDesc.
  ///
  /// In sl, this message translates to:
  /// **'Podatki Geodetske uprave Republike Slovenije (ortofoto, kataster, topografske karte) so na voljo pod pogoji odprtih podatkov. Uporaba je dovoljena za nekomercialne in komercialne namene ob navedbi vira.'**
  String get mapTabUsageGuDesc;

  /// No description provided for @mapTabUsageZgsName.
  ///
  /// In sl, this message translates to:
  /// **'Zavod za gozdove Slovenije'**
  String get mapTabUsageZgsName;

  /// No description provided for @mapTabUsageZgsDesc.
  ///
  /// In sl, this message translates to:
  /// **'Gozdarski podatki (gozdne združbe, sestojna karta, rastiščni koeficienti) so javno dostopni. Uporaba je dovoljena za informativne namene. Za komercialno uporabo je potrebno pridobiti dovoljenje ZGS.'**
  String get mapTabUsageZgsDesc;

  /// No description provided for @mapTabUsageOsmDesc.
  ///
  /// In sl, this message translates to:
  /// **'Kartografski podatki OpenStreetMap so na voljo pod licenco Open Database License (ODbL). Uporaba je dovoljena ob navedbi \"© OpenStreetMap contributors\".'**
  String get mapTabUsageOsmDesc;

  /// No description provided for @mapTabUsageEsriDesc.
  ///
  /// In sl, this message translates to:
  /// **'Esri satelitski posnetki so na voljo za osebno in nekomercialno uporabo. Za komercialno uporabo je potrebna licenca.'**
  String get mapTabUsageEsriDesc;

  /// No description provided for @mapTabUsageDisclaimer.
  ///
  /// In sl, this message translates to:
  /// **'Ta aplikacija je namenjena informativni uporabi. Za uradne podatke se obrnite na pristojne institucije.'**
  String get mapTabUsageDisclaimer;

  /// No description provided for @mapTabLocationRenamed.
  ///
  /// In sl, this message translates to:
  /// **'Lokacija preimenovana v \"{newName}\"'**
  String mapTabLocationRenamed(String newName);

  /// No description provided for @mapwAddLocationTitle.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj lokacijo'**
  String get mapwAddLocationTitle;

  /// No description provided for @mapwAddLocationHint.
  ///
  /// In sl, this message translates to:
  /// **'Koordinate iz dolgo-pritiska ali vnesite svoje'**
  String get mapwAddLocationHint;

  /// No description provided for @mapwLatLabel.
  ///
  /// In sl, this message translates to:
  /// **'Zemljepisna širina (Lat)'**
  String get mapwLatLabel;

  /// No description provided for @mapwLngLabel.
  ///
  /// In sl, this message translates to:
  /// **'Zemljepisna dolžina (Lng)'**
  String get mapwLngLabel;

  /// No description provided for @mapwLatExample.
  ///
  /// In sl, this message translates to:
  /// **'npr. 46.0569'**
  String get mapwLatExample;

  /// No description provided for @mapwLngExample.
  ///
  /// In sl, this message translates to:
  /// **'npr. 14.5058'**
  String get mapwLngExample;

  /// No description provided for @mapwEnterLat.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite širino'**
  String get mapwEnterLat;

  /// No description provided for @mapwEnterLng.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite dolžino'**
  String get mapwEnterLng;

  /// No description provided for @mapwInvalidNumber.
  ///
  /// In sl, this message translates to:
  /// **'Neveljavna številka'**
  String get mapwInvalidNumber;

  /// No description provided for @mapwLatRange.
  ///
  /// In sl, this message translates to:
  /// **'Širina mora biti med -90 in 90'**
  String get mapwLatRange;

  /// No description provided for @mapwLngRange.
  ///
  /// In sl, this message translates to:
  /// **'Dolžina mora biti med -180 in 180'**
  String get mapwLngRange;

  /// No description provided for @mapwLatNotInSlovenia.
  ///
  /// In sl, this message translates to:
  /// **'Lokacija ni v Sloveniji ali na Hrvaškem (42.3-46.9)'**
  String get mapwLatNotInSlovenia;

  /// No description provided for @mapwLngNotInSlovenia.
  ///
  /// In sl, this message translates to:
  /// **'Lokacija ni v Sloveniji ali na Hrvaškem (13.3-19.5)'**
  String get mapwLngNotInSlovenia;

  /// No description provided for @mapwLocationNameLabel.
  ///
  /// In sl, this message translates to:
  /// **'Ime lokacije'**
  String get mapwLocationNameLabel;

  /// No description provided for @mapwLocationNameHint.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite ime za to lokacijo'**
  String get mapwLocationNameHint;

  /// No description provided for @mapwEnterName.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite ime'**
  String get mapwEnterName;

  /// No description provided for @mapwMarkFellingTitle.
  ///
  /// In sl, this message translates to:
  /// **'Označi sečnjo'**
  String get mapwMarkFellingTitle;

  /// No description provided for @mapwTreeDescLabel.
  ///
  /// In sl, this message translates to:
  /// **'Opis drevesa'**
  String get mapwTreeDescLabel;

  /// No description provided for @mapwTreeDescHint.
  ///
  /// In sl, this message translates to:
  /// **'npr. Hrast, Bukev, Smreka...'**
  String get mapwTreeDescHint;

  /// No description provided for @mapwEnterDescription.
  ///
  /// In sl, this message translates to:
  /// **'Prosim vnesite opis'**
  String get mapwEnterDescription;

  /// No description provided for @mapwMarkAction.
  ///
  /// In sl, this message translates to:
  /// **'Označi'**
  String get mapwMarkAction;

  /// No description provided for @mapwDeleteLocationTitle.
  ///
  /// In sl, this message translates to:
  /// **'Izbriši lokacijo'**
  String get mapwDeleteLocationTitle;

  /// No description provided for @mapwDeleteLocationSure.
  ///
  /// In sl, this message translates to:
  /// **'Ali ste prepričani, da želite izbrisati \"{name}\"?'**
  String mapwDeleteLocationSure(String name);

  /// No description provided for @mapwAddLocationByCoordsTitle.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj lokacijo s koordinatami'**
  String get mapwAddLocationByCoordsTitle;

  /// No description provided for @mapwEnterWgs84Hint.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite koordinate v WGS84 formatu (decimalne stopinje)'**
  String get mapwEnterWgs84Hint;

  /// No description provided for @mapwRenameLocationTitle.
  ///
  /// In sl, this message translates to:
  /// **'Preimenuj lokacijo'**
  String get mapwRenameLocationTitle;

  /// No description provided for @mapwNameLabel.
  ///
  /// In sl, this message translates to:
  /// **'Ime'**
  String get mapwNameLabel;

  /// No description provided for @mapwParcelTitle.
  ///
  /// In sl, this message translates to:
  /// **'Parcela {number}'**
  String mapwParcelTitle(String number);

  /// No description provided for @mapwCadastralParcel.
  ///
  /// In sl, this message translates to:
  /// **'Katastrska parcela'**
  String get mapwCadastralParcel;

  /// No description provided for @mapwCadastralMunicipality.
  ///
  /// In sl, this message translates to:
  /// **'Katastrska občina'**
  String get mapwCadastralMunicipality;

  /// No description provided for @mapwArea.
  ///
  /// In sl, this message translates to:
  /// **'Površina'**
  String get mapwArea;

  /// No description provided for @mapwOwner.
  ///
  /// In sl, this message translates to:
  /// **'Lastnik'**
  String get mapwOwner;

  /// No description provided for @mapwDeleteLocationQuestion.
  ///
  /// In sl, this message translates to:
  /// **'Ali res želite izbrisati lokacijo \"{name}\"?'**
  String mapwDeleteLocationQuestion(String name);

  /// No description provided for @mapwResetOnboardingTitle.
  ///
  /// In sl, this message translates to:
  /// **'Ponastavi uvodni vodič'**
  String get mapwResetOnboardingTitle;

  /// No description provided for @mapwResetOnboardingBody.
  ///
  /// In sl, this message translates to:
  /// **'Ali res želite ponastaviti uvodni vodič? Ponovno zaženite aplikacijo.'**
  String get mapwResetOnboardingBody;

  /// No description provided for @mapwReset.
  ///
  /// In sl, this message translates to:
  /// **'Ponastavi'**
  String get mapwReset;

  /// No description provided for @mapwMenuMeasure.
  ///
  /// In sl, this message translates to:
  /// **'Merjenje'**
  String get mapwMenuMeasure;

  /// No description provided for @mapwMenuNavigate.
  ///
  /// In sl, this message translates to:
  /// **'Navigiraj'**
  String get mapwMenuNavigate;

  /// No description provided for @mapwMenuParcel.
  ///
  /// In sl, this message translates to:
  /// **'Parcela'**
  String get mapwMenuParcel;

  /// No description provided for @mapwMenuImport.
  ///
  /// In sl, this message translates to:
  /// **'Uvozi'**
  String get mapwMenuImport;

  /// No description provided for @mapwPublicParcel.
  ///
  /// In sl, this message translates to:
  /// **'Javna parcela • {category}'**
  String mapwPublicParcel(String category);

  /// No description provided for @mapwMenuPoint.
  ///
  /// In sl, this message translates to:
  /// **'Točka'**
  String get mapwMenuPoint;

  /// No description provided for @mapwMenuLogs.
  ///
  /// In sl, this message translates to:
  /// **'Hlodovina'**
  String get mapwMenuLogs;

  /// No description provided for @mapwMenuFelling.
  ///
  /// In sl, this message translates to:
  /// **'Sečnja'**
  String get mapwMenuFelling;

  /// No description provided for @mapwMenuDistance.
  ///
  /// In sl, this message translates to:
  /// **'Razdalja'**
  String get mapwMenuDistance;

  /// No description provided for @mapwMenuBoundaries.
  ///
  /// In sl, this message translates to:
  /// **'Mejniki'**
  String get mapwMenuBoundaries;

  /// No description provided for @mapwSelectLayer.
  ///
  /// In sl, this message translates to:
  /// **'Izberi sloj'**
  String get mapwSelectLayer;

  /// No description provided for @mapwSearchParcelByKo.
  ///
  /// In sl, this message translates to:
  /// **'Išči parcelo po KO'**
  String get mapwSearchParcelByKo;

  /// No description provided for @mapwZoomIn.
  ///
  /// In sl, this message translates to:
  /// **'Povečaj karto'**
  String get mapwZoomIn;

  /// No description provided for @mapwZoomOut.
  ///
  /// In sl, this message translates to:
  /// **'Pomanjšaj karto'**
  String get mapwZoomOut;

  /// No description provided for @mapwCenterOnGps.
  ///
  /// In sl, this message translates to:
  /// **'Centriraj na GPS lokacijo'**
  String get mapwCenterOnGps;

  /// No description provided for @mapwSavedLocations.
  ///
  /// In sl, this message translates to:
  /// **'Shranjene lokacije'**
  String get mapwSavedLocations;

  /// No description provided for @mapwLayersTitle.
  ///
  /// In sl, this message translates to:
  /// **'Sloji karte'**
  String get mapwLayersTitle;

  /// No description provided for @mapwTabBase.
  ///
  /// In sl, this message translates to:
  /// **'Podlaga'**
  String get mapwTabBase;

  /// No description provided for @mapwTabOverlays.
  ///
  /// In sl, this message translates to:
  /// **'Prekrivni sloji'**
  String get mapwTabOverlays;

  /// No description provided for @mapwInternationalMaps.
  ///
  /// In sl, this message translates to:
  /// **'Mednarodne karte'**
  String get mapwInternationalMaps;

  /// No description provided for @mapwSlovenianMaps.
  ///
  /// In sl, this message translates to:
  /// **'Slovenske karte'**
  String get mapwSlovenianMaps;

  /// No description provided for @mapwDownloadOffline.
  ///
  /// In sl, this message translates to:
  /// **'Prenesi za delo brez povezave'**
  String get mapwDownloadOffline;

  /// No description provided for @mapwImportGeodata.
  ///
  /// In sl, this message translates to:
  /// **'Uvozi geodatke (KML, KMZ)'**
  String get mapwImportGeodata;

  /// No description provided for @mapwNoResults.
  ///
  /// In sl, this message translates to:
  /// **'Ni rezultatov'**
  String get mapwNoResults;

  /// No description provided for @mapwActiveCount.
  ///
  /// In sl, this message translates to:
  /// **'{count} aktivnih'**
  String mapwActiveCount(int count);

  /// No description provided for @mapwPublicParcels.
  ///
  /// In sl, this message translates to:
  /// **'Javne parcele'**
  String get mapwPublicParcels;

  /// No description provided for @mapwVlakeHint.
  ///
  /// In sl, this message translates to:
  /// **'Vlake (pri večji povečavi)'**
  String get mapwVlakeHint;

  /// No description provided for @mapwAddByCoordinates.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj s koordinatami'**
  String get mapwAddByCoordinates;

  /// No description provided for @mapwSectionPoints.
  ///
  /// In sl, this message translates to:
  /// **'Točke'**
  String get mapwSectionPoints;

  /// No description provided for @mapwNoSavedLocations.
  ///
  /// In sl, this message translates to:
  /// **'Ni shranjenih lokacij'**
  String get mapwNoSavedLocations;

  /// No description provided for @mapwRename.
  ///
  /// In sl, this message translates to:
  /// **'Preimenuj'**
  String get mapwRename;

  /// No description provided for @mapwNavAppOpenFailed.
  ///
  /// In sl, this message translates to:
  /// **'Aplikacije za navigacijo ni bilo mogoče odpreti.'**
  String get mapwNavAppOpenFailed;

  /// No description provided for @mapwGoogleMaps.
  ///
  /// In sl, this message translates to:
  /// **'Google Zemljevidi'**
  String get mapwGoogleMaps;

  /// No description provided for @mapwAppleMaps.
  ///
  /// In sl, this message translates to:
  /// **'Apple Zemljevidi'**
  String get mapwAppleMaps;

  /// No description provided for @mapwRoadNavigation.
  ///
  /// In sl, this message translates to:
  /// **'Navigacija po cesti'**
  String get mapwRoadNavigation;

  /// No description provided for @mapwInAppCompass.
  ///
  /// In sl, this message translates to:
  /// **'Kompas v aplikaciji'**
  String get mapwInAppCompass;

  /// No description provided for @mapwInAppCompassHint.
  ///
  /// In sl, this message translates to:
  /// **'Smer in razdalja do cilja, tudi brez spleta'**
  String get mapwInAppCompassHint;

  /// No description provided for @mapwCopyCoordinates.
  ///
  /// In sl, this message translates to:
  /// **'Kopiraj koordinate'**
  String get mapwCopyCoordinates;

  /// No description provided for @mapwCoordinatesCopied.
  ///
  /// In sl, this message translates to:
  /// **'Koordinate kopirane'**
  String get mapwCoordinatesCopied;

  /// No description provided for @mapwCompassN.
  ///
  /// In sl, this message translates to:
  /// **'S'**
  String get mapwCompassN;

  /// No description provided for @mapwCompassE.
  ///
  /// In sl, this message translates to:
  /// **'V'**
  String get mapwCompassE;

  /// No description provided for @mapwCompassS.
  ///
  /// In sl, this message translates to:
  /// **'J'**
  String get mapwCompassS;

  /// No description provided for @mapwCompassW.
  ///
  /// In sl, this message translates to:
  /// **'Z'**
  String get mapwCompassW;

  /// No description provided for @mapwCompassNE.
  ///
  /// In sl, this message translates to:
  /// **'SV'**
  String get mapwCompassNE;

  /// No description provided for @mapwCompassSE.
  ///
  /// In sl, this message translates to:
  /// **'JV'**
  String get mapwCompassSE;

  /// No description provided for @mapwCompassSW.
  ///
  /// In sl, this message translates to:
  /// **'JZ'**
  String get mapwCompassSW;

  /// No description provided for @mapwCompassNW.
  ///
  /// In sl, this message translates to:
  /// **'SZ'**
  String get mapwCompassNW;

  /// No description provided for @mapwCompassLowAccuracy.
  ///
  /// In sl, this message translates to:
  /// **'Nizka natančnost kompasa (±{degrees}°). Kalibrirajte napravo.'**
  String mapwCompassLowAccuracy(int degrees);

  /// No description provided for @mapwCompassMediumAccuracy.
  ///
  /// In sl, this message translates to:
  /// **'Zmerna natančnost kompasa (±{degrees}°)'**
  String mapwCompassMediumAccuracy(int degrees);

  /// No description provided for @mapwLocationPermissionDenied.
  ///
  /// In sl, this message translates to:
  /// **'Dovoljenje za lokacijo zavrnjeno — razdalja ni na voljo'**
  String get mapwLocationPermissionDenied;

  /// No description provided for @mapwCompass.
  ///
  /// In sl, this message translates to:
  /// **'Kompas'**
  String get mapwCompass;

  /// No description provided for @mapwDistance.
  ///
  /// In sl, this message translates to:
  /// **'Razdalja'**
  String get mapwDistance;

  /// No description provided for @mapwAzimuth.
  ///
  /// In sl, this message translates to:
  /// **'Azimut'**
  String get mapwAzimuth;

  /// No description provided for @mapwDirection.
  ///
  /// In sl, this message translates to:
  /// **'Smer'**
  String get mapwDirection;

  /// No description provided for @mapwTileTemplateUnavailable.
  ///
  /// In sl, this message translates to:
  /// **'URL predloge ni na voljo'**
  String get mapwTileTemplateUnavailable;

  /// No description provided for @mapwDownloadComplete.
  ///
  /// In sl, this message translates to:
  /// **'Prenos končan'**
  String get mapwDownloadComplete;

  /// No description provided for @mapwClearCacheTitle.
  ///
  /// In sl, this message translates to:
  /// **'Počisti predpomnilnik?'**
  String get mapwClearCacheTitle;

  /// No description provided for @mapwClearCacheBody.
  ///
  /// In sl, this message translates to:
  /// **'Vse prenesene ploščice bodo izbrisane. Te operacije ni mogoče razveljaviti.'**
  String get mapwClearCacheBody;

  /// No description provided for @mapwCacheCleared.
  ///
  /// In sl, this message translates to:
  /// **'Predpomnilnik izpraznjen'**
  String get mapwCacheCleared;

  /// No description provided for @mapwSyncing.
  ///
  /// In sl, this message translates to:
  /// **'Sinhroniziram {name}'**
  String mapwSyncing(String name);

  /// No description provided for @mapwSyncDownloaded.
  ///
  /// In sl, this message translates to:
  /// **'Preneseno {done}/{total}'**
  String mapwSyncDownloaded(int done, int total);

  /// No description provided for @mapwSyncFromCache.
  ///
  /// In sl, this message translates to:
  /// **'Iz predpomnilnika {done}/{total}'**
  String mapwSyncFromCache(int done, int total);

  /// No description provided for @mapwSyncDone.
  ///
  /// In sl, this message translates to:
  /// **'Končano! {downloaded} prenesenih, {skipped} iz predpomnilnika, {failed} neuspešnih'**
  String mapwSyncDone(int downloaded, int skipped, int failed);

  /// No description provided for @mapwSyncCancelled.
  ///
  /// In sl, this message translates to:
  /// **'Sinhronizacija preklicana'**
  String get mapwSyncCancelled;

  /// No description provided for @mapwTileSharing.
  ///
  /// In sl, this message translates to:
  /// **'Deljenje ploščic'**
  String get mapwTileSharing;

  /// No description provided for @mapwShareMyTiles.
  ///
  /// In sl, this message translates to:
  /// **'Deli moje ploščice'**
  String get mapwShareMyTiles;

  /// No description provided for @mapwSharingOnHint.
  ///
  /// In sl, this message translates to:
  /// **'Druge naprave lahko prenesejo ploščice s te naprave'**
  String get mapwSharingOnHint;

  /// No description provided for @mapwSharingOffHint.
  ///
  /// In sl, this message translates to:
  /// **'Začni deliti predpomnjene ploščice z bližnjimi napravami'**
  String get mapwSharingOffHint;

  /// No description provided for @mapwMyCachedMaps.
  ///
  /// In sl, this message translates to:
  /// **'Moje predpomnjene karte'**
  String get mapwMyCachedMaps;

  /// No description provided for @mapwTilesAndSize.
  ///
  /// In sl, this message translates to:
  /// **'{tiles} ploščic, {size}'**
  String mapwTilesAndSize(String tiles, String size);

  /// No description provided for @mapwNearbyDevices.
  ///
  /// In sl, this message translates to:
  /// **'Bližnje naprave'**
  String get mapwNearbyDevices;

  /// No description provided for @mapwRefresh.
  ///
  /// In sl, this message translates to:
  /// **'Osveži'**
  String get mapwRefresh;

  /// No description provided for @mapwAddDeviceManually.
  ///
  /// In sl, this message translates to:
  /// **'Ročno dodaj napravo'**
  String get mapwAddDeviceManually;

  /// No description provided for @mapwNoDevicesFound.
  ///
  /// In sl, this message translates to:
  /// **'V lokalnem omrežju ni najdenih naprav.\nPreverite, da imajo druge naprave vključeno deljenje ploščic.'**
  String get mapwNoDevicesFound;

  /// No description provided for @mapwFetchingCatalog.
  ///
  /// In sl, this message translates to:
  /// **'Pridobivam katalog'**
  String get mapwFetchingCatalog;

  /// No description provided for @mapwNoCachedTilesOnDevice.
  ///
  /// In sl, this message translates to:
  /// **'Na tej napravi ni predpomnjenih ploščic'**
  String get mapwNoCachedTilesOnDevice;

  /// No description provided for @mapwYouHave.
  ///
  /// In sl, this message translates to:
  /// **' (imate {count})'**
  String mapwYouHave(String count);

  /// No description provided for @mapwDownloadAll.
  ///
  /// In sl, this message translates to:
  /// **'Prenesi vse'**
  String get mapwDownloadAll;

  /// No description provided for @mapwAddDeviceTitle.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj napravo'**
  String get mapwAddDeviceTitle;

  /// No description provided for @mapwIpAddress.
  ///
  /// In sl, this message translates to:
  /// **'IP naslov'**
  String get mapwIpAddress;

  /// No description provided for @mapwDeleteStyleTitle.
  ///
  /// In sl, this message translates to:
  /// **'Izbriši {name}?'**
  String mapwDeleteStyleTitle(String name);

  /// No description provided for @mapwDeleteStyleBody.
  ///
  /// In sl, this message translates to:
  /// **'{tiles} ploščic, {size} bo izbrisanih.'**
  String mapwDeleteStyleBody(String tiles, String size);

  /// No description provided for @mapwTileDownloadTitle.
  ///
  /// In sl, this message translates to:
  /// **'Prenos kart'**
  String get mapwTileDownloadTitle;

  /// No description provided for @mapwForOfflineWork.
  ///
  /// In sl, this message translates to:
  /// **'Za delo brez povezave'**
  String get mapwForOfflineWork;

  /// No description provided for @mapwSharingEnabled.
  ///
  /// In sl, this message translates to:
  /// **'Deljenje ploščic vključeno'**
  String get mapwSharingEnabled;

  /// No description provided for @mapwSharingDisabled.
  ///
  /// In sl, this message translates to:
  /// **'Deljenje ploščic izklopljeno'**
  String get mapwSharingDisabled;

  /// No description provided for @mapwLayersShort.
  ///
  /// In sl, this message translates to:
  /// **'Sloji'**
  String get mapwLayersShort;

  /// No description provided for @mapwZoomLevel.
  ///
  /// In sl, this message translates to:
  /// **'Povečava'**
  String get mapwZoomLevel;

  /// No description provided for @mapwEstimate.
  ///
  /// In sl, this message translates to:
  /// **'Ocena'**
  String get mapwEstimate;

  /// No description provided for @mapwEstimatedTiles.
  ///
  /// In sl, this message translates to:
  /// **'~{count} ploščic'**
  String mapwEstimatedTiles(int count);

  /// No description provided for @mapwDownloadingPercent.
  ///
  /// In sl, this message translates to:
  /// **'Prenašam... {percent}%'**
  String mapwDownloadingPercent(String percent);

  /// No description provided for @mapwLayerNotDownloadable.
  ///
  /// In sl, this message translates to:
  /// **'Sloj ni na voljo za prenos'**
  String get mapwLayerNotDownloadable;

  /// No description provided for @mapwNoXyzTemplate.
  ///
  /// In sl, this message translates to:
  /// **'Za ta sloj ni bilo mogoče določiti XYZ predloge.'**
  String get mapwNoXyzTemplate;

  /// No description provided for @mapwCache.
  ///
  /// In sl, this message translates to:
  /// **'Predpomnilnik'**
  String get mapwCache;

  /// No description provided for @mapwCacheStats.
  ///
  /// In sl, this message translates to:
  /// **'{tiles} ploščic ({size} MB)'**
  String mapwCacheStats(String tiles, String size);

  /// No description provided for @mapwClearCache.
  ///
  /// In sl, this message translates to:
  /// **'Počisti predpomnilnik'**
  String get mapwClearCache;

  /// No description provided for @mapwParcelAlreadyInDb.
  ///
  /// In sl, this message translates to:
  /// **'Parcela {municipality} - {number} je že v bazi podatkov'**
  String mapwParcelAlreadyInDb(String municipality, String number);

  /// No description provided for @parcelPointUnknown.
  ///
  /// In sl, this message translates to:
  /// **'Točka ?'**
  String get parcelPointUnknown;

  /// No description provided for @parcelPointNumbered.
  ///
  /// In sl, this message translates to:
  /// **'Točka {number}'**
  String parcelPointNumbered(int number);

  /// No description provided for @parcelDetailUpdateError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri posodabljanju: {error}'**
  String parcelDetailUpdateError(String error);

  /// No description provided for @parcelDetailPreparingPdf.
  ///
  /// In sl, this message translates to:
  /// **'Pripravljam PDF …'**
  String get parcelDetailPreparingPdf;

  /// No description provided for @parcelDetailPdfOpenError.
  ///
  /// In sl, this message translates to:
  /// **'PDF ni mogoče odpreti: {message}'**
  String parcelDetailPdfOpenError(String message);

  /// No description provided for @parcelDetailPdfError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri pripravi PDF: {error}'**
  String parcelDetailPdfError(String error);

  /// No description provided for @parcelDetailPreparingExport.
  ///
  /// In sl, this message translates to:
  /// **'Pripravljam izvoz …'**
  String get parcelDetailPreparingExport;

  /// No description provided for @parcelDetailExportDone.
  ///
  /// In sl, this message translates to:
  /// **'Izvoz zaključen'**
  String get parcelDetailExportDone;

  /// No description provided for @parcelDetailExportError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri izvozu: {error}'**
  String parcelDetailExportError(String error);

  /// No description provided for @parcelForestTypeTitle.
  ///
  /// In sl, this message translates to:
  /// **'Vrsta gozda'**
  String get parcelForestTypeTitle;

  /// No description provided for @parcelForestTypeDeciduous.
  ///
  /// In sl, this message translates to:
  /// **'Listavci'**
  String get parcelForestTypeDeciduous;

  /// No description provided for @parcelForestTypeMixed.
  ///
  /// In sl, this message translates to:
  /// **'Mešani gozd'**
  String get parcelForestTypeMixed;

  /// No description provided for @parcelForestTypeConiferous.
  ///
  /// In sl, this message translates to:
  /// **'Iglavci'**
  String get parcelForestTypeConiferous;

  /// No description provided for @parcelOwnerTitle.
  ///
  /// In sl, this message translates to:
  /// **'Lastnik'**
  String get parcelOwnerTitle;

  /// No description provided for @parcelOwnerNameLabel.
  ///
  /// In sl, this message translates to:
  /// **'Ime lastnika'**
  String get parcelOwnerNameLabel;

  /// No description provided for @parcelOwnerNameHint.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite ime lastnika'**
  String get parcelOwnerNameHint;

  /// No description provided for @parcelNotesTitle.
  ///
  /// In sl, this message translates to:
  /// **'Opombe'**
  String get parcelNotesTitle;

  /// No description provided for @parcelAllowanceTitle.
  ///
  /// In sl, this message translates to:
  /// **'Dovoljen posek'**
  String get parcelAllowanceTitle;

  /// No description provided for @parcelAllowanceAmountLabel.
  ///
  /// In sl, this message translates to:
  /// **'Količina (m³)'**
  String get parcelAllowanceAmountLabel;

  /// No description provided for @parcelAllowanceAmountHint.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite dovoljeno količino'**
  String get parcelAllowanceAmountHint;

  /// No description provided for @parcelInvalidNumber.
  ///
  /// In sl, this message translates to:
  /// **'Neveljavna številka'**
  String get parcelInvalidNumber;

  /// No description provided for @parcelLogCutTitle.
  ///
  /// In sl, this message translates to:
  /// **'Zabeleži posek'**
  String get parcelLogCutTitle;

  /// No description provided for @parcelCutCurrent.
  ///
  /// In sl, this message translates to:
  /// **'Trenutno posekano: {volume} m³'**
  String parcelCutCurrent(String volume);

  /// No description provided for @parcelCutRemaining.
  ///
  /// In sl, this message translates to:
  /// **'Še na voljo: {volume} m³'**
  String parcelCutRemaining(String volume);

  /// No description provided for @parcelCutAddLabel.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj posek (m³)'**
  String get parcelCutAddLabel;

  /// No description provided for @parcelCutAddHint.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite količino'**
  String get parcelCutAddHint;

  /// No description provided for @parcelTreesCountLabel.
  ///
  /// In sl, this message translates to:
  /// **'Število dreves'**
  String get parcelTreesCountLabel;

  /// No description provided for @parcelTreesCountHint.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite število'**
  String get parcelTreesCountHint;

  /// No description provided for @parcelTreesUnit.
  ///
  /// In sl, this message translates to:
  /// **'dreves'**
  String get parcelTreesUnit;

  /// No description provided for @parcelCutInvalidAmount.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite veljavno količino poseka'**
  String get parcelCutInvalidAmount;

  /// No description provided for @parcelCutAddedWithTrees.
  ///
  /// In sl, this message translates to:
  /// **'Dodano {volume} m³ poseka ({trees} dreves)'**
  String parcelCutAddedWithTrees(String volume, int trees);

  /// No description provided for @parcelCutAdded.
  ///
  /// In sl, this message translates to:
  /// **'Dodano {volume} m³ poseka'**
  String parcelCutAdded(String volume);

  /// No description provided for @parcelResetCutTitle.
  ///
  /// In sl, this message translates to:
  /// **'Ponastavi posek'**
  String get parcelResetCutTitle;

  /// No description provided for @parcelResetCutMessage.
  ///
  /// In sl, this message translates to:
  /// **'Ali ste prepričani, da želite ponastaviti količino posekanega lesa na 0?'**
  String get parcelResetCutMessage;

  /// No description provided for @parcelReset.
  ///
  /// In sl, this message translates to:
  /// **'Ponastavi'**
  String get parcelReset;

  /// No description provided for @parcelAddTreesTitle.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj posekana drevesa'**
  String get parcelAddTreesTitle;

  /// No description provided for @parcelResetTreesTitle.
  ///
  /// In sl, this message translates to:
  /// **'Ponastavi drevesa'**
  String get parcelResetTreesTitle;

  /// No description provided for @parcelResetTreesMessage.
  ///
  /// In sl, this message translates to:
  /// **'Ali ste prepričani, da želite ponastaviti število posekanih dreves na 0?'**
  String get parcelResetTreesMessage;

  /// No description provided for @parcelDeleteTitle.
  ///
  /// In sl, this message translates to:
  /// **'Izbriši parcelo'**
  String get parcelDeleteTitle;

  /// No description provided for @parcelDeleteMessage.
  ///
  /// In sl, this message translates to:
  /// **'Ali ste prepričani, da želite izbrisati \"{name}\"?\n\nIzbrisane bodo tudi vse točke, sečnje in hlodovina znotraj parcele.'**
  String parcelDeleteMessage(String name);

  /// No description provided for @parcelDeletedLogsExtra.
  ///
  /// In sl, this message translates to:
  /// **'{count} hlodov'**
  String parcelDeletedLogsExtra(int count);

  /// No description provided for @parcelDeletedPointsExtra.
  ///
  /// In sl, this message translates to:
  /// **'{count} točk'**
  String parcelDeletedPointsExtra(int count);

  /// No description provided for @parcelDeleted.
  ///
  /// In sl, this message translates to:
  /// **'Parcela izbrisana'**
  String get parcelDeleted;

  /// No description provided for @parcelDeletedWithExtras.
  ///
  /// In sl, this message translates to:
  /// **'Parcela izbrisana ({extras})'**
  String parcelDeletedWithExtras(String extras);

  /// No description provided for @parcelDeleteError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri brisanju: {error}'**
  String parcelDeleteError(String error);

  /// No description provided for @parcelEditShape.
  ///
  /// In sl, this message translates to:
  /// **'Uredi obliko'**
  String get parcelEditShape;

  /// No description provided for @parcelPrint.
  ///
  /// In sl, this message translates to:
  /// **'Natisni'**
  String get parcelPrint;

  /// No description provided for @parcelExportKml.
  ///
  /// In sl, this message translates to:
  /// **'Izvozi KML'**
  String get parcelExportKml;

  /// No description provided for @parcelViewOnMap.
  ///
  /// In sl, this message translates to:
  /// **'Poglej na karti'**
  String get parcelViewOnMap;

  /// No description provided for @parcelNavigate.
  ///
  /// In sl, this message translates to:
  /// **'Navigiraj'**
  String get parcelNavigate;

  /// No description provided for @parcelEditorNeedThreePoints.
  ///
  /// In sl, this message translates to:
  /// **'Narišite vsaj 3 točke'**
  String get parcelEditorNeedThreePoints;

  /// No description provided for @parcelEditorNameRequired.
  ///
  /// In sl, this message translates to:
  /// **'Prosim vnesite ime'**
  String get parcelEditorNameRequired;

  /// No description provided for @parcelEditorBaseLayer.
  ///
  /// In sl, this message translates to:
  /// **'Osnovni sloj'**
  String get parcelEditorBaseLayer;

  /// No description provided for @parcelEditorOverlayLayers.
  ///
  /// In sl, this message translates to:
  /// **'Prekrivni sloji'**
  String get parcelEditorOverlayLayers;

  /// No description provided for @parcelEditorAddTitle.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj parcelo'**
  String get parcelEditorAddTitle;

  /// No description provided for @parcelEditorEditTitle.
  ///
  /// In sl, this message translates to:
  /// **'Uredi parcelo'**
  String get parcelEditorEditTitle;

  /// No description provided for @parcelEditorNameLabel.
  ///
  /// In sl, this message translates to:
  /// **'Ime parcele'**
  String get parcelEditorNameLabel;

  /// No description provided for @parcelForestTypeMixedShort.
  ///
  /// In sl, this message translates to:
  /// **'Mešani'**
  String get parcelForestTypeMixedShort;

  /// No description provided for @parcelEditorTapToAdd.
  ///
  /// In sl, this message translates to:
  /// **'Tapnite na zemljevid za dodajanje točk ({count} točk)'**
  String parcelEditorTapToAdd(int count);

  /// No description provided for @parcelEditorDrawingDone.
  ///
  /// In sl, this message translates to:
  /// **'Risanje zaključeno'**
  String get parcelEditorDrawingDone;

  /// No description provided for @parcelEditorArea.
  ///
  /// In sl, this message translates to:
  /// **'Površina: {area}'**
  String parcelEditorArea(String area);

  /// No description provided for @parcelEditorClear.
  ///
  /// In sl, this message translates to:
  /// **'Počisti'**
  String get parcelEditorClear;

  /// No description provided for @parcelLogsCardTitle.
  ///
  /// In sl, this message translates to:
  /// **'Hlodovina na parceli ({count})'**
  String parcelLogsCardTitle(int count);

  /// No description provided for @parcelManualEntry.
  ///
  /// In sl, this message translates to:
  /// **'Ročni vnos'**
  String get parcelManualEntry;

  /// No description provided for @parcelLogName.
  ///
  /// In sl, this message translates to:
  /// **'Hlod {id}'**
  String parcelLogName(int id);

  /// No description provided for @parcelMoreLogs.
  ///
  /// In sl, this message translates to:
  /// **'... in še {count} hlodov'**
  String parcelMoreLogs(int count);

  /// No description provided for @parcelSavedPointsTitle.
  ///
  /// In sl, this message translates to:
  /// **'Shranjene točke ({count})'**
  String parcelSavedPointsTitle(int count);

  /// No description provided for @parcelSecnjaTitle.
  ///
  /// In sl, this message translates to:
  /// **'Sečnja ({count})'**
  String parcelSecnjaTitle(int count);

  /// No description provided for @parcelFoundTitle.
  ///
  /// In sl, this message translates to:
  /// **'Parcela {label}'**
  String parcelFoundTitle(String label);

  /// No description provided for @parcelFoundKo.
  ///
  /// In sl, this message translates to:
  /// **'KO {ko}'**
  String parcelFoundKo(String ko);

  /// No description provided for @parcelFoundHide.
  ///
  /// In sl, this message translates to:
  /// **'Skrij'**
  String get parcelFoundHide;

  /// No description provided for @parcelFoundOpen.
  ///
  /// In sl, this message translates to:
  /// **'Odpri parcelo'**
  String get parcelFoundOpen;

  /// No description provided for @parcelFoundImport.
  ///
  /// In sl, this message translates to:
  /// **'Uvozi parcelo'**
  String get parcelFoundImport;

  /// No description provided for @parcelPointsCount.
  ///
  /// In sl, this message translates to:
  /// **'{count} točk'**
  String parcelPointsCount(int count);

  /// No description provided for @parcelInfoAdded.
  ///
  /// In sl, this message translates to:
  /// **'Dodano'**
  String get parcelInfoAdded;

  /// No description provided for @parcelInfoParcel.
  ///
  /// In sl, this message translates to:
  /// **'Parcela'**
  String get parcelInfoParcel;

  /// No description provided for @parcelNotSet.
  ///
  /// In sl, this message translates to:
  /// **'Ni določen'**
  String get parcelNotSet;

  /// No description provided for @parcelFromCadastre.
  ///
  /// In sl, this message translates to:
  /// **'iz katastra (GURS)'**
  String get parcelFromCadastre;

  /// No description provided for @parcelNoNotes.
  ///
  /// In sl, this message translates to:
  /// **'Ni opomb'**
  String get parcelNoNotes;

  /// No description provided for @parcelWoodTitle.
  ///
  /// In sl, this message translates to:
  /// **'Posek lesa'**
  String get parcelWoodTitle;

  /// No description provided for @parcelCutLabel.
  ///
  /// In sl, this message translates to:
  /// **'Posekano'**
  String get parcelCutLabel;

  /// No description provided for @parcelWoodUsed.
  ///
  /// In sl, this message translates to:
  /// **'{percent}% izkoriščeno'**
  String parcelWoodUsed(String percent);

  /// No description provided for @parcelTreesCutLabel.
  ///
  /// In sl, this message translates to:
  /// **'Posekanih dreves'**
  String get parcelTreesCutLabel;

  /// No description provided for @parcelLogCutButton.
  ///
  /// In sl, this message translates to:
  /// **'Posek m³'**
  String get parcelLogCutButton;

  /// No description provided for @parcelTreeButton.
  ///
  /// In sl, this message translates to:
  /// **'Drevo'**
  String get parcelTreeButton;

  /// No description provided for @parcelSearchNotFound.
  ///
  /// In sl, this message translates to:
  /// **'Parcela {number} ni najdena.'**
  String parcelSearchNotFound(String number);

  /// No description provided for @parcelSearchError.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri iskanju: {error}'**
  String parcelSearchError(String error);

  /// No description provided for @parcelSearchTitle.
  ///
  /// In sl, this message translates to:
  /// **'Iskanje parcele'**
  String get parcelSearchTitle;

  /// No description provided for @parcelSearchAllKo.
  ///
  /// In sl, this message translates to:
  /// **'Vse katastrske občine'**
  String get parcelSearchAllKo;

  /// No description provided for @parcelSearchByMapPosition.
  ///
  /// In sl, this message translates to:
  /// **'Po legi na zemljevidu'**
  String get parcelSearchByMapPosition;

  /// No description provided for @parcelSearchRemoveKo.
  ///
  /// In sl, this message translates to:
  /// **'Odstrani katastrsko občino'**
  String get parcelSearchRemoveKo;

  /// No description provided for @parcelSearchHint.
  ///
  /// In sl, this message translates to:
  /// **'Parcela, lastnik, naslov ali k.o.'**
  String get parcelSearchHint;

  /// No description provided for @parcelSearchHelper.
  ///
  /// In sl, this message translates to:
  /// **'npr. 123/4, Novak Babno ali Škofja Loka'**
  String get parcelSearchHelper;

  /// No description provided for @parcelSearchPromptNoKo.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite številko parcele, ime lastnika, naslov ali katastrsko občino.'**
  String get parcelSearchPromptNoKo;

  /// No description provided for @parcelSearchPromptWithKo.
  ///
  /// In sl, this message translates to:
  /// **'Vnesite številko parcele (npr. 123/4), ime lastnika ali naslov.'**
  String get parcelSearchPromptWithKo;

  /// No description provided for @parcelSearchNeedsKoHint.
  ///
  /// In sl, this message translates to:
  /// **'Za parcelo {number} izberite katastrsko občino: vnesite njeno ime.'**
  String parcelSearchNeedsKoHint(String number);

  /// No description provided for @parcelSearchNoResults.
  ///
  /// In sl, this message translates to:
  /// **'Ni zadetkov.'**
  String get parcelSearchNoResults;

  /// No description provided for @parcelSearchNeedsKo.
  ///
  /// In sl, this message translates to:
  /// **'Za parcelo {number} izberite katastrsko občino.'**
  String parcelSearchNeedsKo(String number);

  /// No description provided for @parcelMapPreviewLabel.
  ///
  /// In sl, this message translates to:
  /// **'Karta'**
  String get parcelMapPreviewLabel;

  /// No description provided for @parcelPdfKo.
  ///
  /// In sl, this message translates to:
  /// **'Katastrska občina'**
  String get parcelPdfKo;

  /// No description provided for @parcelPdfNumber.
  ///
  /// In sl, this message translates to:
  /// **'Parcelna številka'**
  String get parcelPdfNumber;

  /// No description provided for @parcelPdfArea.
  ///
  /// In sl, this message translates to:
  /// **'Površina'**
  String get parcelPdfArea;

  /// No description provided for @parcelPdfAddress.
  ///
  /// In sl, this message translates to:
  /// **'Naslov'**
  String get parcelPdfAddress;

  /// No description provided for @parcelPdfMunicipality.
  ///
  /// In sl, this message translates to:
  /// **'Občina'**
  String get parcelPdfMunicipality;

  /// No description provided for @parcelPdfMapFailed.
  ///
  /// In sl, this message translates to:
  /// **'Zemljevida ni bilo mogoče naložiti'**
  String get parcelPdfMapFailed;

  /// No description provided for @parcelPdfFooter.
  ///
  /// In sl, this message translates to:
  /// **'Gozdar • Izpisano: {date}'**
  String parcelPdfFooter(String date);

  /// No description provided for @parcelPdfSource.
  ///
  /// In sl, this message translates to:
  /// **'Vir: © GURS, © ZGS'**
  String get parcelPdfSource;

  /// No description provided for @parcelSearchKoSubtitle.
  ///
  /// In sl, this message translates to:
  /// **'Katastrska občina {sifko}'**
  String parcelSearchKoSubtitle(int sifko);

  /// No description provided for @svcKmlExportSubject.
  ///
  /// In sl, this message translates to:
  /// **'Gozdar Parcels Export'**
  String get svcKmlExportSubject;

  /// No description provided for @svcKmlExportText.
  ///
  /// In sl, this message translates to:
  /// **'Exported {count} parcels'**
  String svcKmlExportText(int count);

  /// No description provided for @svcKmlParcelShareSubject.
  ///
  /// In sl, this message translates to:
  /// **'Parcela {name}'**
  String svcKmlParcelShareSubject(String name);

  /// No description provided for @svcKmlParcelShareText.
  ///
  /// In sl, this message translates to:
  /// **'Izvoz parcele {name} z {logs} hlodi, {fellings} sečnjami in {points} točkami'**
  String svcKmlParcelShareText(String name, int logs, int fellings, int points);

  /// No description provided for @svcDownloadFailedHttp.
  ///
  /// In sl, this message translates to:
  /// **'Prenos ni uspel (HTTP {status}).'**
  String svcDownloadFailedHttp(int status);

  /// No description provided for @svcParcelDisplayName.
  ///
  /// In sl, this message translates to:
  /// **'Parcela {number} (KO {ko})'**
  String svcParcelDisplayName(String number, int ko);

  /// No description provided for @svcParcelDisplayNameRef.
  ///
  /// In sl, this message translates to:
  /// **'Parcela {label} ({ref})'**
  String svcParcelDisplayNameRef(String label, String ref);

  /// No description provided for @svcLayerParcel.
  ///
  /// In sl, this message translates to:
  /// **'Parcela'**
  String get svcLayerParcel;

  /// No description provided for @svcLayerStand.
  ///
  /// In sl, this message translates to:
  /// **'Sestoj'**
  String get svcLayerStand;

  /// No description provided for @svcLayerSection.
  ///
  /// In sl, this message translates to:
  /// **'Odsek'**
  String get svcLayerSection;

  /// No description provided for @svcLayerDistrict.
  ///
  /// In sl, this message translates to:
  /// **'Revir'**
  String get svcLayerDistrict;

  /// No description provided for @svcLayerGge.
  ///
  /// In sl, this message translates to:
  /// **'GGE'**
  String get svcLayerGge;

  /// No description provided for @svcLayerGgo.
  ///
  /// In sl, this message translates to:
  /// **'GGO'**
  String get svcLayerGgo;

  /// No description provided for @svcLayerForestReserve.
  ///
  /// In sl, this message translates to:
  /// **'Gozdni rezervat'**
  String get svcLayerForestReserve;

  /// No description provided for @svcLayerProtectiveForest.
  ///
  /// In sl, this message translates to:
  /// **'Varovalni gozd'**
  String get svcLayerProtectiveForest;

  /// No description provided for @svcLayerProtectedArea.
  ///
  /// In sl, this message translates to:
  /// **'Zavarovano območje'**
  String get svcLayerProtectedArea;

  /// No description provided for @svcLayerNaturalValue.
  ///
  /// In sl, this message translates to:
  /// **'Naravna vrednota'**
  String get svcLayerNaturalValue;

  /// No description provided for @svcLayerEpo.
  ///
  /// In sl, this message translates to:
  /// **'EPO'**
  String get svcLayerEpo;

  /// No description provided for @svcLayerHuntingGround.
  ///
  /// In sl, this message translates to:
  /// **'Lovišče'**
  String get svcLayerHuntingGround;

  /// No description provided for @svcLayerFireRisk.
  ///
  /// In sl, this message translates to:
  /// **'Požarna ogroženost'**
  String get svcLayerFireRisk;

  /// No description provided for @svcLayerMunicipality.
  ///
  /// In sl, this message translates to:
  /// **'Občina'**
  String get svcLayerMunicipality;

  /// No description provided for @svcLayerCadastralMunicipality.
  ///
  /// In sl, this message translates to:
  /// **'Katastrska občina'**
  String get svcLayerCadastralMunicipality;

  /// No description provided for @svcAesBadFormat.
  ///
  /// In sl, this message translates to:
  /// **'Datoteka ni v pričakovani obliki (napačna glava).'**
  String get svcAesBadFormat;

  /// No description provided for @svcAesCorrupt.
  ///
  /// In sl, this message translates to:
  /// **'Datoteka je okvarjena ali nepopolna.'**
  String get svcAesCorrupt;

  /// No description provided for @svcAesWrongPassword.
  ///
  /// In sl, this message translates to:
  /// **'Napačno geslo.'**
  String get svcAesWrongPassword;

  /// No description provided for @svcNetTimeout.
  ///
  /// In sl, this message translates to:
  /// **'Povezava je potekla. Prosimo, poskusite znova.'**
  String get svcNetTimeout;

  /// No description provided for @svcNetNoConnection.
  ///
  /// In sl, this message translates to:
  /// **'Ni internetne povezave. Preverite omrežje.'**
  String get svcNetNoConnection;

  /// No description provided for @svcNetServerError.
  ///
  /// In sl, this message translates to:
  /// **'Strežnik ni dosegljiv. Poskusite pozneje.'**
  String get svcNetServerError;

  /// No description provided for @svcNetUnknown.
  ///
  /// In sl, this message translates to:
  /// **'Prišlo je do napake. Poskusite znova.'**
  String get svcNetUnknown;

  /// No description provided for @aboutTitle.
  ///
  /// In sl, this message translates to:
  /// **'O aplikaciji'**
  String get aboutTitle;

  /// No description provided for @aboutSectionMapSources.
  ///
  /// In sl, this message translates to:
  /// **'Viri kartografskih podatkov'**
  String get aboutSectionMapSources;

  /// No description provided for @aboutSectionLegal.
  ///
  /// In sl, this message translates to:
  /// **'Pravne informacije'**
  String get aboutSectionLegal;

  /// No description provided for @aboutSectionOpenSource.
  ///
  /// In sl, this message translates to:
  /// **'Odprtokodne knjižnice'**
  String get aboutSectionOpenSource;

  /// No description provided for @aboutSectionSupport.
  ///
  /// In sl, this message translates to:
  /// **'Podpora'**
  String get aboutSectionSupport;

  /// No description provided for @aboutTagline.
  ///
  /// In sl, this message translates to:
  /// **'Aplikacija za lastnike gozdov in gozdarske delavce v Sloveniji'**
  String get aboutTagline;

  /// No description provided for @aboutInfoTitle.
  ///
  /// In sl, this message translates to:
  /// **'Informacije o aplikaciji'**
  String get aboutInfoTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In sl, this message translates to:
  /// **'Verzija'**
  String get aboutVersion;

  /// No description provided for @aboutBuildNumber.
  ///
  /// In sl, this message translates to:
  /// **'Številka gradnje'**
  String get aboutBuildNumber;

  /// No description provided for @aboutPackage.
  ///
  /// In sl, this message translates to:
  /// **'Paket'**
  String get aboutPackage;

  /// No description provided for @aboutDeveloperOptions.
  ///
  /// In sl, this message translates to:
  /// **'Razvijalske moznosti'**
  String get aboutDeveloperOptions;

  /// No description provided for @aboutOwnersDb.
  ///
  /// In sl, this message translates to:
  /// **'Baza lastnikov (kataster)'**
  String get aboutOwnersDb;

  /// No description provided for @aboutNotImported.
  ///
  /// In sl, this message translates to:
  /// **'Ni uvozena.'**
  String get aboutNotImported;

  /// No description provided for @aboutOwnersCount.
  ///
  /// In sl, this message translates to:
  /// **'{count} lastnikov{size}'**
  String aboutOwnersCount(String count, String size);

  /// No description provided for @aboutOwnersDownloading.
  ///
  /// In sl, this message translates to:
  /// **'Prenašam bazo lastnikov…'**
  String get aboutOwnersDownloading;

  /// No description provided for @aboutOwnersUpdateButton.
  ///
  /// In sl, this message translates to:
  /// **'Posodobi (~300 MB)'**
  String get aboutOwnersUpdateButton;

  /// No description provided for @aboutOwnersDownloadButton.
  ///
  /// In sl, this message translates to:
  /// **'Prenesi (~300 MB)'**
  String get aboutOwnersDownloadButton;

  /// No description provided for @aboutImportFromFile.
  ///
  /// In sl, this message translates to:
  /// **'Uvozi iz datoteke (.sqlite)'**
  String get aboutImportFromFile;

  /// No description provided for @aboutRemove.
  ///
  /// In sl, this message translates to:
  /// **'Odstrani'**
  String get aboutRemove;

  /// No description provided for @aboutOfflineOwnerSearch.
  ///
  /// In sl, this message translates to:
  /// **'Iskanje lastnika brez povezave'**
  String get aboutOfflineOwnerSearch;

  /// No description provided for @aboutOfflineOwnerSearchDesc.
  ///
  /// In sl, this message translates to:
  /// **'Ko ni povezave, določi lastnika iz približnih mej parcel (lokalna baza).'**
  String get aboutOfflineOwnerSearchDesc;

  /// No description provided for @aboutVlake.
  ///
  /// In sl, this message translates to:
  /// **'Vlake (gozdne vlake)'**
  String get aboutVlake;

  /// No description provided for @aboutVlakeDesc.
  ///
  /// In sl, this message translates to:
  /// **'Omogoči sloj — prikaže se v izbiri slojev (Infrastruktura)'**
  String get aboutVlakeDesc;

  /// No description provided for @aboutHttpCache.
  ///
  /// In sl, this message translates to:
  /// **'Predpomnilnik HTTP'**
  String get aboutHttpCache;

  /// No description provided for @aboutHttpCacheDesc.
  ///
  /// In sl, this message translates to:
  /// **'Predpomni odgovore državnih API-jev (prostor.zgs.gov.si).'**
  String get aboutHttpCacheDesc;

  /// No description provided for @aboutTileCache.
  ///
  /// In sl, this message translates to:
  /// **'Predpomnilnik ploščic'**
  String get aboutTileCache;

  /// No description provided for @aboutTileCacheDesc.
  ///
  /// In sl, this message translates to:
  /// **'Predpomni karte (ločeno od HTTP predpomnilnika).'**
  String get aboutTileCacheDesc;

  /// No description provided for @aboutClearMapCache.
  ///
  /// In sl, this message translates to:
  /// **'Počisti predpomnilnik karte'**
  String get aboutClearMapCache;

  /// No description provided for @aboutPickSqlite.
  ///
  /// In sl, this message translates to:
  /// **'Izberi datoteko .sqlite.'**
  String get aboutPickSqlite;

  /// No description provided for @aboutOwnersImported.
  ///
  /// In sl, this message translates to:
  /// **'Uvozenih {count} lastnikov.'**
  String aboutOwnersImported(String count);

  /// No description provided for @aboutImportFailed.
  ///
  /// In sl, this message translates to:
  /// **'Uvoz ni uspel: {error}'**
  String aboutImportFailed(String error);

  /// No description provided for @aboutOwnersRemoved.
  ///
  /// In sl, this message translates to:
  /// **'Baza lastnikov odstranjena.'**
  String get aboutOwnersRemoved;

  /// No description provided for @aboutClearCacheTitle.
  ///
  /// In sl, this message translates to:
  /// **'Počisti predpomnilnik karte?'**
  String get aboutClearCacheTitle;

  /// No description provided for @aboutClearCacheBody.
  ///
  /// In sl, this message translates to:
  /// **'Izbrisane bodo vse shranjene karte, tudi tiste, prenesene za delo brez povezave. Brez signala jih ne bo mogoče prikazati, dokler jih znova ne prenesete.'**
  String get aboutClearCacheBody;

  /// No description provided for @aboutCacheCleared.
  ///
  /// In sl, this message translates to:
  /// **'Predpomnilnik karte počiščen.'**
  String get aboutCacheCleared;

  /// No description provided for @aboutCacheClearFailed.
  ///
  /// In sl, this message translates to:
  /// **'Brisanje predpomnilnika ni uspelo: {error}'**
  String aboutCacheClearFailed(String error);

  /// No description provided for @aboutOfflineKataster.
  ///
  /// In sl, this message translates to:
  /// **'Offline kataster (parcele)'**
  String get aboutOfflineKataster;

  /// No description provided for @aboutKatasterNotLoaded.
  ///
  /// In sl, this message translates to:
  /// **'Ni naložena — kataster se prikazuje prek spleta.'**
  String get aboutKatasterNotLoaded;

  /// No description provided for @aboutParcelsSummary.
  ///
  /// In sl, this message translates to:
  /// **'{regions}{count} parcel{size}{date} • brez spleta'**
  String aboutParcelsSummary(
    String regions,
    String count,
    String size,
    String date,
  );

  /// No description provided for @aboutAddRegion.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj regijo'**
  String get aboutAddRegion;

  /// No description provided for @aboutDownloadRegion.
  ///
  /// In sl, this message translates to:
  /// **'Prenesi regijo'**
  String get aboutDownloadRegion;

  /// No description provided for @aboutDownloadRegionHint.
  ///
  /// In sl, this message translates to:
  /// **'Prenesi le svojo statistično regijo — priporočena povezava Wi-Fi.'**
  String get aboutDownloadRegionHint;

  /// No description provided for @aboutShareKataster.
  ///
  /// In sl, this message translates to:
  /// **'Deli offline kataster'**
  String get aboutShareKataster;

  /// No description provided for @aboutShareKatasterActive.
  ///
  /// In sl, this message translates to:
  /// **'Na voljo v lokalnem omrežju • najdenih naprav: {count}'**
  String aboutShareKatasterActive(int count);

  /// No description provided for @aboutShareKatasterDesc.
  ///
  /// In sl, this message translates to:
  /// **'Dovoli drugim napravam v istem omrežju prenos naloženih regij.'**
  String get aboutShareKatasterDesc;

  /// No description provided for @aboutPublicOwners.
  ///
  /// In sl, this message translates to:
  /// **'javni lastniki'**
  String get aboutPublicOwners;

  /// No description provided for @aboutKatasterUpdateAvailable.
  ///
  /// In sl, this message translates to:
  /// **'Na voljo je novejši kataster ({date})'**
  String aboutKatasterUpdateAvailable(String date);

  /// No description provided for @aboutKatasterOutdated.
  ///
  /// In sl, this message translates to:
  /// **'Zastarelo: {parts}{size}'**
  String aboutKatasterOutdated(String parts, String size);

  /// No description provided for @updateLater.
  ///
  /// In sl, this message translates to:
  /// **'Pozneje'**
  String get updateLater;

  /// No description provided for @updateNow.
  ///
  /// In sl, this message translates to:
  /// **'Posodobi'**
  String get updateNow;

  /// No description provided for @aboutPublicOwnersLabel.
  ///
  /// In sl, this message translates to:
  /// **'Javni lastniki…'**
  String get aboutPublicOwnersLabel;

  /// No description provided for @aboutPublicOwnersFailed.
  ///
  /// In sl, this message translates to:
  /// **'Prenos javnih lastnikov ni uspel.'**
  String get aboutPublicOwnersFailed;

  /// No description provided for @aboutErrorWithDetail.
  ///
  /// In sl, this message translates to:
  /// **'Napaka: {error}'**
  String aboutErrorWithDetail(String error);

  /// No description provided for @aboutPickRegionsTitle.
  ///
  /// In sl, this message translates to:
  /// **'Izberi statistične regije'**
  String get aboutPickRegionsTitle;

  /// No description provided for @aboutRegionParcels.
  ///
  /// In sl, this message translates to:
  /// **' • {count} parcel'**
  String aboutRegionParcels(String count);

  /// No description provided for @aboutRegionLoaded.
  ///
  /// In sl, this message translates to:
  /// **' • naloženo'**
  String get aboutRegionLoaded;

  /// No description provided for @aboutDownloadSelected.
  ///
  /// In sl, this message translates to:
  /// **'Prenesi {count} (~{mb} MB)'**
  String aboutDownloadSelected(int count, String mb);

  /// No description provided for @aboutRegionProgress.
  ///
  /// In sl, this message translates to:
  /// **'{name} ({index}/{total})…'**
  String aboutRegionProgress(String name, int index, int total);

  /// No description provided for @aboutRegionsDownloaded.
  ///
  /// In sl, this message translates to:
  /// **'Prenesenih regij: {count}.'**
  String aboutRegionsDownloaded(int count);

  /// No description provided for @aboutRegionsFailed.
  ///
  /// In sl, this message translates to:
  /// **' Neuspešno: {names}.'**
  String aboutRegionsFailed(String names);

  /// No description provided for @aboutPasswordLabel.
  ///
  /// In sl, this message translates to:
  /// **'Geslo'**
  String get aboutPasswordLabel;

  /// No description provided for @aboutUnlock.
  ///
  /// In sl, this message translates to:
  /// **'Odkleni'**
  String get aboutUnlock;

  /// No description provided for @aboutOwnersPasswordTitle.
  ///
  /// In sl, this message translates to:
  /// **'Geslo za bazo lastnikov'**
  String get aboutOwnersPasswordTitle;

  /// No description provided for @aboutOwnersDownloaded.
  ///
  /// In sl, this message translates to:
  /// **'Prenesenih {count} lastnikov.'**
  String aboutOwnersDownloaded(String count);

  /// No description provided for @aboutDownloadCancelled.
  ///
  /// In sl, this message translates to:
  /// **'Prenos preklican.'**
  String get aboutDownloadCancelled;

  /// No description provided for @aboutDownloadFailed.
  ///
  /// In sl, this message translates to:
  /// **'Prenos ni uspel: {error}'**
  String aboutDownloadFailed(String error);

  /// No description provided for @aboutParcelsImported.
  ///
  /// In sl, this message translates to:
  /// **'Uvoženih {count} parcel.'**
  String aboutParcelsImported(String count);

  /// No description provided for @aboutParcelsRemoved.
  ///
  /// In sl, this message translates to:
  /// **'Baze parcel odstranjene.'**
  String get aboutParcelsRemoved;

  /// No description provided for @aboutWipeSection.
  ///
  /// In sl, this message translates to:
  /// **'Pobriši podatke (baze parcel + lastnikov)'**
  String get aboutWipeSection;

  /// No description provided for @aboutWipeImported.
  ///
  /// In sl, this message translates to:
  /// **'Uvožene'**
  String get aboutWipeImported;

  /// No description provided for @aboutWipeDownloaded.
  ///
  /// In sl, this message translates to:
  /// **'Prenesene'**
  String get aboutWipeDownloaded;

  /// No description provided for @aboutWipeAll.
  ///
  /// In sl, this message translates to:
  /// **'Vse'**
  String get aboutWipeAll;

  /// No description provided for @aboutWipeScopeAll.
  ///
  /// In sl, this message translates to:
  /// **'vse baze'**
  String get aboutWipeScopeAll;

  /// No description provided for @aboutWipeScopeImported.
  ///
  /// In sl, this message translates to:
  /// **'uvožene baze'**
  String get aboutWipeScopeImported;

  /// No description provided for @aboutWipeScopeDownloaded.
  ///
  /// In sl, this message translates to:
  /// **'prenesene baze'**
  String get aboutWipeScopeDownloaded;

  /// No description provided for @aboutWipeTitle.
  ///
  /// In sl, this message translates to:
  /// **'Pobriši podatke'**
  String get aboutWipeTitle;

  /// No description provided for @aboutWipeConfirm.
  ///
  /// In sl, this message translates to:
  /// **'Ali res želiš pobrisati {scope}? Tega ni mogoče razveljaviti.'**
  String aboutWipeConfirm(String scope);

  /// No description provided for @aboutWipeButton.
  ///
  /// In sl, this message translates to:
  /// **'Pobriši'**
  String get aboutWipeButton;

  /// No description provided for @aboutWipeNone.
  ///
  /// In sl, this message translates to:
  /// **'Ni ustreznih baz za brisanje.'**
  String get aboutWipeNone;

  /// No description provided for @aboutWipeDone.
  ///
  /// In sl, this message translates to:
  /// **'Pobrisanih baz: {count}.'**
  String aboutWipeDone(int count);

  /// No description provided for @aboutSrcZgsDesc.
  ///
  /// In sl, this message translates to:
  /// **'Gozdarski sloji, sestoji, odseki, revirji, gozdni rezervati, varovalni gozdovi, požarna ogroženost, vetrolomi, podlubniki'**
  String get aboutSrcZgsDesc;

  /// No description provided for @aboutSrcGursDesc.
  ///
  /// In sl, this message translates to:
  /// **'Ortofoto posnetki (2022-2024), kataster, katastrske občine, občine, upravne enote, DMR'**
  String get aboutSrcGursDesc;

  /// No description provided for @aboutSrcOsmDesc.
  ///
  /// In sl, this message translates to:
  /// **'Osnovni zemljevid in topografski podatki'**
  String get aboutSrcOsmDesc;

  /// No description provided for @aboutSrcTopoDesc.
  ///
  /// In sl, this message translates to:
  /// **'Topografski zemljevid (Seznam.cz)'**
  String get aboutSrcTopoDesc;

  /// No description provided for @aboutSrcEsriDesc.
  ///
  /// In sl, this message translates to:
  /// **'Satelitski posnetki in topografski zemljevid'**
  String get aboutSrcEsriDesc;

  /// No description provided for @aboutTermsTitle.
  ///
  /// In sl, this message translates to:
  /// **'Pogoji uporabe'**
  String get aboutTermsTitle;

  /// No description provided for @aboutDisclaimerTitle.
  ///
  /// In sl, this message translates to:
  /// **'Omejitev odgovornosti'**
  String get aboutDisclaimerTitle;

  /// No description provided for @aboutCopyrightTitle.
  ///
  /// In sl, this message translates to:
  /// **'Avtorske pravice'**
  String get aboutCopyrightTitle;

  /// No description provided for @aboutPrivacyTitle.
  ///
  /// In sl, this message translates to:
  /// **'Zasebnost'**
  String get aboutPrivacyTitle;

  /// No description provided for @aboutTermsBody.
  ///
  /// In sl, this message translates to:
  /// **'Aplikacija Gozdar je namenjena izključno informativnim namenom. Podatki o parcelah, gozdnih sestojih in drugih kartografskih slojih so povzeti iz javno dostopnih virov in morda niso posodobljeni ali popolnoma točni.'**
  String get aboutTermsBody;

  /// No description provided for @aboutDisclaimerBody.
  ///
  /// In sl, this message translates to:
  /// **'Razvijalec ne prevzema odgovornosti za morebitno škodo, ki bi nastala zaradi uporabe aplikacije ali podatkov v njej. Za uradne podatke o lastništvu in mejah parcel se obrnite na pristojne organe (GURS, ZGS).'**
  String get aboutDisclaimerBody;

  /// No description provided for @aboutCopyrightBody.
  ///
  /// In sl, this message translates to:
  /// **'Kartografski podatki ZGS in GURS so last Republike Slovenije. OpenStreetMap podatki so na voljo pod licenco ODbL. ESRI podatki so last Esri Inc.'**
  String get aboutCopyrightBody;

  /// No description provided for @aboutPrivacyBody.
  ///
  /// In sl, this message translates to:
  /// **'Aplikacija zbira anonimne podatke o uporabi za izboljšanje delovanja (Firebase Analytics). Lokacijski podatki se ne pošiljajo na strežnik - vsi podatki o parcelah in hlodih se hranijo lokalno na napravi.'**
  String get aboutPrivacyBody;

  /// No description provided for @aboutShowLicenses.
  ///
  /// In sl, this message translates to:
  /// **'Prikaži licence'**
  String get aboutShowLicenses;

  /// No description provided for @aboutLicensesDesc.
  ///
  /// In sl, this message translates to:
  /// **'Flutter in odprtokodne knjižnice'**
  String get aboutLicensesDesc;

  /// No description provided for @aboutReportBug.
  ///
  /// In sl, this message translates to:
  /// **'Prijavi napako'**
  String get aboutReportBug;

  /// No description provided for @aboutContact.
  ///
  /// In sl, this message translates to:
  /// **'Kontakt'**
  String get aboutContact;

  /// No description provided for @aboutContactDesc.
  ///
  /// In sl, this message translates to:
  /// **'Pošljite povratne informacije'**
  String get aboutContactDesc;

  /// No description provided for @aboutSourceCode.
  ///
  /// In sl, this message translates to:
  /// **'Izvorna koda'**
  String get aboutSourceCode;

  /// No description provided for @aboutSourceCodeDesc.
  ///
  /// In sl, this message translates to:
  /// **'Odprtokodni projekt na GitHub'**
  String get aboutSourceCodeDesc;

  /// No description provided for @aboutLanguage.
  ///
  /// In sl, this message translates to:
  /// **'Jezik'**
  String get aboutLanguage;

  /// No description provided for @aboutLanguageAuto.
  ///
  /// In sl, this message translates to:
  /// **'Samodejno'**
  String get aboutLanguageAuto;

  /// No description provided for @aboutDownloadingRegion.
  ///
  /// In sl, this message translates to:
  /// **'Prenašam regijo…'**
  String get aboutDownloadingRegion;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In sl, this message translates to:
  /// **'Nova posodobitev na voljo'**
  String get updateAvailableTitle;

  /// No description provided for @updateVersion.
  ///
  /// In sl, this message translates to:
  /// **'Verzija {version}'**
  String updateVersion(String version);

  /// No description provided for @updateDownloading.
  ///
  /// In sl, this message translates to:
  /// **'Prenašanje posodobitve...'**
  String get updateDownloading;

  /// No description provided for @updateReadyTitle.
  ///
  /// In sl, this message translates to:
  /// **'Posodobitev pripravljena'**
  String get updateReadyTitle;

  /// No description provided for @updateReadyHint.
  ///
  /// In sl, this message translates to:
  /// **'Tapni za namestitev'**
  String get updateReadyHint;

  /// No description provided for @updateInstall.
  ///
  /// In sl, this message translates to:
  /// **'Namesti'**
  String get updateInstall;

  /// No description provided for @updateErrorTitle.
  ///
  /// In sl, this message translates to:
  /// **'Napaka pri posodobitvi'**
  String get updateErrorTitle;

  /// No description provided for @updateRetry.
  ///
  /// In sl, this message translates to:
  /// **'Ponovi'**
  String get updateRetry;

  /// No description provided for @updateKatasterBanner.
  ///
  /// In sl, this message translates to:
  /// **'Na voljo je novejši kataster ({date}{size}).'**
  String updateKatasterBanner(String date, String size);

  /// No description provided for @updateErrorAlreadyRunning.
  ///
  /// In sl, this message translates to:
  /// **'Prenos že poteka'**
  String get updateErrorAlreadyRunning;

  /// No description provided for @updateErrorPermission.
  ///
  /// In sl, this message translates to:
  /// **'Dovoljenje za namestitev je zavrnjeno'**
  String get updateErrorPermission;

  /// No description provided for @updateErrorInternal.
  ///
  /// In sl, this message translates to:
  /// **'Notranja napaka'**
  String get updateErrorInternal;

  /// No description provided for @updateErrorDownload.
  ///
  /// In sl, this message translates to:
  /// **'Prenos ni uspel'**
  String get updateErrorDownload;

  /// No description provided for @updateErrorChecksum.
  ///
  /// In sl, this message translates to:
  /// **'Preverjanje kontrolne vsote ni uspelo'**
  String get updateErrorChecksum;

  /// No description provided for @updateErrorInstall.
  ///
  /// In sl, this message translates to:
  /// **'Namestitev ni uspela'**
  String get updateErrorInstall;

  /// No description provided for @navTabMap.
  ///
  /// In sl, this message translates to:
  /// **'Karta'**
  String get navTabMap;

  /// No description provided for @navTabForest.
  ///
  /// In sl, this message translates to:
  /// **'Gozd'**
  String get navTabForest;

  /// No description provided for @navTabLogs.
  ///
  /// In sl, this message translates to:
  /// **'Hlodi'**
  String get navTabLogs;

  /// No description provided for @navTabSemantic.
  ///
  /// In sl, this message translates to:
  /// **'Tab {name}'**
  String navTabSemantic(String name);

  /// No description provided for @navOnboardingReset.
  ///
  /// In sl, this message translates to:
  /// **'Uvodni vodič ponastavljen. Ponovno zaženi aplikacijo.'**
  String get navOnboardingReset;

  /// No description provided for @introSkip.
  ///
  /// In sl, this message translates to:
  /// **'Preskoči'**
  String get introSkip;

  /// No description provided for @introStart.
  ///
  /// In sl, this message translates to:
  /// **'Začni'**
  String get introStart;

  /// No description provided for @introWelcomeTitle.
  ///
  /// In sl, this message translates to:
  /// **'Dobrodošli v Gozdar'**
  String get introWelcomeTitle;

  /// No description provided for @introWelcomeBody.
  ///
  /// In sl, this message translates to:
  /// **'Aplikacija za lastnike gozdov in gozdarske delavce v Sloveniji.\n\nSledite poseku, belezite hlodovino in uporabljajte GPS za delo na terenu.'**
  String get introWelcomeBody;

  /// No description provided for @introNavTitle.
  ///
  /// In sl, this message translates to:
  /// **'Navigacija'**
  String get introNavTitle;

  /// No description provided for @introNavMapDesc.
  ///
  /// In sl, this message translates to:
  /// **'Interaktivni zemljevid z vašimi parcelami'**
  String get introNavMapDesc;

  /// No description provided for @introNavForestDesc.
  ///
  /// In sl, this message translates to:
  /// **'Seznam parcel in iskanje v katastru'**
  String get introNavForestDesc;

  /// No description provided for @introNavLogsDesc.
  ///
  /// In sl, this message translates to:
  /// **'Beleženje hlodovine z izračunom volumna'**
  String get introNavLogsDesc;

  /// No description provided for @introLogsTitle.
  ///
  /// In sl, this message translates to:
  /// **'Beleženje hlodovine'**
  String get introLogsTitle;

  /// No description provided for @introLogsDiameter.
  ///
  /// In sl, this message translates to:
  /// **'Premer: 45 cm'**
  String get introLogsDiameter;

  /// No description provided for @introLogsLength.
  ///
  /// In sl, this message translates to:
  /// **'Dolžina: 4.5 m'**
  String get introLogsLength;

  /// No description provided for @introLogsVolume.
  ///
  /// In sl, this message translates to:
  /// **'Volumen: 0.716 m³'**
  String get introLogsVolume;

  /// No description provided for @introLogsSpecies.
  ///
  /// In sl, this message translates to:
  /// **'Drevesne vrste'**
  String get introLogsSpecies;

  /// No description provided for @introLogsSpeciesDesc.
  ///
  /// In sl, this message translates to:
  /// **'Beležite vrsto lesa (Smreka, Bukev, Jelka, ...)'**
  String get introLogsSpeciesDesc;

  /// No description provided for @introLogsAutoCalc.
  ///
  /// In sl, this message translates to:
  /// **'Samodejni izračun'**
  String get introLogsAutoCalc;

  /// No description provided for @introLogsAutoCalcDesc.
  ///
  /// In sl, this message translates to:
  /// **'Aplikacija izračuna volumen iz premera in dolžine'**
  String get introLogsAutoCalcDesc;

  /// No description provided for @introLogsGrouping.
  ///
  /// In sl, this message translates to:
  /// **'Razvrščanje'**
  String get introLogsGrouping;

  /// No description provided for @introLogsGroupingDesc.
  ///
  /// In sl, this message translates to:
  /// **'Hlodi se samodejno razvrstijo po vrstah'**
  String get introLogsGroupingDesc;

  /// No description provided for @introLogsManage.
  ///
  /// In sl, this message translates to:
  /// **'Upravljanje vrst'**
  String get introLogsManage;

  /// No description provided for @introLogsManageDesc.
  ///
  /// In sl, this message translates to:
  /// **'Dodajte ali odstranite vrste v meniju ⋮'**
  String get introLogsManageDesc;

  /// No description provided for @introLongPressTitle.
  ///
  /// In sl, this message translates to:
  /// **'Dolg pritisk na karti'**
  String get introLongPressTitle;

  /// No description provided for @introLongPressAddPoint.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj točko'**
  String get introLongPressAddPoint;

  /// No description provided for @introLongPressAddPointDesc.
  ///
  /// In sl, this message translates to:
  /// **'Shrani lokacijo (mejnik, skladišče)'**
  String get introLongPressAddPointDesc;

  /// No description provided for @introLongPressAddLogs.
  ///
  /// In sl, this message translates to:
  /// **'Dodaj hlodovino'**
  String get introLongPressAddLogs;

  /// No description provided for @introLongPressAddLogsDesc.
  ///
  /// In sl, this message translates to:
  /// **'Beleženje hloda z GPS koordinatami'**
  String get introLongPressAddLogsDesc;

  /// No description provided for @introLongPressMarkCut.
  ///
  /// In sl, this message translates to:
  /// **'Označi sečnjo'**
  String get introLongPressMarkCut;

  /// No description provided for @introLongPressMarkCutDesc.
  ///
  /// In sl, this message translates to:
  /// **'Označi drevo za posek na karti'**
  String get introLongPressMarkCutDesc;

  /// No description provided for @introLongPressImport.
  ///
  /// In sl, this message translates to:
  /// **'Uvozi parcelo'**
  String get introLongPressImport;

  /// No description provided for @introLongPressImportDesc.
  ///
  /// In sl, this message translates to:
  /// **'Pridobi parcelo iz katastra na trenutni lokaciji'**
  String get introLongPressImportDesc;

  /// No description provided for @introLongPressHint.
  ///
  /// In sl, this message translates to:
  /// **'Držite prst na karti za prikaz menija'**
  String get introLongPressHint;

  /// No description provided for @introMarkersTitle.
  ///
  /// In sl, this message translates to:
  /// **'Označbe na karti'**
  String get introMarkersTitle;

  /// No description provided for @introMarkerPoint.
  ///
  /// In sl, this message translates to:
  /// **'Točka'**
  String get introMarkerPoint;

  /// No description provided for @introMarkerLog.
  ///
  /// In sl, this message translates to:
  /// **'Hlod'**
  String get introMarkerLog;

  /// No description provided for @introMarkerCut.
  ///
  /// In sl, this message translates to:
  /// **'Sečnja'**
  String get introMarkerCut;

  /// No description provided for @introMarkersRed.
  ///
  /// In sl, this message translates to:
  /// **'Rdeče'**
  String get introMarkersRed;

  /// No description provided for @introMarkersRedDesc.
  ///
  /// In sl, this message translates to:
  /// **'Shranjene lokacije (mejniki, skladišča)'**
  String get introMarkersRedDesc;

  /// No description provided for @introMarkersBrown.
  ///
  /// In sl, this message translates to:
  /// **'Rjave'**
  String get introMarkersBrown;

  /// No description provided for @introMarkersBrownDesc.
  ///
  /// In sl, this message translates to:
  /// **'Hlodovina z GPS lokacijo'**
  String get introMarkersBrownDesc;

  /// No description provided for @introMarkersOrange.
  ///
  /// In sl, this message translates to:
  /// **'Oranžne'**
  String get introMarkersOrange;

  /// No description provided for @introMarkersOrangeDesc.
  ///
  /// In sl, this message translates to:
  /// **'Drevesa označena za sečnjo'**
  String get introMarkersOrangeDesc;

  /// No description provided for @introMarkersLinked.
  ///
  /// In sl, this message translates to:
  /// **'Hlodi in sečnje se samodejno povežejo s parcelo'**
  String get introMarkersLinked;

  /// No description provided for @introLayersTitle.
  ///
  /// In sl, this message translates to:
  /// **'Sloji na karti'**
  String get introLayersTitle;

  /// No description provided for @introLayersButtonHint.
  ///
  /// In sl, this message translates to:
  /// **'Pritisnite za izbiro slojev'**
  String get introLayersButtonHint;

  /// No description provided for @introLayersOrthoDesc.
  ///
  /// In sl, this message translates to:
  /// **'Satelitski posnetki Slovenije'**
  String get introLayersOrthoDesc;

  /// No description provided for @introLayersCadastreDesc.
  ///
  /// In sl, this message translates to:
  /// **'Meje parcel iz katastra'**
  String get introLayersCadastreDesc;

  /// No description provided for @introLayersStands.
  ///
  /// In sl, this message translates to:
  /// **'Gozdni sestoji'**
  String get introLayersStands;

  /// No description provided for @introLayersStandsDesc.
  ///
  /// In sl, this message translates to:
  /// **'Podatki Zavoda za gozdove'**
  String get introLayersStandsDesc;

  /// No description provided for @introLayersTopo.
  ///
  /// In sl, this message translates to:
  /// **'Topografija'**
  String get introLayersTopo;

  /// No description provided for @introLayersTopoDesc.
  ///
  /// In sl, this message translates to:
  /// **'DTK in druge karte'**
  String get introLayersTopoDesc;

  /// No description provided for @introOfflineTitle.
  ///
  /// In sl, this message translates to:
  /// **'Delo brez povezave'**
  String get introOfflineTitle;

  /// No description provided for @introOfflineAutoCache.
  ///
  /// In sl, this message translates to:
  /// **'Samodejno predpomnjenje'**
  String get introOfflineAutoCache;

  /// No description provided for @introOfflineAutoCacheDesc.
  ///
  /// In sl, this message translates to:
  /// **'Ogledane karte se shranijo za kasnejšo uporabo'**
  String get introOfflineAutoCacheDesc;

  /// No description provided for @introOfflineOnSearch.
  ///
  /// In sl, this message translates to:
  /// **'Ob iskanju parcele'**
  String get introOfflineOnSearch;

  /// No description provided for @introOfflineOnSearchDesc.
  ///
  /// In sl, this message translates to:
  /// **'Karte za območje parcele se prenesejo samodejno'**
  String get introOfflineOnSearchDesc;

  /// No description provided for @introOfflineManual.
  ///
  /// In sl, this message translates to:
  /// **'Ročni prenos'**
  String get introOfflineManual;

  /// No description provided for @introOfflineManualDesc.
  ///
  /// In sl, this message translates to:
  /// **'Uporabite gumb za sloje na karti za prenos območja'**
  String get introOfflineManualDesc;

  /// No description provided for @introOfflineHint.
  ///
  /// In sl, this message translates to:
  /// **'Karte delujejo tudi v gozdu brez signala!'**
  String get introOfflineHint;

  /// No description provided for @introCompassTitle.
  ///
  /// In sl, this message translates to:
  /// **'Navigacija do mejnika'**
  String get introCompassTitle;

  /// No description provided for @introCompassMarker.
  ///
  /// In sl, this message translates to:
  /// **'Mejnik 1 • 45m'**
  String get introCompassMarker;

  /// No description provided for @introCompassStep1.
  ///
  /// In sl, this message translates to:
  /// **'Odprite parcelo'**
  String get introCompassStep1;

  /// No description provided for @introCompassStep1Desc.
  ///
  /// In sl, this message translates to:
  /// **'V zavihku Gozd izberite parcelo'**
  String get introCompassStep1Desc;

  /// No description provided for @introCompassStep2.
  ///
  /// In sl, this message translates to:
  /// **'Tapnite mejno točko'**
  String get introCompassStep2;

  /// No description provided for @introCompassStep2Desc.
  ///
  /// In sl, this message translates to:
  /// **'Izberite točko na karti parcele'**
  String get introCompassStep2Desc;

  /// No description provided for @introCompassStep3.
  ///
  /// In sl, this message translates to:
  /// **'Aktivirajte kompas'**
  String get introCompassStep3;

  /// No description provided for @introCompassStep3Desc.
  ///
  /// In sl, this message translates to:
  /// **'Tapnite oranžni navigacijski trak'**
  String get introCompassStep3Desc;

  /// No description provided for @introCompassStep4.
  ///
  /// In sl, this message translates to:
  /// **'Sledite smeri'**
  String get introCompassStep4;

  /// No description provided for @introCompassStep4Desc.
  ///
  /// In sl, this message translates to:
  /// **'Kompas kaže smer in razdaljo do točke'**
  String get introCompassStep4Desc;

  /// No description provided for @introTermsTitle.
  ///
  /// In sl, this message translates to:
  /// **'Pogoji uporabe'**
  String get introTermsTitle;

  /// No description provided for @introTermsBody.
  ///
  /// In sl, this message translates to:
  /// **'Aplikacija uporablja javne podatke Zavoda za gozdove Slovenije.\n\nZ uporabo te aplikacije se strinjate s pogoji uporabe podatkov:\n\n'**
  String get introTermsBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['hr', 'sl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'hr':
      return AppLocalizationsHr();
    case 'sl':
      return AppLocalizationsSl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
