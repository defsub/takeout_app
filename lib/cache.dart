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
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:path/path.dart';

import 'client.dart';
import 'spiff.dart';

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

class JsonCache {
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
      print(e);
      completer.completeError(e);
    });
    return completer.future;
  }

  Future<dynamic> get(String uri, {Duration? ttl}) async {
    final completer = Completer<dynamic>();
    final file = await _jsonFile(uri);
    file.exists().then((exists) {
      if (exists) {
        final lastModified = file.lastModifiedSync();
        if (ttl != null) {
          final expirationTime = lastModified.add(ttl);
          final expired = DateTime.now().isAfter(expirationTime);
          completer.complete(expired ? false : file);
          if (expired) {
            print("deleting $file");
            file.delete(); // delete async
          }
        } else {
          // no ttl, send file
          completer.complete(file);
        }
      } else {
        completer.complete(false);
      }
    });
    return completer.future;
  }
}

class TrackCache {
  static const _dir = 'track_cache';
  static final keysSubject = BehaviorSubject<Set<String>>();
  static final _entries = Map<String, File>();

  static void init() async {
    final dir = await checkAppDir(_dir);
    final files = await dir.list().toList();
    await Future.forEach(files, (FileSystemEntity file) async {
      // entry keys are etags
      _entries[basename(file.path)] = file as File;
    }).whenComplete(() => _broadcast());
  }

  static bool checkAll(Set<String> cacheKeys, Iterable<Locatable> entries) {
    final entryKeys = Set<String>();
    entries.forEach((e) => entryKeys.add(e.key));
    return cacheKeys.containsAll(entryKeys);
  }

  static void _broadcast() {
    final keys = Set<String>.from(_entries.keys);
    keysSubject.add(keys);
  }

  Future<File> _trackFile(Locatable d) async {
    return await checkAppDir(_dir).then((dir) {
      // keys are etags
      final path = '${dir.path}/${d.key}';
      return File(path);
    });
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
    // key should be the etag
    _entries[d.key] = file;
    _broadcast();
  }

  // Create a file that will later be stored in the cache
  Future<File> create(Locatable d) async {
    return await _trackFile(d);
  }

  void remove(Locatable d) {
    _entries.remove(d.key);
    _broadcast();
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
    print('$uri -> $fileName');
    return await checkAppDir(_dir).then((dir) {
      return File('${dir.path}/$fileName');
    });
  }

  static Future<File> _save(Uri uri, Spiff spiff) async {
    print('_saving $spiff');
    final completer = Completer<File>();
    File file = await _cacheFile(uri);
    final data = jsonEncode(spiff.toJson());
    file.writeAsString(data).then((f) {
      completer.complete(f);
    }).catchError((e) {
      print(e);
      completer.completeError(e);
    });
    return completer.future;
  }

  static Future<void> put(Spiff spiff) async {
    String? location = spiff.playlist.location;
    if (location == null || location.isEmpty) {
      print('put spiff with null location!');
      return;
    }
    final key = Uri.parse(location);
    final curr = _cache[key];
    print('put ${key.toString()} -> ${spiff.playlist.tracks.length} tracks');
    if (curr != null && spiff == curr && spiff.index == curr.index) {
      // TODO check if Spiff == is good enough
      // TODO position changes aren't saved right now
      print('put unchanged');
    } else {
      await _save(key, spiff);
      _cache[key] = spiff;
    }
  }

  static Future<Spiff?> get(Uri uri) async {
    print('get $uri -> ${_cache[uri]}');
    return _cache[uri];
  }

  static Future<Spiff> load(Uri uri) async {
    print('loading ${uri.toString()}');
    final file = await _cacheFile(uri);
    final spiff = await Spiff.fromFile(file);
    print(
        'loaded ${spiff.playlist.title} with ${spiff.playlist.tracks.length} tracks');
    await put(spiff);
    return spiff;
  }
}
