/// Display formatting shared across screens. Kept dependency-free (no intl)
/// because the app only needs a handful of fixed English formats.
library;

String _two(int n) => n.toString().padLeft(2, '0');

/// 24-hour clock, e.g. "09:05".
String formatClock(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

/// Short relative label: "just now", "5m ago", "3h ago", "yesterday", "4d ago".
/// Future times read as "in 2h" / "tomorrow" / "in 3d".
String formatRelative(DateTime time, DateTime now) {
  final diff = now.difference(time);
  final future = diff.isNegative;
  final d = diff.abs();

  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return future ? 'in ${d.inMinutes}m' : '${d.inMinutes}m ago';
  if (d.inDays < 1) return future ? 'in ${d.inHours}h' : '${d.inHours}h ago';
  if (d.inDays == 1) return future ? 'tomorrow' : 'yesterday';
  return future ? 'in ${d.inDays}d' : '${d.inDays}d ago';
}

/// Compact counts for tight spaces: 950 → "950", 1200 → "1.2k", 3400000 → "3.4M".
String compactNumber(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) return '${_trim(n / 1000)}k';
  return '${_trim(n / 1000000)}M';
}

String _trim(double value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

/// Seconds as "m:ss", for recording timers.
String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes:${_two(seconds)}';
}

/// "Good morning" / "Good afternoon" / "Good evening" for [now].
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}
