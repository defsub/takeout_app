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

import 'package:audio_service/audio_service.dart';
import 'package:logging/logging.dart';

import 'client.dart';
import 'schema.dart';
import 'patch.dart';
import 'spiff.dart';
import 'global.dart';
import 'cache.dart';
import 'model.dart';
import 'util.dart';

const ExtraHeaders = 'headers';
const ExtraMediaType = 'mediaType';
const ExtraETag = 'etag';
const ExtraKey = 'key';
const ExtraLocation = 'location';

class PlaylistException implements Exception {
  const PlaylistException();
}

class Reference {
  final String reference;
  final MediaType type;

  Reference(this.reference, this.type);
}

class MediaQueue {
  static final log = Logger('MediaQueue');

  static const settingPlaylist = 'current_playlist';

  static Future<Uri> getCurrentPlaylist() async {
    final value = await prefsString(settingPlaylist);
    if (value == 'null') {
      log.warning('current is really "null"');
    }
    return value != null ? Uri.parse(value) : Client.defaultPlaylistUri();
  }

  static Future<void> setCurrentPlaylist(Uri? uri) async {
    await (await prefs).setString(settingPlaylist, uri.toString());
  }

  static Future savePosition(Duration position) async {
    final uri = await getCurrentPlaylist();
    var spiff = await SpiffCache.get(uri);
    if (spiff != null) {
      spiff = spiff.copyWith(position: position.inSeconds.toDouble());
      SpiffCache.put(spiff);
    }
  }

  static Reference _ref(
      {Release? release, Track? track, Station? station, Series? series}) {
    String ref = '';
    MediaType type = MediaType.music;
    if (release != null) {
      ref = '/music/releases/${release.id}/tracks';
      type = MediaType.music;
    } else if (station != null) {
      ref = '/music/radio/${station.id}';
      type = MediaType.music;
    } else if (track != null) {
      ref = '/music/tracks/${track.id}'; // TODO
      type = MediaType.music;
    } else if (series != null) {
      ref = '/podcasts/series/${series.id}';
      type = MediaType.podcast;
    }
    return Reference(ref, type);
  }

  static Future restore() async {
    log.fine('restore');
    final uri = await getCurrentPlaylist();
    final spiff = await SpiffCache.load(uri);
    return _stage(spiff);
  }

  static Spiff fromTracks(List<MediaLocatable> tracks,
      {String location = 'file:spiff.json',
      String creator = '',
      String title = '',
      int index = 0}) {
    final playlist = Playlist(
      location: location,
      creator: creator,
      title: title,
      image: '',
      date: DateTime.now().toString(),
      tracks: _trackEntries(tracks),
    );
    return Spiff(
        index: index,
        position: 0,
        playlist: playlist,
        type: MediaType.music.name);
  }

  static Future playTrack(MediaLocatable track) {
    return playSpiff(fromTracks([track]), index: 0);
  }

  static Future playTracks(List<MediaLocatable> tracks, {int index = 0}) {
    return playSpiff(fromTracks(tracks), index: index);
  }

  static Future playSpiff(Spiff spiff, {int index = 0}) async {
    // unless provided, this will restart at index 0
    log.info('playSpiff $spiff $index');
    spiff =
        spiff.copyWith(index: index >= 0 && index < spiff.length ? index : 0);
    final uri = Uri.parse(spiff.playlist.location ?? 'location-missing');
    await setCurrentPlaylist(uri);
    await SpiffCache.put(spiff);
    return audioHandler
        .customAction('doit', <String, dynamic>{'spiff': uri.toString()});
  }

  /// Play a release or station, replacing current playlist.
  static Future play(
      {Release? release,
      Station? station,
      Series? series,
      int index = 0}) async {
    return _playRef(_ref(release: release, station: station, series: series),
        index: index);
  }

  /// Play remote reference to release, track, station, etc.
  static Future _playRef(Reference ref,
      {int index = 0, double position = 0.0}) async {
    await setCurrentPlaylist(null);
    final uri = Client.defaultPlaylistUri();

    final completer = Completer();
    final client = Client();

    log.fine('play $ref index $index');
    // get playlist from server, resolving refs

    // ref patch with position
    final patch = patchReplace(ref.reference, ref.type.name) +
        patchPosition(index, position);
    client.patch(patch).then((result) async {
      if (result.notModified()) {
        SpiffCache.get(uri).then((spiff) {
          spiff = spiff!.copyWith(index: index, position: position);
          SpiffCache.put(spiff).then((_) {
            audioHandler.customAction('doit', <String, dynamic>{
              'spiff': uri.toString()
            }).then((_) => completer.complete());
          });
        }).catchError((e) {
          completer.completeError(e);
        });
      } else {
        var spiff = result.toSpiff();
        SpiffCache.put(spiff).then((_) {
          audioHandler.customAction('doit', <String, dynamic>{
            'spiff': uri.toString()
          }).then((_) => completer.complete());
        });
      }
    }).catchError((e) {
      completer.completeError(e);
    });
    return completer.future;
  }

