import 'package:intl/intl.dart';

final _day = DateFormat('d MMM yyyy');
final _dayShort = DateFormat('d MMM');
final _weekdayDay = DateFormat('EEE, d MMM');
final _dateTime = DateFormat('d MMM yyyy, h:mm a');
final _money = NumberFormat('#,##0.00');

String formatDate(DateTime? d) => d == null ? '—' : _day.format(d);
String formatDateShort(DateTime? d) => d == null ? '—' : _dayShort.format(d);
String formatWeekdayDate(DateTime? d) => d == null ? '—' : _weekdayDay.format(d);
String formatDateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d);
String formatMoney(double? v) => v == null ? '—' : _money.format(v);

/// Minutes since midnight as `9:05 AM`.
String formatMinutes(int? minutes) {
  if (minutes == null) return '—';
  final t = DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60);
  return DateFormat('h:mm a').format(t);
}

/// `82.5` → `82.5`, `80.0` → `80`.
String formatNumber(double? v, {int digits = 2}) {
  if (v == null) return '—';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(digits).replaceFirst(RegExp(r'0+$'), '');
}

String formatPercent(double? v) => v == null ? '—' : '${formatNumber(v, digits: 1)}%';

/// "in 3 days", "today", "2 days ago".
String relativeDays(DateTime date, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final diff = _dateOnly(date).difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return diff > 0 ? 'In $diff days' : '${-diff} days ago';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String timeAgo(DateTime d, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return formatDate(d);
}

/// `medical_leave` → `Medical leave`.
String humanize(String? code) {
  if (code == null || code.isEmpty) return '—';
  final s = code.replaceAll('_', ' ');
  return s[0].toUpperCase() + s.substring(1);
}
