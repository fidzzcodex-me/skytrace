class BodyView {
  const BodyView({
    required this.size,
    required this.storedSize,
    required this.truncated,
    required this.contentType,
    required this.encoding,
    required this.isBinary,
    required this.text,
    required this.base64,
  });

  final int size;
  final int storedSize;
  final bool truncated;
  final String contentType;
  final String encoding;
  final bool isBinary;
  final String text;
  final String base64;

  bool get isEmpty => size == 0 && text.isEmpty && base64.isEmpty;

  factory BodyView.fromJson(Map<String, dynamic> json) => BodyView(
        size: (json['size'] ?? 0) as int,
        storedSize: (json['storedSize'] ?? 0) as int,
        truncated: (json['truncated'] ?? false) as bool,
        contentType: (json['contentType'] ?? '') as String,
        encoding: (json['encoding'] ?? '') as String,
        isBinary: (json['isBinary'] ?? false) as bool,
        text: (json['text'] ?? '') as String,
        base64: (json['base64'] ?? '') as String,
      );
}

class Timings {
  const Timings({
    required this.connect,
    required this.tls,
    required this.send,
    required this.wait,
    required this.receive,
    required this.total,
  });

  final int connect;
  final int tls;
  final int send;
  final int wait;
  final int receive;
  final int total;

  factory Timings.fromJson(Map<String, dynamic> json) => Timings(
        connect: (json['connect'] ?? 0) as int,
        tls: (json['tls'] ?? 0) as int,
        send: (json['send'] ?? 0) as int,
        wait: (json['wait'] ?? 0) as int,
        receive: (json['receive'] ?? 0) as int,
        total: (json['total'] ?? 0) as int,
      );
}