  // Only call this from player task
  static Future<Spiff> update(Spiff spiff,
      {int? index, double? position}) async {
    spiff = spiff.copyWith(
        index: index ?? spiff.index, position: position ?? spiff.position);

    // update with current index & position, force to persist the index & position
    await SpiffCache.put(spiff);

    if (spiff.isRemote()) {
      final defaultLocation = Client.defaultPlaylistUri().toString();
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
    }).catchError((e) {
      completer.completeError(e);
    });
    return completer.future;
  }

  static Future _stage(Spiff spiff) async {
    Uri uri = Uri.parse(spiff.playlist.location ?? 'location-missing');
    audioHandler
        .customAction('stage', <String, dynamic>{'spiff': uri.toString()});
  }

  /// Append a release, track or station to current playlist.
  /// TODO append to either remote or local playlist
  static Future<Spiff> append(
      {Release? release, Track? track, Station? station}) async {
    final completer = Completer<Spiff>();
    Reference ref = _ref(release: release, track: track, station: station);
    if (isNotNullOrEmpty(ref.reference)) {
      final client = Client();
      client.patch(patchAppend(ref.reference)).then((result) {
        final spiff = result.toSpiff();
        SpiffCache.put(spiff).then((_) {
          audioHandler.customAction('test', <String, dynamic>{
            'fixme': 'test'
          }).whenComplete(() => completer.complete(spiff));
        }).catchError((e) {
          completer.completeError(e);
        });
      }).catchError((e) {
        completer.completeError(e);
      });
    } else {
      completer.completeError(PlaylistException());
    }
    return completer.future;
  }

  /// Clear current playlist.
  /// TODO
  // void clear() {
  //   final client = Client();
  //   // client.patch(patchClear()).then((spiff) => _save(spiff));
  // }

  /// Fetch and cache the current playlist from the server.
  static Future<Spiff> sync() async {
    final completer = Completer<Spiff>();
    _fetch().then((spiff) {
      SpiffCache.put(spiff).then((_) => completer.complete(spiff));
    }).catchError((e) {
      completer.completeError(e);
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
      log.warning(e);
      completer.completeError(e);
    });
    return completer.future;
  }

  static Future<MediaState> load(Uri uri) async {
    final spiff = await SpiffCache.load(uri);
    return fromSpiff(spiff);
  }

  static Future<MediaState> fromSpiff(Spiff spiff) async {
    final client = Client();
    final queue = await _createQueue(client, spiff);
    if (spiff.index < 0) {
      spiff = spiff.copyWith(index: 0);
    }
    return MediaState(spiff, queue, spiff.index, spiff.position);
  }

  static Future<MediaItem> trackMediaItem(MediaLocatable track) async {
    final client = Client();
    final entry = _trackEntry(track);
    final uri = await client.locate(track);
    final headers = await client.headers();
    return _entryMediaItem(entry, uri, headers, MediaType.music);
  }

  static List<Entry> _trackEntries(List<MediaLocatable> tracks) {
    final entries = <Entry>[];
    for (var t in tracks) {
      entries.add(_trackEntry(t));
    }
    return entries;
  }

  static Entry _trackEntry(MediaLocatable track) {
    return Entry(
      creator: track.creator,
      album: track.album,
      title: track.title,
      image: track.image,
      date: track.date,
      locations: [track.location],
      identifiers: [track.key],
      sizes: [track.size],
    );
  }

  // static MediaItem _trackMediaItem(Track track, Uri uri, Map headers) {
  //   final coverUri = track.image;
  //   return MediaItem(
  //     id: uri.toString(),
  //     album: track.release,
  //     title: track.title,
  //     artist: track.artist,
  //     artUri: coverUri,
  //     extras: {'headers': headers},
  //   );
  // }

  static MediaItem _entryMediaItem(
      Entry entry, Uri uri, Map headers, MediaType mediaType) {
    return MediaItem(
      id: uri.toString(),
      album: entry.album,
      title: entry.title,
      artist: entry.creator,
      artUri: Uri.parse(entry.image),
      extras: {
        ExtraLocation: entry.location,
        ExtraHeaders: headers,
        ExtraMediaType: mediaType.name,
        ExtraETag: entry.etag,
        ExtraKey: entry.key,
      },
    );
  }

  static Future<List<MediaItem>> _createQueue(
      Client client, Spiff spiff) async {
    final items = <MediaItem>[];
    // streams shouldn't send the cookie header
    final headers =
        spiff.isStream() ? <String, String>{} : await client.headers();
    for (var t in spiff.playlist.tracks) {
      final uri = await client.locate(t);
      items.add(_entryMediaItem(t, uri, headers, spiff.mediaType));
    }
    return items;
  }
}

class MediaState {
  static final log = Logger('MediaState');

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
  MediaItem? item(int index) {
    return index < length ? _queue[index] : null;
  }

  /// add item to queue
  void add(MediaItem item) {
    _queue.add(item);
  }

  /// find item with id
  MediaItem findId(String id) {
    return _queue.where((item) => item.id == id).first;
  }

  /// find item
  int findItem(MediaItem target) {
    return _queue.indexWhere((item) => item == target);
  }

  /// update current index and position in playlist
  /// only call from player task
  Future<Spiff> update(int index, double position) async {
    log.fine('spiff update $index $position');
    _index = index;
    _position = position;
    return MediaQueue.update(_spiff, index: index, position: position);
  }
}
