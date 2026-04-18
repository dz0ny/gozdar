class HttpCacheEntry {
  int id;
  String urlHash;
  String url;
  String responseBody;
  int statusCode;
  DateTime cachedAt;

  HttpCacheEntry({
    this.id = 0,
    required this.urlHash,
    required this.url,
    required this.responseBody,
    required this.statusCode,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id == 0 ? null : id,
        'url_hash': urlHash,
        'url': url,
        'response_body': responseBody,
        'status_code': statusCode,
        'cached_at': cachedAt.millisecondsSinceEpoch,
      };

  factory HttpCacheEntry.fromMap(Map<String, dynamic> map) => HttpCacheEntry(
        id: map['id'] as int,
        urlHash: map['url_hash'] as String,
        url: map['url'] as String,
        responseBody: map['response_body'] as String,
        statusCode: map['status_code'] as int,
        cachedAt: DateTime.fromMillisecondsSinceEpoch(map['cached_at'] as int),
      );
}
