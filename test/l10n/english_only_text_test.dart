import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/auth/phone_country.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/content/driver_text_l10n.dart';
import 'package:movera/core/contracts/category_name_text.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/cancel_reasons.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_l10n.dart';
import 'package:movera/core/waybill/waybill.dart';

import 'literal_scanner.dart';

/// Owner 2026-10-28: no English-only text on screen. Every string literal
/// in lib/ that reads as words must come from the translations (the ARB
/// files), or be one of the values below, each with the reason it is not
/// translated where it is written. The second half checks the stored
/// English values are translated where they are shown.

/// Files that hold data, not app text: the demo dispatch (it plays the
/// server), admin's published defaults (what the home shows of them is
/// translated: demandText, dayWord), bank names, onboarding documents
/// (written in English, Swedish and French there), the local data
/// inventory (not shown), the country list and the admin text defaults
/// (both checked below), and the demo history seed.
const _dataFiles = {
  'lib/core/dispatch/demo_dispatch_repository.dart',
  'lib/core/admin/driver_home_admin_content.dart',
  'lib/core/money/bank_account.dart',
  'lib/core/contracts/driver_onboarding_rules.dart',
  'lib/core/privacy/local_data.dart',
  'lib/core/auth/phone_country_list.dart',
  'lib/core/content/driver_app_texts.dart',
  'lib/core/history/trip_history.dart',
};

const _allowed = <String, Set<String>>{
  'names: brands, languages in their own name, places, demo riders, '
      'demo cars and a font': {
    'Movera',
    'Movera Driver',
    'Movera Radar',
    'Movera XL',
    'Movera Pet',
    'Premium',
    'Apple Pay',
    'Google Pay',
    'Apple',
    'Google',
    'English',
    'Français',
    'Svenska',
    'Urbanist',
    'Movera .',
    'Mercedes-Benz',
    'Toyota',
    'Mark X',
    'PNG, JPG, PDF',
    'Stockholm',
    'Stockholm City',
    'Södermalm',
    'Södermalm, Stockholm',
    'Solna centrum',
    'Solna centrum, Solna',
    'Solna Torg, Solna',
    'Bromma Airport',
    'Flygplatsinfarten, Bromma',
    'Stockholm Central',
    'Centralplan 15, Stockholm',
    'Kista centrum',
    'Kista Galleria, Stockholm',
    'Södertälje centrum',
    'Storgatan, Södertälje',
    'Arlanda Airport',
    'Stockholm Arlanda Airport',
    'Odlarvägen 22',
    'Enhörna',
    'T-Centralen, Stockholm',
    'Vasagatan 10, Stockholm',
    'Kungsgatan 42, Stockholm',
    'Hornstull, Stockholm',
    'Odengatan 63, Stockholm',
    '1141 central park, DHA',
    'Angelica',
    'Maya',
    'Nils',
    'Maja',
    'Lars',
    'Sofia',
    'Adam',
    'Ella',
    'Karl',
    'Noor',
  },
  'stored or sent in English, translated where shown (checked below)': {
    'Comfort', 'Priority', 'Electric', 'Booster Seat', 'Comfort · 21:42',
    'Cash', 'Card', 'Wallet', 'Black', 'This week',
    // Waybill status, source and stand-ins (WaybillRecord.*Text).
    'Current trip', 'Next trip secured', 'Completed', 'Exclusive offer',
    'Local demo', 'Demo Radar', 'Exclusive reservation', 'Scheduled ride',
    'Assigned by Movera', 'Reservation assigned by Movera',
    'Demo driver — identity unavailable', 'Rider data unavailable',
    'Vehicle data unavailable', 'Plate unavailable', 'Unavailable',
    'Cancelled by rider', 'Cancelled by driver', 'Cancelled by Movera',
    'Cancelled by driver · reassigned', 'Rider no-show', 'Expired', 'Failed',
    // Support categories (supportCategoryLabel) and a draft's status.
    'Trip & rider', 'Wallet & payments', 'Scheduled rides',
    'Account & documents', 'Technical issue', 'Something else',
    'LOCAL DRAFT',
    // Waiting rules (WaitingTerms._shown).
    'Pickup far away', 'Airport pickup', 'Event pickup',
    // Exclusive offer reasons (by id).
    'Best match', "Rider's favourite", 'Finishing nearby', 'Airport queue',
    'Pickup soon', 'Only for you · nearby',
    // Weekday names read from a reservation's day.
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
    // Ride check triggers, topics, questions and answers (ride_check_l10n).
    'Finished far from drop-off', 'Long stop', 'Off the route',
    'Possible crash', 'Accident or collision', 'Accident',
    'Someone is hurt or feels ill', 'Someone hurt', 'I feel unsafe',
    'Unsafe', 'Car problem', 'The rider asked for a stop', 'Rider stop',
    'Traffic or road works', 'Traffic', 'The rider asked to stop here',
    'The rider changed destination', 'New destination',
    'Road closed or no access', 'Road closed',
    'The rider asked for another route', 'Other route', 'Yes', 'No',
    'Not sure', 'Is anyone hurt?', 'Is the car in a safe place?',
    'Is the other person OK?', 'Who needs help?', 'The rider',
    'Someone else', 'Are you in danger right now?',
    'Can you continue the trip?', 'Ride check', 'Opened', 'Did not open',
    'Call 112', 'What happened',
  },
  'never shown: the rider app\'s signal words, developer text, formats': {
    "I'm on the way",
    'Bearer',
    'Request failed.',
    'no identity token',
    'Precise location is turned off.',
    'Location permission is blocked in device settings.',
    'Location permission was denied.',
    'Trip storage unavailable:',
    '+ {body.substring(dial.length + 1)}',
    'min · km',
    'km · min',
  },
};

