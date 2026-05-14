/// Backend free-tier quota block (`code: quota_exceeded`, HTTP 403).
class AppQuotaExceededException implements Exception {
  const AppQuotaExceededException({
    required this.key,
    required this.limit,
    required this.current,
  });

  final String key;
  final int limit;
  final int current;

  @override
  String toString() =>
      'AppQuotaExceededException(key: $key, limit: $limit, current: $current)';
}
