// Follow-up probe: the Z suffix is dropped by toString() because
// RecurrenceRuleToStringOptions.isTimeUtc defaults to false.
// Verify that the explicit option restores RFC-conformant, lossless output,
// and check what the Z-less form parses back to.

import 'package:rrule/rrule.dart';

void main() {
  const codecDefault = RecurrenceRuleStringCodec();
  const codecUtc = RecurrenceRuleStringCodec(
    toStringOptions: RecurrenceRuleToStringOptions(isTimeUtc: true),
  );

  const withUntil = 'RRULE:FREQ=DAILY;UNTIL=20260930T235959Z';
  const noUntil = 'RRULE:FREQ=WEEKLY;INTERVAL=2;BYDAY=TU,TH';
  const withCount = 'RRULE:FREQ=DAILY;COUNT=5';

  for (final src in [noUntil, withCount, withUntil]) {
    final rule = RecurrenceRule.fromString(src);
    final viaDefault = codecDefault.encode(rule);
    final viaUtc = codecUtc.encode(rule);
    print('src            : $src');
    print('  toString()   : ${rule.toString()}   lossless=${rule.toString() == src}');
    print('  codec default: $viaDefault   lossless=${viaDefault == src}');
    print('  isTimeUtc:true: $viaUtc   lossless=${viaUtc == src}');
    print('');
  }

  print('--- what does the Z-less form parse back to? ---');
  final a = RecurrenceRule.fromString('RRULE:FREQ=DAILY;UNTIL=20260930T235959Z');
  final b = RecurrenceRule.fromString('RRULE:FREQ=DAILY;UNTIL=20260930T235959');
  print('with Z   -> until=${a.until}  isUtc=${a.until?.isUtc}');
  print('without Z-> until=${b.until}  isUtc=${b.until?.isUtc}');
  print('equal rules? ${a == b}');
}
