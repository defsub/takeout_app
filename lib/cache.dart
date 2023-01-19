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
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:path/path.dart';
import 'package:logging/logging.dart';

import 'client.dart';
import 'spiff.dart';
import 'schema.dart';

final _emptyDownloaded = Set<String>.unmodifiable([]);
final _emptyOffsets = Map<String, Offset>.unmodifiable({});
final _emptyDownloading = Map<String, DownloadSnapshot>.unmodifiable({});

class CacheSnapshot {
  final Set<String> downloaded;
  final Map<String, Offset> offsets;
  final Map<String, DownloadSnapshot> downloading;

  const CacheSnapshot(this.downloaded, this.offsets, this.downloading);

  factory CacheSnapshot.empty() =>
      CacheSnapshot(_emptyDownloaded, _emptyOffsets, _emptyDownloading);

  bool containsAll(Iterable<Locatable> entries) {
    final entryKeys = Set<String>();
    entries.forEach((e) => entryKeys.add(e.key));
    return downloaded.containsAll(entryKeys);
  }

  bool containsAny(Iterable<Locatable> entries) {
    final entryKeys = Set<String>();
    entries.forEach((e) => entryKeys.add(e.key));
    return entryKeys.intersection(downloaded).isNotEmpty;
  }

  bool contains(Locatable l) {
    return downloaded.contains(l.key);
  }

  Duration? duration(Locatable l) {
    final offset = offsets[l.key];
    return offset != null && offset.hasDuration()
        ? Duration(seconds: offset.duration)
        : null;
  }

  Duration? position(Locatable l) {
    final offset = offsets[l.key];
    return offset != null ? offset.position() : null;
  }

  Duration? remaining(Locatable l) {
    final offset = offsets[l.key];
    return offset != null
        ? Duration(seconds: offset.duration - offset.offset)
        : null;
  }

  DateTime? when(Locatable l) {
    final offset = offsets[l.key];
    return offset != null ? offset.dateTime : null;
  }

  double? value(Locatable l) {
    final offset = offsets[l.key];
    final pos = offset?.offset ?? null;
    final end = offset?.duration;
    if (pos != null && end != null) {
      final value = pos.toDouble() / end.toDouble();
      return value;
    }
    return null;
  }

  bool isDownloading(Locatable l) {
    return downloading.containsKey(l.key);
  }

  DownloadSnapshot? downloadSnapshot(Locatable l) {
    return downloading[l.key];
  }

  DownloadSnapshot fold() {
    return downloading.values.fold<DownloadSnapshot>(
        DownloadSnapshot(0, 0),
        (total, e) =>
            DownloadSnapshot(total.size + e.size, total.offset + e.offset));
  }
}

class MediaCache {
  static final _cachedMediaStream =
      BehaviorSubject<Set<String>>.seeded(_emptyDownloaded);
  static final _cachedOffsetsStream =
      BehaviorSubject<Map<String, Offset>>.seeded(_emptyOffsets);

  static void _updateMedia(Set<String> media) {
    _cachedMediaStream.add(media);
  }

  static void _updateOffsets(Map<String, Offset> offsets) {
    _cachedOffsetsStream.add(offsets);
  }

  static Stream<CacheSnapshot> stream() {
    return Rx.combineLatest3(
        _cachedMediaStream.stream,
        _cachedOffsetsStream.stream,
        Client.downloadStream.stream,
        (Set<String>? media, Map<String, Offset>? offsets,
                Map<String, DownloadSnapshot>? downloading) =>
            CacheSnapshot(media ?? _emptyDownloaded, offsets ?? _emptyOffsets,
                downloading ?? _emptyDownloading));
  }
}

Future<Directory> checkAppDir(String name) async {
  final docDir = await getApplicationDocumentsDirectory();
  final dir = Directory('${docDir.path}/$name');
  final completer = Completer<Directory>();
  dir.exists().then((exists) {
    if (!exists) {
      dir
          .create()
          .then((created) => completer.complete(dir))
          .catchError((e) => completer.completeError(e));
    } else {
      completer.complete(dir);
    }
  });
  return completer.future;
}

class JsonCacheResult {
  final bool exists;

  JsonCacheResult(this.exists);

  factory JsonCacheResult.NotFound() => JsonCacheResult(false);
}

class JsonCacheEntry extends JsonCacheResult {
  final String uri;
  final File file;
  final DateTime lastModified;
  final bool expired;

  JsonCacheEntry(this.uri, this.file, this.lastModified, this.expired)
      : super(true);
}

