// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Modern Greek (`el`).
class AppLocalizationsEl extends AppLocalizations {
  AppLocalizationsEl([String locale = 'el']) : super(locale);

  @override
  String get appTitle => 'Μετεωρόγραμμα';

  @override
  String get temperature => 'Θερμοκρασία';

  @override
  String get precipitation => 'Βροχόπτωση';

  @override
  String get cloudCover => 'Νεφοκάλυψη';

  @override
  String get now => 'Τώρα';

  @override
  String updatedAt(String time) {
    return 'Ενημερώθηκε $time';
  }

  @override
  String minutesAgo(int count) {
    return '$count λεπτά πριν';
  }

  @override
  String get justNow => 'Μόλις τώρα';

  @override
  String get refresh => 'Ανανέωση';

  @override
  String get settings => 'Ρυθμίσεις';

  @override
  String get location => 'Τοποθεσία';

  @override
  String get currentLocation => 'Τρέχουσα τοποθεσία';

  @override
  String get setManually => 'Χειροκίνητη ρύθμιση';

  @override
  String get errorNoConnection => 'Χωρίς σύνδεση στο διαδίκτυο';

  @override
  String get errorLocationUnavailable => 'Τοποθεσία μη διαθέσιμη';

  @override
  String get errorLoadingData => 'Αδυναμία φόρτωσης δεδομένων καιρού';

  @override
  String get retry => 'Επανάληψη';

  @override
  String get offline => 'ΕΚΤΟΣ ΣΥΝΔΕΣΗΣ';

  @override
  String forecastHours(int hours) {
    return 'Πρόβλεψη $hours ωρών';
  }

  @override
  String maxPrecipitation(String amount) {
    return 'Μέγ. $amount';
  }

  @override
  String maxSunshine(int percent) {
    return 'Μέγ. $percent%';
  }

  @override
  String precipitationRate(String amount) {
    return '$amount mm/ώρα';
  }

  @override
  String get locationSourceGps => 'GPS';

  @override
  String get locationSourceManual => 'Χειροκίνητα';

  @override
  String get daylight => 'Φως ημέρας';

  @override
  String weatherDataBy(String provider) {
    return 'Δεδομένα καιρού από $provider (CC BY 4.0)';
  }

  @override
  String get daylightDerived => 'Φως ημέρας υπολογισμένο';
}
