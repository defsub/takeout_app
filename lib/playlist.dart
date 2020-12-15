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
import 'dart:io';

import 'package:audio_service/audio_service.dart';

import 'client.dart';
import 'cover.dart';
import 'music.dart';
import 'patch.dart';
import 'spiff.dart';
import 'global.dart';
import 'cache.dart';

class PlaylistException implements Exception {
  const PlaylistException();
}

class MediaQueue {
  static const prefsPlaylist = 'current_playlist';

  static Future<Uri> getCurrentPlaylist() async {
    final value = await prefsString(prefsPlaylist);
    print('current is $value');
    return value != null ? Uri.parse(value) : await Client.defaultPlaylistUri();
  }

  static Future<void> setCurrentPlaylist(Uri uri) async {
    await (await prefs).setString(prefsPlaylist, uri?.toString());
  }

  static String _ref({Release release, Track track, Station station}) {
    String ref;
    if (release != null) {
      ref = '/music/releases/${release.id}/tracks';
    } else if (station != null) {
      ref = '/music/radio/${station.id}';
    } else if (track != null) {
      ref = '/music/tracks/${track.id}'; // TODO
    }
    return ref;
  }

  static Future restore() async {
    final spiff = await SpiffCache.load(await getCurrentPlaylist());
    return _stage(spiff);
  }

  static Future playSpiff(Spiff spiff) async {
    await setCurrentPlaylist(Uri.parse(spiff.playlist.location));
    await SpiffCache.put(spiff);
    return _stage(spiff);
  }

  /// Play a release, track or station, replacing current playlist.
  static Future play({Release release, Track track, Station station}) async {
    if (track != null) {
      // final uri = await client.locate(track);
      // final headers = await client.headers();
      // TODO
      // AudioService.playMediaItem(_trackMediaItem(track, uri, headers));
    } else {
      return _playRef(_ref(release: release, station: station));
    }
  }

  /// Play remote reference to release, track, station, etc.
  static Future _playRef(String ref) async {
    await setCurrentPlaylist(null);
    final uri = await Client.defaultPlaylistUri();

    final completer = Completer();
    final client = Client();

    print('play $ref');
    // get playlist from server, resolving refs
    client.patch(patchReplace(ref)).then((result) async {
      if (result.notModified()) {
        SpiffCache.get(uri).then((spiff) {
          update(spiff, index: 0).then((_) {
            AudioService.customAction('stage+play')
                .then((_) => completer.complete());
          }).catchError((e) => completer.completeError(e));
        }).catchError((e) => completer.completeError(e));
      } else {
        var spiff = result.toSpiff();
        print('fixing location ${spiff.playlist.location}');
        spiff = spiff.copyWith(
            playlist: spiff.playlist
                .copyWith(location: uri.toString())); // TODO fixme
        update(spiff, index: 0).then((_) {
          AudioService.customAction('stage+play')
              .then((_) => completer.complete());
        }).catchError((e) => completer.completeError(e));
      }
    }).catchError((e) => completer.completeError(e));
    return completer.future;
  }

  static Future<Spiff> update(Spiff spiff, {int index, double position}) async {
    spiff = spiff.copyWith(
        index: index ?? spiff.index, position: position ?? spiff.position);

    // update with current index & position
    await SpiffCache.put(spiff);

    if (spiff.isRemote()) {
      final defaultLocation = await Client.getDefaultPlaylistUrl();
      if (spiff.playlist.location == defaultLocation) {
        _updateServer(spiff);
      }
    }

    return spiff;
  }

  /// Update playlist index & position at server.
  static Future _updateServer(Spiff spiff) {
    final completer = Completer();
    final client = Client();
    client.patch(patchPosition(spiff.index, spiff.position)).then((result) {
      completer.complete();
    }).catchError((e) => completer.completeError(e));
    return completer.future;
  }

  static Future _stage(Spiff spiff) async {
    AudioService.customAction('stage');
  }

