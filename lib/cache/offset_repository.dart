import 'dart:io';

import 'package:takeout_app/api/model.dart';
import 'offset_provider.dart';

abstract class OffsetIdentifier {
  String get key;
}

class OffsetCacheRepository {
  final Directory directory;
  final OffsetCache _cache;

  OffsetCacheRepository({required this.directory, OffsetCache? cache})
      : _cache = cache ?? OffsetFileCache(directory: directory);

  Future<Offset?> get(OffsetIdentifier id, {Duration? ttl}) async {
    return _cache.get(id, ttl: ttl);
  }

  Future put(Offset offset) async {
    return _cache.put(offset);
  }

  void remove(Offset offset) {
    _cache.remove(offset);
  }

  Future<Iterable<Offset>> merge(Iterable<Offset> offsets) {
    return _cache.merge(offsets);
  }

  Future<Map<String, Offset>> entries() async {
    return _cache.entries();
  }
}
