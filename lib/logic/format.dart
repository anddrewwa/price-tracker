/// Small formatting helpers shared by the logic and the UI.
library;

/// 1299.5 -> "$1,299.50"
String money(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '\$$whole.${parts[1]}';
}

/// "just now", "5 min ago", "3 hr ago", or a date.
String timeAgo(DateTime? time) {
  if (time == null) return 'never';
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} hr ago';
  return '${time.month}/${time.day}/${time.year}';
}

/// "10/21 5:07 PM"
String shortDateTime(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  return '${t.month}/${t.day} $hour:$minute $ampm';
}
