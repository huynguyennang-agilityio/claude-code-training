/// 21:55, in the device's time zone.
String formatClock(DateTime moment) {
  final local = moment.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// Metres as kilometres with two decimals: 3080 → "3.08".
String formatDistanceKm(int metres) => (metres / 1000).toStringAsFixed(2);

/// Minutes as hours with one decimal: 390 → "6.5".
String formatSleepHours(int minutes) => (minutes / 60).toStringAsFixed(1);
