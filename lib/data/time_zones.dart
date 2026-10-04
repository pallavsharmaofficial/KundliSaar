import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Historical time zone offsets, resolved by zone name rather than by a stored
/// number. A 1944 Indian birth ran on war time (IST+1 from 1 September 1942 to
/// 15 October 1945) and a chart that ignores that lands the lagna about
/// fifteen degrees out.
class TimeZones {
  static bool _ready = false;

  static void ensureInitialised() {
    if (_ready) return;
    tzdata.initializeTimeZones();
    _ready = true;
  }

  /// The offset in force at a local wall-clock time in [zoneId].
  static Duration offsetFor(String zoneId, DateTime wallClock) {
    ensureInitialised();
    final tz.Location location = _lookup(zoneId);
    final tz.TZDateTime moment = tz.TZDateTime(
      location,
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
    );
    return moment.timeZoneOffset;
  }

  /// The short name of the zone at that moment, such as IST.
  static String abbreviationFor(String zoneId, DateTime wallClock) {
    ensureInitialised();
    final tz.Location location = _lookup(zoneId);
    return tz.TZDateTime(
      location,
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
    ).timeZoneName;
  }

  static tz.Location _lookup(String zoneId) {
    ensureInitialised();
    try {
      return tz.getLocation(zoneId);
    } catch (_) {
      return tz.getLocation('Asia/Kolkata');
    }
  }
}

String formatOffset(Duration offset) {
  final bool negative = offset.isNegative;
  final Duration absolute = offset.abs();
  final String hours = absolute.inHours.toString().padLeft(2, '0');
  final String minutes = (absolute.inMinutes % 60).toString().padLeft(2, '0');
  return '${negative ? '-' : '+'}$hours:$minutes';
}
