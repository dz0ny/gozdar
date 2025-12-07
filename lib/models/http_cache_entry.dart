import 'package:objectbox/objectbox.dart';

@Entity()
class HttpCacheEntry {
  @Id()
  int id;

  @Index()
  @Unique()
  String urlHash;

  String url;
  String responseBody;
  int statusCode;

  @Property(type: PropertyType.date)
  DateTime cachedAt;

  HttpCacheEntry({
    this.id = 0,
    required this.urlHash,
    required this.url,
    required this.responseBody,
    required this.statusCode,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();
}