class JsonCache {
  static final log = Logger('JsonCache');
  static const _dir = 'api_cache';

  String _md5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  Future<File> _jsonFile(String uri) async {
    return await checkAppDir(_dir).then((dir) {
      final key = _md5(uri);
      final path = '${dir.path}/$key.json';
      return File(path);
    });
  }

  Future<void> put(String uri, Uint8List body) async {
    final completer = Completer<dynamic>();
    final file = await _jsonFile(uri);
    file.writeAsBytes(body).then((f) {
      completer.complete();
    }).catchError((e) {
      log.warning(e);
      completer.completeError(e);
    });
    return completer.future;
  }

  Future<JsonCacheResult> get(String uri, {Duration? ttl}) async {
    final completer = Completer<JsonCacheResult>();
    final file = await _jsonFile(uri);
    file.exists().then((exists) {
      if (exists) {
        final lastModified = file.lastModifiedSync();
        if (ttl != null) {
          final expirationTime = lastModified.add(ttl);
          final expired = DateTime.now().isAfter(expirationTime);
          final result = JsonCacheEntry(uri, file, lastModified, expired);
          completer.complete(result);
        } else {
          // no ttl, send file
          completer.complete(JsonCacheEntry(uri, file, lastModified, false));
        }
      } else {
        completer.complete(JsonCacheResult.NotFound());
      }
    });
    return completer.future;
  }
}

class TrackCache {
  static const _dir = 'track_cache';
  static final _entries = Map<String, File>();

  static Future<void> init() async {
    final dir = await checkAppDir(_dir);
    final files = await dir.list().toList();
    await Future.forEach(files, (FileSystemEntity file) async {
      // entry keys are etags with any quotes (or other) removed
      _entries[basename(file.path)] = file as File;
    }).whenComplete(() => _publish());
  }

  static void _publish() {
    final keys = Set<String>.from(_entries.keys);
    MediaCache._updateMedia(keys);
  }

  Future<File> _trackFile(Locatable d) async {
    return await checkAppDir(_dir).then((dir) {
      // keys are etags
      final path = '${dir.path}/${d.key}';
      return File(path);
    });
  }

  Set<String> keys() {
    final keys = Set<String>();
    keys.addAll(_entries.keys);
    return keys;
  }

  Future<bool> exists(Locatable d) async {
    final result = await get(d);
    return result is File;
  }

  Future<dynamic> get(Locatable d) async {
    final completer = Completer<dynamic>();
    final file = await _trackFile(d);
    file.exists().then((exists) {
      completer.complete(exists ? file : false);
    });
    return completer.future;
  }

  // Put a (downloaded) file in the cache and publish
  void put(Locatable d, File file) {
    // key should be the etag or similar hash
    _entries[d.key] = file;
    _publish();
  }

  // Create a file that will later be stored in the cache
  Future<File> create(Locatable d) async {
    return await _trackFile(d);
  }

  void remove(Locatable d) {
    _entries.remove(d.key);
    _publish();
  }

  Future<bool> contains(List<Locatable> list) async {
    int count = 0;
    for (var l in list) {
      final result = await get(l);
      if (result is File) {
        count++;
      }
    }
    return list.length == count;
  }

  Future<int> size(Spiff spiff) async {
    int size = 0;
    for (var t in spiff.playlist.tracks) {
      final result = await get(t);
      if (result is File) {
        size += await result.length();
      }
    }
    return size;
  }
}

class SpiffCache {
  static final log = Logger('SpiffCache');
  static const _dir = 'spiff_cache';
  static final Map<Uri, Spiff> _cache = {};

  static Future<File> _cacheFile(Uri uri) async {
    var fileName;
    if (uri.scheme == 'file') {
      // local spiffs
      fileName = 'local.json';
    } else {
      fileName = uri.path
          .replaceAll('/api/', '')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      fileName = '$fileName.json';
    }
    log.fine('$uri -> $fileName');
    return await checkAppDir(_dir).then((dir) {
      return File('${dir.path}/$fileName');
    });
  }

  static Future<File> _save(Uri uri, Spiff spiff) async {
    log.fine('_saving $spiff');
    final completer = Completer<File>();
    File file = await _cacheFile(uri);
    final data = jsonEncode(spiff.toJson());
    file.writeAsString(data).then((f) {
      completer.complete(f);
    }).catchError((e) {
      log.warning(e);
      completer.completeError(e);
    });
    return completer.future;
  }

