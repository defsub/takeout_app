// Copyright (C) 2023 The Takeout Authors.
//
// This file is part of Takeout.
//
// Takeout is free software: you can redistribute it and/or modify it under the
// terms of the GNU Affero General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version.
//
// Takeout is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for
// more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Takeout.  If not, see <https://www.gnu.org/licenses/>.

import 'package:takeout_app/client/etag.dart';
import 'package:takeout_app/spiff/model.dart';

import 'spiff.dart';
import 'track_repository.dart';

class _TrackIdentifier implements TrackIdentifier {
  final ETag _etag;

  _TrackIdentifier(Entry track) : _etag = ETag(track.etag);

  @override
  String get key => _etag.key;
}

Future<void> pruneCache(
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
            await trackCache.remove(id);
          }
        }
      }
    });
  });
}
