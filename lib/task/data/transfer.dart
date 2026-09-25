/// Live byte counters for one in-flight download.
class DownloadTransfer {
  const DownloadTransfer({
    this.received = 0,
    this.total,
    this.bytesPerSecond = 0,
  });

  final int received;
  final int? total;
  final double bytesPerSecond;

  double get fraction {
    final int? expected = total;
    if (expected == null || expected <= 0) return 0;
    return (received / expected).clamp(0, 1);
  }
}

String formatByteCount(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final double kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final double mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  final double gb = mb / 1024;
  return '${gb.toStringAsFixed(gb < 10 ? 1 : 0)} GB';
}

String formatTransfer(DownloadTransfer transfer) {
  final String size = transfer.total == null
      ? formatByteCount(transfer.received)
      : '${formatByteCount(transfer.received)} / ${formatByteCount(transfer.total!)}';
  if (transfer.bytesPerSecond <= 0) return size;
  return '$size · ${formatByteCount(transfer.bytesPerSecond.round())}/s';
}
