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

import 'dart:io';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:takeout_app/api/model.dart';

import 'offset_repository.dart';

extension FileExpiration on File {
  bool isExpired(Duration ttl) {
    final expirationTime = lastModifiedSync().add(ttl);
    return DateTime.now().isAfter(expirationTime);
  }
}

abstract class OffsetCache {
  Future<Offset?> get(OffsetIdentifier id, {Duration? ttl});

  Future put(Offset offset);

  void remove(Offset offset);

  Future<Iterable<Offset>> merge(Iterable<Offset> offsets);

  Future<Map<String, Offset>> entries();
}

class OffsetFileCache implements OffsetCache {
  static final log = Logger('OffsetFileCache');

  final Directory directory; // 'offset_cache'
  final Map<String, Offset> _entries = {};
  bool _initialized = false;

  OffsetFileCache({required this.directory});

  Future _checkInitialized() async {
    if (_initialized) {
      return;
    }
    final files = await directory.list().toList();
    return Future.forEach(files, (FileSystemEntity file) async {
      final offset = _decode(file as File);
      if (offset != null) {
        await put(offset);
      } else {
        // corrupt? delete it
        log.warning('offset deleting $file');
        file.deleteSync();
      }
    }).whenComplete(() {
      _initialized = true;
    });
  }

  File _cacheFile(String key) {
    // ensure no weird chars
    var fileName = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    fileName = '$fileName.json';
    return File('${directory.path}/$fileName');
  }

  Offset? _decode(File file) {
    try {
      return Offset.fromJson(jsonDecode(file.readAsStringSync()));
    } on FormatException {
      log.warning(
          '_decode failed to parse $file with "${file.readAsStringSync()}"');
      return null;
    }
  }

  Future<File> _save(Offset offset) async {
    File file = _cacheFile(offset.key);
    final data = jsonEncode(offset.toJson());
    return file.writeAsString(data);
  }

  @override
  Future<Offset?> get(OffsetIdentifier id, {Duration? ttl}) async {
    await _checkInitialized();
    final file = _cacheFile(id.key);
    return file.exists().then((exists) {
      if (exists) {
        if (ttl != null && file.isExpired(ttl)) {
          log.fine('deleting $file');
          _remove(id.key);
        } else {
          return _decode(file);
        }
      }
      return null;
    });
  }

  @override
  Future put(Offset offset) async {
    await _checkInitialized();
    final curr = _entries[offset.key];
    if (curr != null && curr.hasDuration() && offset.duration == 0) {
      // duration is dynamic so don't zero out previously found duration
      offset = offset.copyWith(duration: curr.duration);
    }
    _entries[offset.key] = offset;
    return _save(offset);
  }

  @override
  Future<Iterable<Offset>> merge(Iterable<Offset> offsets) async {
    final newer = <Offset>[];
    await Future.forEach(offsets, (Offset remote) async {
      final local = await get(remote);
      if (local != null && local.newerThan(remote)) {
        newer.add(local);
      } else {
        await put(remote);
      }
    });
    return newer;
  }

  @override
  void remove(Offset offset) {
    _remove(offset.key);
  }

  void _remove(String key) {
    if (_entries.containsKey(key) == false) {
      return;
    }
    _entries.remove(key);
    final file = _cacheFile(key);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  void removeAll() {
    _entries.keys.forEach((key) => _remove(key));
  }

  @override
  Future<Map<String, Offset>> entries() async {
    await _checkInitialized();
    return Map.unmodifiable(_entries);
  }
}
