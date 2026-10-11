class Fmt {
  const Fmt._();

  static String bytes(num value) {
    if (value < 1024) return '${value.toInt()} B';
    final kb = value / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 2 : 1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  static String duration(num ms) {
    if (ms <= 0) return '-';
    if (ms < 1000) return '${ms.toInt()} ms';
    final s = ms / 1000;
    if (s < 60) return '${s.toStringAsFixed(s < 10 ? 2 : 1)} s';
    final m = (s / 60).floor();
    return '${m}m ${(s % 60).toInt()}s';
  }

  static String clock(int epochMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  static String dateTime(int epochMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(epochMs);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  static String shortType(String contentType) {
    if (contentType.isEmpty) return '-';
    final main = contentType.split(';').first.trim();
    final slash = main.indexOf('/');
    if (slash < 0) return main;
    final sub = main.substring(slash + 1);
    return sub.contains('+') ? sub.split('+').last : sub;
  }

  static String ellipsize(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max - 1)}...';
  }
}
