// Probe for reviewer finding B-1: does `rrule` treat UNTIL as a naive
// (wall-clock) bound, or does it apply any timezone conversion?
//
// If it is naive, then storing a *true UTC* UNTIL (as RFC 5545 requires when
// DTSTART is local-time-with-TZID) while expanding in the "fake UTC" wall-clock
// domain will silently include/exclude the last occurrence.

import 'package:rrule/rrule.dart';

String d(DateTime x) => x.toIso8601String();

void section(String s) => print('\n--- $s ---');

void main() {
  section('1. UNTIL boundary: inclusive or exclusive?');
  // Daily from 09-07T00:00, UNTIL exactly 09-10T00:00.
  final r1 = RecurrenceRule.fromString(
    'RRULE:FREQ=DAILY;UNTIL=20260910T000000Z',
  );
  final got1 = r1
      .getInstances(start: DateTime.utc(2026, 9, 7))
      .map(d)
      .toList();
  print('instances = $got1');
  print('includes the UNTIL instant itself? '
      '${got1.contains(DateTime.utc(2026, 9, 10).toIso8601String())}');

  section('2. UNTIL one second before the instance -> should exclude it');
  final r2 = RecurrenceRule.fromString(
    'RRULE:FREQ=DAILY;UNTIL=20260909T235959Z',
  );
  print('instances = '
      '${r2.getInstances(start: DateTime.utc(2026, 9, 7)).map(d).toList()}');

  section('3. Is UNTIL compared naively against the wall-clock instances?');
  // Wall clock 23:00 daily. UNTIL = 20260930T095959Z.
  // If rrule converted anything by timezone, the answer would depend on a zone.
  // It has no zone input at all, so this must be a naive comparison.
  final r3 = RecurrenceRule.fromString(
    'RRULE:FREQ=DAILY;UNTIL=20260930T095959Z',
  );
  final got3 = r3
      .getInstances(start: DateTime.utc(2026, 9, 28, 23))
      .map(d)
      .toList();
  print('start=2026-09-28T23:00 (wall), UNTIL=2026-09-30T09:59:59');
  print('instances = $got3');
  print('=> last instance ${got3.isEmpty ? "NONE" : got3.last}');
  print('If naive: 09-30T23:00 > 09-30T09:59:59 so it must be DROPPED.');

  section('4. Same rule, UNTIL late enough to keep 09-30T23:00');
  final r4 = RecurrenceRule.fromString(
    'RRULE:FREQ=DAILY;UNTIL=20260930T235959Z',
  );
  print('instances = '
      '${r4.getInstances(start: DateTime.utc(2026, 9, 28, 23)).map(d).toList()}');

  section('5. Does the package accept a non-UTC UNTIL at all?');
  try {
    RecurrenceRule(
      frequency: Frequency.daily,
      until: DateTime(2026, 9, 30), // isUtc == false
    );
    print('accepted a local (isUtc=false) UNTIL -- no assertion');
  } catch (e) {
    print('rejected non-UTC UNTIL: ${e.runtimeType}');
  }

  section('6. UNTIL round-trip through toString()');
  const src = 'RRULE:FREQ=DAILY;UNTIL=20260930T235959Z';
  final r6 = RecurrenceRule.fromString(src);
  print('src  = $src');
  print('back = ${r6.toString()}');
  print('lossless = ${r6.toString() == src}');

  section('7. COUNT as the control group (timezone-independent)');
  final r7 = RecurrenceRule.fromString('RRULE:FREQ=DAILY;COUNT=3');
  print('instances = '
      '${r7.getInstances(start: DateTime.utc(2026, 9, 28, 23)).map(d).toList()}');
}
