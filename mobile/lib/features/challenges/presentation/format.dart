import '../domain/entities/challenge.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _day(DateTime date) => '${_months[date.month - 1]} ${date.day}';

/// "Oct 20", in the device's time zone.
String formatDay(DateTime date) => _day(date.toLocal());

/// "Oct 1 – Oct 31", in the device's time zone.
String formatShortRange(DateTime start, DateTime end) =>
    '${_day(start.toLocal())} – ${_day(end.toLocal())}';

/// "Oct 1 – Oct 31, 2026". A range across two years names both.
String formatFullRange(DateTime start, DateTime end) {
  final from = start.toLocal();
  final to = end.toLocal();
  if (from.year == to.year) {
    return '${_day(from)} – ${_day(to)}, ${to.year}';
  }
  return '${_day(from)}, ${from.year} – ${_day(to)}, ${to.year}';
}

/// 50000 → "50,000".
String formatNumber(int value) {
  final digits = value.abs().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return value < 0 ? '-$grouped' : grouped.toString();
}

/// Metres as kilometres, without a trailing ".0": 20000 → "20", 2500 → "2.5".
String formatKm(int metres) {
  final km = metres / 1000;
  return km == km.roundToDouble()
      ? km.round().toString()
      : km.toStringAsFixed(1);
}

/// What a threshold or target is in: "50,000 steps" or "20 km".
String formatGoal(ChallengeType type, int value) =>
    type.countsSteps ? '${formatNumber(value)} steps' : '${formatKm(value)} km';

/// Like [formatGoal] but without the unit for steps, for a tile: "20,000" or "5 km".
String formatThreshold(ChallengeType type, int value) =>
    type.countsSteps ? formatNumber(value) : '${formatKm(value)} km';

/// "813", "1.2K", "12K".
String formatCount(int value) {
  if (value < 1000) return '$value';
  final thousands = value / 1000;
  final text = thousands < 10
      ? thousands.toStringAsFixed(1)
      : thousands.round().toString();
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}K';
}

/// Asks Cloudinary for a picture [width] pixels wide in the best format, by
/// inserting transformations after `/upload/` (the same as the backend's
/// `resized_url`). Anything that is not a Cloudinary delivery URL is returned
/// as it is.
String resizedImageUrl(String url, int width) {
  const marker = '/image/upload/';
  final at = url.indexOf(marker);
  if (at < 0) return url;
  final head = url.substring(0, at + marker.length);
  final rest = url.substring(at + marker.length);
  if (rest.startsWith('f_auto') || rest.startsWith('q_auto')) return url;
  return '${head}f_auto,q_auto,w_$width/$rest';
}