  /// Append a release, track or station to current playlist.
  /// TODO should only append to default playlist
  static Future<Spiff> append(
      {Release release, Track track, Station station}) async {
    final completer = Completer<Spiff>();
    String ref = _ref(release: release, track: track, station: station);
    if (ref != null) {
      final client = Client();
      client.patch(patchAppend(ref)).then((result) {
        final spiff = result.toSpiff();
        SpiffCache.put(spiff).then((_) {
          AudioService.customAction('test')
              .whenComplete(() => completer.complete(spiff));
        }).catchError((e) => completer.completeError(e));
      }).catchError((e) => completer.completeError(e));
    } else {
      completer.completeError(PlaylistException());
    }
    return completer.future;
  }

  /// Clear current playlist.
  /// TODO
  void clear() {
    final client = Client();
    // client.patch(patchClear()).then((spiff) => _save(spiff));
  }

  /// Fetch and cache the current playlist from the server.
  static Future<Spiff> sync() async {
    final uri = await Client.defaultPlaylistUri();
    final completer = Completer<Spiff>();
    _fetch().then((spiff) {
      print('fixing2 location ${spiff.playlist.location}');
      spiff = spiff.copyWith(
          playlist:
              spiff.playlist.copyWith(location: uri.toString())); // TODO fixme
      SpiffCache.put(spiff).then((_) => completer.complete(spiff));
    });
    return completer.future;
  }

  /// server only
  static Future<Spiff> _fetch() async {
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

  static Future<MediaState> load() async {
    final spiff = await SpiffCache.load(await getCurrentPlaylist());
    return fromSpiff(spiff);
  }

  static Future<MediaState> fromSpiff(Spiff spiff) async {
    final client = Client();
    final queue = await _createQueue(client, spiff.playlist.tracks);
    for (var q in queue) {
      print('${q.artist} / ${q.title} / ${q.id} / ${q.extras['headers']}');
    }
    if (spiff.index < 0) {
      spiff = spiff.copyWith(index: 0);
    }
    return MediaState(spiff, queue, spiff.index, spiff.position);
  }

  static MediaItem _trackMediaItem(Track track, Uri uri, Map headers) {
    final coverUri = trackCoverUrl(track);
    return MediaItem(
      id: uri.toString(),
      album: track.release,
      title: track.title,
      artist: track.artist,
      artUri: coverUri,
      extras: {'headers': headers},
    );
  }

  static MediaItem _entryMediaItem(Entry entry, Uri uri, Map headers) {
    return MediaItem(
      id: uri.toString(),
      album: entry.album,
      title: entry.title,
      artist: entry.creator,
      artUri: entry.image,
      extras: {'headers': headers},
    );
  }

  static Future<List<MediaItem>> _createQueue(
      Client client, List<Entry> entries) async {
    final items = List<MediaItem>();
    final headers = await client.headers();
    for (var t in entries) {
      final uri = await client.locate(t);
      items.add(_entryMediaItem(t, uri, headers));
    }
    return items;
  }
}

class MediaState {
  int _index;
  double _position;
  final List<MediaItem> _queue;
  final Spiff _spiff;

  MediaState(this._spiff, this._queue, this._index, this._position);

  /// current index
  int get index => _index;

  /// current position
  double get position => _position;

  /// current queue
  List<MediaItem> get queue => _queue;

  /// current item in the queue
  MediaItem get current => _queue[_index == -1 ? 0 : _index];

  /// set current item
  set current(MediaItem item) => _queue[_index] = item;

  /// is queue empty?
  bool get isEmpty => _queue.isEmpty;

  /// length of queue
  int get length => _queue.length;

  /// item at index or null
  MediaItem item(int index) {
    return index < length ? _queue[index] : null;
  }

  /// add item to queue
  void add(MediaItem item) {
    _queue.add(item);
  }

  /// find item with id
  int findId(String id) {
    return _queue.indexWhere((item) => item.id == id);
  }

  /// find item
  int findItem(MediaItem target) {
    return _queue.indexWhere((item) => item == target);
  }

  /// update current index and position in playlist
  Future<Spiff> update(int index, double position) async {
    print('spiff update ${index} ${position}');
    _index = index;
    _position = position;
    return MediaQueue.update(_spiff, index: index, position: _position);
  }
}
