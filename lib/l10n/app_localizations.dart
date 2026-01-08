import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_be.dart';
import 'app_localizations_bg.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_bs.dart';
import 'app_localizations_cs.dart';
import 'app_localizations_da.dart';
import 'app_localizations_de.dart';
import 'app_localizations_el.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_hr.dart';
import 'app_localizations_is.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_jv.dart';
import 'app_localizations_ka.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_mk.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_no.dart';
import 'app_localizations_pa.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ro.dart';
import 'app_localizations_sk.dart';
import 'app_localizations_sq.dart';
import 'app_localizations_sv.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_uk.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ar'),
    Locale('be'),
    Locale('bg'),
    Locale('bn'),
    Locale('bs'),
    Locale('cs'),
    Locale('da'),
    Locale('de'),
    Locale('el'),
    Locale('en'),
    Locale('es'),
    Locale('fi'),
    Locale('fr'),
    Locale('hi'),
    Locale('hr'),
    Locale('is'),
    Locale('it'),
    Locale('ja'),
    Locale('jv'),
    Locale('ka'),
    Locale('ko'),
    Locale('mk'),
    Locale('nl'),
    Locale('no'),
    Locale('pa'),
    Locale('pl'),
    Locale('pt'),
    Locale('ro'),
    Locale('sk'),
    Locale('sq'),
    Locale('sv'),
    Locale('ta'),
    Locale('tr'),
    Locale('uk'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// App name shown in title bar and widget
  ///
  /// In en, this message translates to:
  /// **'Meteogram'**
  String get appTitle;

  /// Label for temperature data on chart
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// Label for precipitation data on chart
  ///
  /// In en, this message translates to:
  /// **'Precipitation'**
  String get precipitation;

  /// Label for cloud cover data
  ///
  /// In en, this message translates to:
  /// **'Cloud cover'**
  String get cloudCover;

  /// Label for current time indicator on chart
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// Shows when weather data was last refreshed
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAt(String time);

  /// Time elapsed in minutes
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// Shown when data was updated less than a minute ago
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// Button to manually refresh weather data
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Location settings label
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// Option to use GPS location
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get currentLocation;

  /// Option to set location manually
  ///
  /// In en, this message translates to:
  /// **'Set manually'**
  String get setManually;

  /// Error shown when network is unavailable
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNoConnection;

  /// Error when GPS/location cannot be determined
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get errorLocationUnavailable;

  /// Generic error when API request fails
  ///
  /// In en, this message translates to:
  /// **'Could not load weather data'**
  String get errorLoadingData;

  /// Button to retry failed operation
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Watermark shown on chart when displaying cached data
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get offline;

  /// Label showing forecast duration
  ///
  /// In en, this message translates to:
  /// **'{hours}-Hour Forecast'**
  String forecastHours(int hours);

  /// Maximum precipitation in forecast
  ///
  /// In en, this message translates to:
  /// **'Max {amount}'**
  String maxPrecipitation(String amount);

  /// Maximum sunshine in forecast
  ///
  /// In en, this message translates to:
  /// **'Max {percent}%'**
  String maxSunshine(int percent);

  /// Precipitation rate shown on chart
  ///
  /// In en, this message translates to:
  /// **'{amount} mm/h'**
  String precipitationRate(String amount);

  /// Short label for GPS location source
  ///
  /// In en, this message translates to:
  /// **'GPS'**
  String get locationSourceGps;

  /// Short label for manually set location
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get locationSourceManual;

  /// Legend label for sunshine/daylight bars on chart
  ///
  /// In en, this message translates to:
  /// **'Daylight'**
  String get daylight;

  /// Attribution text for weather data provider with license
  ///
  /// In en, this message translates to:
  /// **'Weather data by {provider} (CC BY 4.0)'**
  String weatherDataBy(String provider);

  /// Note indicating daylight values are calculated from cloud data (CC BY 4.0 modification disclosure)
  ///
  /// In en, this message translates to:
  /// **'Daylight derived'**
  String get daylightDerived;

  /// Snackbar message when refresh fails but cached data is available
  ///
  /// In en, this message translates to:
  /// **'Unable to refresh - showing cached data'**
  String get offlineRefreshError;

  /// Loading indicator text while fetching weather data
  ///
  /// In en, this message translates to:
  /// **'Loading weather...'**
  String get loadingWeather;

  /// Error message when weather data cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Unable to load weather'**
  String get unableToLoadWeather;

  /// Fallback text when location name is not available
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownLocation;

  /// Snackbar message when GPS permission is denied
  ///
  /// In en, this message translates to:
  /// **'GPS permission denied. Enable in device settings.'**
  String get gpsPermissionDenied;

  /// Error message when city search fails due to network
  ///
  /// In en, this message translates to:
  /// **'Unable to search - check your connection'**
  String get searchConnectionError;

  /// Title for location selection dialog
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get selectLocation;

  /// Placeholder text in city search field
  ///
  /// In en, this message translates to:
  /// **'Search city...'**
  String get searchCityHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'be',
    'bg',
    'bn',
    'bs',
    'cs',
    'da',
    'de',
    'el',
    'en',
    'es',
    'fi',
    'fr',
    'hi',
    'hr',
    'is',
    'it',
    'ja',
    'jv',
    'ka',
    'ko',
    'mk',
    'nl',
    'no',
    'pa',
    'pl',
    'pt',
    'ro',
    'sk',
    'sq',
    'sv',
    'ta',
    'tr',
    'uk',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'be':
      return AppLocalizationsBe();
    case 'bg':
      return AppLocalizationsBg();
    case 'bn':
      return AppLocalizationsBn();
    case 'bs':
      return AppLocalizationsBs();
    case 'cs':
      return AppLocalizationsCs();
    case 'da':
      return AppLocalizationsDa();
    case 'de':
      return AppLocalizationsDe();
    case 'el':
      return AppLocalizationsEl();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fi':
      return AppLocalizationsFi();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'hr':
      return AppLocalizationsHr();
    case 'is':
      return AppLocalizationsIs();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'jv':
      return AppLocalizationsJv();
    case 'ka':
      return AppLocalizationsKa();
    case 'ko':
      return AppLocalizationsKo();
    case 'mk':
      return AppLocalizationsMk();
    case 'nl':
      return AppLocalizationsNl();
    case 'no':
      return AppLocalizationsNo();
    case 'pa':
      return AppLocalizationsPa();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ro':
      return AppLocalizationsRo();
    case 'sk':
      return AppLocalizationsSk();
    case 'sq':
      return AppLocalizationsSq();
    case 'sv':
      return AppLocalizationsSv();
    case 'ta':
      return AppLocalizationsTa();
    case 'tr':
      return AppLocalizationsTr();
    case 'uk':
      return AppLocalizationsUk();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
