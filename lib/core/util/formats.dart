import 'package:intl/intl.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double v = bytes.toDouble();
  int u = -1;
  do {
    v /= 1024;
    u++;
  } while (v >= 1024 && u < units.length - 1);
  return '${v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} ${units[u]}';
}

String formatCount(int n) => NumberFormat.compact().format(n);

String formatDurationShort(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }
  if (d.inMinutes > 0) {
    return '${d.inMinutes}m ${d.inSeconds % 60}s';
  }
  return '${d.inSeconds}s';
}
