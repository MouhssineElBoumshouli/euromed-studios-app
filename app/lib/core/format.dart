import 'package:intl/intl.dart';

import '../domain/rules/availability.dart';

/// French date and time wording used across the app.
abstract final class Fmt {
  static final _time = DateFormat('HH:mm', 'fr_FR');
  static final _dayShort = DateFormat('EEE d MMM', 'fr_FR');
  static final _dayLong = DateFormat('EEEE d MMMM', 'fr_FR');
  static final _dateTime = DateFormat('EEE d MMM · HH:mm', 'fr_FR');
  static final _dayMonth = DateFormat('d MMM', 'fr_FR');
  static final _dayMonthYear = DateFormat('d MMM y', 'fr_FR');
  static final _month = DateFormat('MMMM y', 'fr_FR');

  static String time(DateTime d) => _time.format(d);

  static String range(DateTime a, DateTime b) => '${time(a)}–${time(b)}';

  /// "Aujourd’hui", "Demain", or "Lun. 18 nov."
  static String relativeDay(DateTime d, DateTime now) {
    final diff = dateOnly(d).difference(dateOnly(now)).inDays;
    if (diff == 0) return 'Aujourd’hui';
    if (diff == 1) return 'Demain';
    if (diff == -1) return 'Hier';
    return _cap(_dayShort.format(d));
  }

  static String longDay(DateTime d) => _cap(_dayLong.format(d));
  static String shortDay(DateTime d) => _cap(_dayShort.format(d));
  static String dateTime(DateTime d) => _cap(_dateTime.format(d));

  /// "14 nov."
  static String dayMonth(DateTime d) => _dayMonth.format(d);

  /// "14 nov. 2026"
  static String dayMonthYear(DateTime d) => _dayMonthYear.format(d);

  /// "Novembre 2026"
  static String month(DateTime d) => _cap(_month.format(d));

  /// "il y a 26 h", "il y a 15 min".
  static String ago(DateTime then, DateTime now) {
    final m = now.difference(then).inMinutes;
    if (m < 1) return 'à l’instant';
    if (m < 60) return 'il y a $m min';
    final h = m ~/ 60;
    if (h < 24) return 'il y a $h h';
    return 'il y a ${h ~/ 24} j';
  }

  /// "12 min", "3 h", "2 j": how long something has been waiting.
  static String duration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes < 1 ? 1 : d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours} h';
    return '${d.inDays} j';
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
