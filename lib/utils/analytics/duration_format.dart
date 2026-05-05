String formatDurationMs(int ms) {
  final clamped = ms < 0 ? 0 : ms;
  if (clamped < 60000) {
    return '${(clamped / 1000.0).toStringAsFixed(1)} с';
  }
  final totalSec = clamped / 1000.0;
  final minutes = totalSec ~/ 60;
  final seconds = totalSec - (minutes * 60);
  return '$minutes:${seconds.toStringAsFixed(1).padLeft(4, '0')}';
}