/// A caught error put on screen as it is (`Text('$e')`, `e.toString()`).
final _rawError = RegExp(
  r'''(?<![\w.])(Text|TextWidget|SnackBar)\([^;]*(\$\{?(e|error|err|exception)\b(?!\.message)|\b(e|error|err|exception)\.toString\(\))''',
);

/// Labels that are the same word in that language.
const _sameWord = {
  'fr': {'shortText accident'},
};

void main() {
  // The sources, read once as data.
  final sources = <String, String>{
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart') &&
          !file.path.contains('/l10n/app_localizations') &&
          !file.path.endsWith('.g.dart'))
        file.path.replaceAll(r'\', '/'): file.readAsStringSync(),
  };
  final allowed = {for (final group in _allowed.values) ...group};

  test('every word in lib/ comes from the translations', () {
    final found = <String>[
      for (final entry in sources.entries)
        if (!_dataFiles.contains(entry.key))
          for (final literal in englishCandidates(entry.value))
            if (!allowed.contains(_words(literal.text)) &&
                !_cancelDefaults.contains(_words(literal.text)))
              '${entry.key}:${literal.line}: ${_words(literal.text)}',
    ];
    expect(sources.length, greaterThan(300));
    expect(
      found,
      isEmpty,
      reason:
          'English-only text: move it into lib/l10n/app_*.arb (en, fr, sv) '
          'or, when it is not shown, add it to _allowed with the reason.',
    );
  });

  test('no caught error is shown as it is', () {
    final found = <String>[
      for (final entry in sources.entries)
        for (final (i, line) in entry.value.split('\n').indexed)
          if (_rawError.hasMatch(line)) '${entry.key}:${i + 1}: $line',
    ];
    expect(found, isEmpty);
  });

  test('the scanner finds text and skips code', () {
    expect(
      englishCandidates("final a = Text('Hello there');").single.text,
      'Hello there',
    );
    expect(englishCandidates("DriverLog.info('Trip step failed');"), isEmpty);
    expect(englishCandidates("throw StateError('Not a ride');"), isEmpty);
    expect(_rawError.hasMatch("Text('\$error')"), isTrue);
  });

  group('stored English is translated where shown', () {
    tearDown(() => DriverAppTexts.language = 'en');

    for (final code in ['fr', 'sv']) {
      test('$code: country names', () {
        final missing = [
          for (final country in PhoneCountries.all)
            if ((code == 'fr' ? country.fr : country.sv) == null) country.iso,
        ];
        expect(missing, isEmpty);
      });

      test('$code: admin text defaults have the app\'s own text', () {
        DriverAppTexts.language = code;
        final missing = [
          for (final key in DriverTexts.all)
            if (driverTextTemplate(tr, key.id) == null) key.id,
        ];
        expect(missing, isEmpty);
      });

      test('$code: labels the app keeps in English', () {
        DriverAppTexts.language = 'en';
        final inEnglish = _shownLabels();
        DriverAppTexts.language = code;
        final shown = _shownLabels();
        expect(shown.keys, inEnglish.keys);
        final untranslated = [
          for (final key in shown.keys)
            if (shown[key] == inEnglish[key] &&
                !(_sameWord[code]?.contains(key) ?? false))
              key,
        ];
        expect(untranslated, isEmpty);
      });
    }
  });
}