  static Future<void> put(Spiff spiff) async {
    String? location = spiff.playlist.location;
    if (location == null || location.isEmpty) {
      log.warning('put spiff with null location!');
      return;
    }
    final key = Uri.parse(location);
    final curr = _cache[key];
    log.fine('put ${key.toString()} -> ${spiff.playlist.tracks.length} tracks');
    if (curr != null &&
        spiff == curr &&
        spiff.index == curr.index &&
        spiff.position == curr.position) {
      log.fine('put unchanged');
    } else {
      await _save(key, spiff);
      _cache[key] = spiff;
    }
  }

  static Future<Spiff?> get(Uri uri) async {
    log.fine('get $uri -> ${_cache[uri]}');
    return _cache[uri];
  }

  static Future<Spiff> load(Uri uri) async {
    log.fine('loading ${uri.toString()}');
    final file = await _cacheFile(uri);
    final spiff = await Spiff.fromFile(file);
    log.fine(
        'loaded ${spiff.playlist.title} with ${spiff.playlist.tracks.length} tracks');
    await put(spiff);
    return spiff;
  }
}

class OffsetCache {
  static final log = Logger('SpiffCache');
  static const _dir = 'offset_cache';

  static Map<String, Offset> _entries = {};

  static Future<File> _cacheFile(String etag) async {
    // ensure no weird chars
    var fileName = etag.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    fileName = '$fileName.json';
    return await checkAppDir(_dir).then((dir) {
      return File('${dir.path}/$fileName');
    });
  }

  static Offset? _decode(File file) {
    try {
      return Offset.fromJson(jsonDecode(file.readAsStringSync()));
    } on FormatException {
      log.warning(
          '_decode failed to parse $file with "${file.readAsStringSync()}"');
      return null;
    }
  }

  static void _publish() {
    MediaCache._updateOffsets(UnmodifiableMapView(_entries));
  }

  static Future<File> _save(Offset offset) async {
    final completer = Completer<File>();
    File file = await _cacheFile(offset.etag);
    final data = jsonEncode(offset.toJson());
    file.writeAsString(data).then((f) {
      completer.complete(f);
    }).catchError((e) {
      log.warning(e);
      completer.completeError(e);
    });
    return completer.future;
  }

  // Init populates the cache from storage.
  static Future<void> init() async {
    _entries.clear();
    final dir = await checkAppDir(_dir);
    final files = await dir.list().toList();
    await Future.forEach(files, (FileSystemEntity file) async {
      final offset = _decode(file as File);
      if (offset != null) {
        put(offset);
      } else {
        // corrupt? delete it
        log.warning('offset deleting $file');
        file.deleteSync();
      }
    });
  }

  // Merge obtains the latest progress from the server and updates any newer
  // local progress as needed.
  static Future merge(Client client) async {
    final view = await client.progress(ttl: Duration.zero);
    final update = <Offset>[];
    await Future.forEach(view.offsets, (Offset remote) async {
      final local = await get(remote.etag);
      if (local != null && local.newerThan(remote)) {
        // update the server
        update.add(local);
      } else {
        // update from server
        await put(remote);
      }
    });
    if (update.isNotEmpty) {
      log.fine('updating progress with ${update.length} offsets');
      await client.updateProgress(Offsets(offsets: update));
    } else {
      log.fine('no progress to update');
    }
  }

  static Future<Offset?> get(String etag, {Duration? ttl}) async {
    final completer = Completer<Offset?>();
    final file = await _cacheFile(etag);
    file.exists().then((exists) {
      if (exists) {
        final lastModified = file.lastModifiedSync();
        if (ttl != null) {
          final expirationTime = lastModified.add(ttl);
          final expired = DateTime.now().isAfter(expirationTime);
          completer.complete(expired ? null : _decode(file));
          if (expired) {
            log.fine('deleting $file');
            remove(etag);
          }
        } else {
          completer.complete(_decode(file));
        }
      } else {
        completer.complete(null);
      }
    });
    return completer.future;
  }

  static Future remove(String etag) async {
    if (_entries.containsKey(etag) == false) {
      // optimize this case
      return;
    }

    _entries.remove(etag);
    _publish();
    final file = await _cacheFile(etag);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  static Future removeAll() async {
    return Future.forEach<String>(_entries.keys, (etag) async {
      await remove(etag);
    });
  }

  static Future put(Offset offset) async {
    final curr = _entries[offset.etag];
    if (curr != null && curr.hasDuration() && offset.duration == 0) {
      // duration is dynamic so don't zero out previously found duration
      offset = offset.copyWith(duration: curr.duration);
    }
    _entries[offset.etag] = offset;
    _publish();
    return _save(offset);
  }
}
