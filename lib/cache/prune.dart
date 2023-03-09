import 'spiff.dart';
import 'track_repository.dart';

import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/client/etag.dart';

class _TrackIdentifier implements TrackIdentifier {
  final ETag _etag;

  _TrackIdentifier(Entry track) : _etag = ETag(track.etag);

  @override
  String get key => _etag.key;
}

void prune(
    SpiffCacheRepository spiffCache, TrackCacheRepository trackCache) async {
  final spiffs = await spiffCache.entries;
  await Future.forEach<Spiff>(spiffs, (spiff) async {
    final tracks = spiff.playlist.tracks;
    await Future.forEach<Entry>(tracks, (track) async {
      final id = _TrackIdentifier(track);
      final file = await trackCache.get(id);
      if (file != null) {
        final fileSize = file.statSync().size;
        if (fileSize != track.size) {
          if (spiff.isPodcast()) {
            // Allow podcasts download to be larger - TWiT sizes can be off
          } else {
            trackCache.remove(id);
          }
        }
      }
    });
  });
}