/// The English default cancel reasons (each shown by code, checked below).
final Set<String> _cancelDefaults = {
  for (final group in CancelReasonGroup.values)
    for (final reason in const CancelReasons(language: '').groups[group]!) ...[
      reason.title,
      reason.subtitle,
    ],
  const CancelReasons().noShow.title,
  const CancelReasons().noShow.subtitle,
};

/// The labels the app stores in English, as the current language shows
/// them.
Map<String, String> _shownLabels() {
  final reasons = const CancelReasons(language: '');
  WaybillRecord record(String status, String source) => WaybillRecord(
    tripId: 't',
    statusLabel: status,
    issuedAt: DateTime(2026),
    fare: '1 kr',
    service: 'Comfort',
    riderName: WaybillRecord.riderUnavailable,
    pickup: 'a',
    dropoff: 'b',
    source: source,
    driverName: WaybillRecord.unavailable,
    vehicle: WaybillRecord.unavailable,
    licensePlate: WaybillRecord.unavailable,
    passengerCapacity: 0,
  );
  return {
    for (final name in ['Comfort', 'Priority', 'Electric', 'Booster Seat'])
      'category $name': categoryNameText(name),
    for (final group in CancelReasonGroup.values)
      for (final reason in reasons.of(group)) ...{
        'cancel ${reason.code}': reason.title,
        if (reason.subtitle.isNotEmpty)
          'cancel detail ${reason.code}': reason.subtitle,
      },
    for (final trigger in RideCheckTrigger.values)
      'trigger ${trigger.name}': trigger.text,
    for (final topic in RideCheckTopic.values) ...{
      'topic ${topic.name}': topic.text,
      'shortText ${topic.name}': topic.shortText,
      for (final question in topic.questions) ...{
        'question ${question.text}': question.shown,
        for (final option in question.options)
          'option $option': RideCheckQuestionText.option(option),
      },
    },
    for (final (status, source) in [
      (WaybillRecord.currentTrip, WaybillRecord.exclusiveOfferSource),
      (WaybillRecord.completed, WaybillRecord.localDemoSource),
      ('Cancelled by rider', WaybillRecord.scheduledRideSource),
      ('Expired', WaybillRecord.assignedByMoveraSource),
    ]) ...{
      'status $status': record(status, source).statusText,
      'source $source': record(status, source).sourceText,
    },
    'waybill driver': record('x', 'y').driverNameText,
    'waybill vehicle': record('x', 'y').vehicleText,
    'waybill plate': record('x', 'y').licensePlateText,
    'waybill rider': record('x', 'y').riderNameText,
    for (final label in [
      'Pickup far away',
      'Scheduled ride',
      'Airport pickup',
      'Event pickup',
    ])
      'waiting $label': WaitingTerms(
        freeMinutes: 1,
        perMinute: Money(minorUnits: 1),
        noShowAfterMinutes: 1,
        noShowFee: Money(minorUnits: 1),
        ruleLabels: [label],
      ).rule,
  };
}

/// [text] with its runs of blanks as one space, trimmed.
String _words(String text) => text.trim().replaceAll(RegExp(r'\s+'), ' ');
