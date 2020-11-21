// Copyright (C) 2020 The Takeout Authors.
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:path_provider/path_provider.dart';

import 'client.dart';
import 'cover.dart';
import 'music.dart';
import 'patch.dart';
import 'spiff.dart';

class PlaylistFacade {
  static const _playlistName = 'playlist.json';

  Future<File> _playlistFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$_playlistName';
    return File(path);
  }

  String _ref({Release release, Track track, Station station}) {
    String ref;
    if (release != null) {
      ref = '/music/releases/${release.id}/tracks';
    } else if (station != null) {
      ref = '/music/radio/${station.id}';
    } else if (track != null) {
      ref = '/music/tracks/${track.id}';
    }
    return ref;
  }

  MediaItem _trackItem(Track track, Uri uri) {
    final coverUri = trackCoverUrl(track);
    return MediaItem(
      id: uri.toString(),
      album: track.release,
      title: track.title,
      artist: track.artist,
      artUri: coverUri,
    );
  }

  MediaItem _entryItem(Entry entry, Uri uri) {
    return MediaItem(
      id: uri.toString(),
      album: entry.album,
      title: entry.title,
      artist: entry.creator,
      artUri: entry.image,
    );
  }

  Future stage(Spiff spiff) {
    return _stage(spiff);
  }

  /// Play a release, track or station, replacing current playlist.
  Future play({Release release, Track track, Station station}) async {
    final completer = Completer();
    final client = Client();
    if (track != null) {
      final uri = await client.locate(track);
      AudioService.playMediaItem(_trackItem(track, uri));
      completer.complete();
    } else {
      final ref = _ref(release: release, station: station);
      print('play $ref');
      // get playlist from server, resolving refs
      client.patch(patchReplace(ref)).then((result) {
        if (result.notModified()) {
          load().then((spiff) {
            _update(spiff, index: 0).then((spiff) {
              AudioService.customAction('stage+play')
                  .then((v) => completer.complete());
            }).catchError((e) => completer.completeError(e));
          }).catchError((e) => completer.completeError(e));
        } else {
          _update(result.toSpiff(), index: 0).then((spiff) {
            AudioService.customAction('stage+play')
                .then((v) => completer.complete());
          }).catchError((e) => completer.complete(e));
        }
      }).catchError((e) => completer.completeError(e));
    }
    return completer.future;
  }

  Future<void> pause() async {}

  Future<void> stop() async {}

  Future<Spiff> next() async {
    final completer = Completer<Spiff>();
    // load saved playlist
    load().then((spiff) {
      final next = spiff.index + 1;
      if (next >= spiff.playlist.tracks.length) {
        // end of tracks, save and stop
        _update(spiff, index: -1)
            .then((spiff) => completer.complete(spiff))
            .catchError((e) => completer.completeError(e));
      } else {
        // move to next track, save and play
        _update(spiff, index: next)
            .then((v) => completer.complete(spiff))
            .catchError((e) => completer.completeError(e));
      }
    });
    return completer.future;
  }

  Future<Spiff> previous() async {
    final completer = Completer<Spiff>();
    // load saved playlist
    load().then((spiff) {
      var previous = spiff.index - 1;
      if (previous < 0) {
        previous = 0;
      }
      // move to previous track, save and play
      _update(spiff, index: previous)
          .then((spiff) => completer.complete(spiff))
          .catchError((e) => completer.completeError(e));
    });
    return completer.future;
  }

  Future<Spiff> update({int index, double position}) async {
    final completer = Completer<Spiff>();
    load().then((spiff) {
      index = index ?? spiff.index;
      position = position ?? spiff.position;
      if (spiff.index == index &&
          spiff.position == position) {
        // no change
        completer.complete(spiff);
      } else {
        _update(spiff, index: index, position: position)
            .then((spiff) => completer.complete(spiff))
            .catchError((e) => completer.completeError(e));
      }
    });
    return completer.future;
  }

  /// Update playlist index, position and save
  Future<Spiff> _update(Spiff spiff, {int index, double position = 0}) async {
    print("update: index $index at $position");
    final completer = Completer<Spiff>();
    _save(spiff.copyWith(
            index: index ?? spiff.index, position: position ?? spiff.position))
        .then((spiff) {
      _updateServer(spiff); // async
      completer.complete(spiff);
    }).catchError((e) => completer.completeError(e));

    return completer.future;
  }

  /// Update playlist index & position at server.
  Future _updateServer(Spiff spiff) {
    final completer = Completer();
    final client = Client();
    client.patch(patchPosition(spiff.index, spiff.position)).then((result) {
      completer.complete();
    }).catchError((e) => completer.completeError(e));
    return completer.future;
  }

  Future _stage(Spiff spiff) async {
    AudioService.customAction('stage');
  }

  /// Append a release, track or station to current playlist.
  /// TODO
  void append({Release release, Track track, Station station}) {
    String ref = _ref(release: release, track: track, station: station);
    if (ref != null) {
      final client = Client();
      // client.patch(patchAppend(ref)).then((spiff) => _save(spiff));
    }
  }

  /// Clear current playlist.
  /// TODO
  void clear() {
    final client = Client();
    // client.patch(patchClear()).then((spiff) => _save(spiff));
  }

  /// Load saved playlist.
  Future<Spiff> load() async {
    final completer = Completer<Spiff>();
    final file = await _playlistFile();
    file.exists().then((exists) {
      if (exists) {
        file.readAsString().then((body) {
          print('load is ${body.length}');
          completer.complete(Spiff.fromJson(jsonDecode(body)));
        }).catchError((e) => completer.completeError(e));
      } else {
        completer.complete(Spiff.empty());
      }
    });
    return completer.future;
  }

  /// Sync (fetch and save) playlist from server.
  Future<void> sync() async {
    final completer = Completer();
    _fetch().then((spiff) {
      _save(spiff).then((v) => completer.complete());
    });
    return completer.future;
  }

  Future<Spiff> _fetch() async {
    final completer = Completer<Spiff>();
    final client = Client();
    client.playlist().then((spiff) {
      completer.complete(spiff);
    }).catchError((e) {
      print(e);
      completer.completeError(e);
    });
    return completer.future;
  }

  Future<Spiff> _save(Spiff spiff) async {
    final completer = Completer<Spiff>();
    final file = await _playlistFile();
    print('save ');
    file.writeAsString(jsonEncode(spiff), flush: true).then((f) {
      completer.complete(spiff);
    }).catchError((e) {
      print(e);
      completer.completeError(e);
    });
    return completer.future;
  }

  Future<MediaItemQueue> mediaItemQueue() async {
    final queue = List<MediaItem>();
    final client = Client();
    final spiff = await load();
    for (var t in spiff.playlist.tracks) {
      final uri = await client.locate(t);
      queue.add(_entryItem(t, uri));
    }
    for (var q in queue) {
      print('${q.artist} / ${q.title} / ${q.id}');
    }
    final headers = await client.headers();
    return MediaItemQueue(queue, spiff.index, spiff.position, headers);
  }
}

class MediaItemQueue {
  final List<MediaItem> queue;
  final int index;
  final double position;
  final Map headers;

  MediaItemQueue(this.queue, this.index, this.position, this.headers);
}