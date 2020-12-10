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

  Future<dynamic> get(String uri, {Duration ttl}) async {
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

  Future<File> _trackFile(Locatable d) async {
    return await checkAppDir(_dir).then((dir) {
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
      if (exists) {
        completer.complete(file);
      } else {
        completer.complete(false);
      }
    });
    return completer.future;
  }

  Future<IOSink> put(Locatable d) async {
    final file = await _trackFile(d);
    return file.openWrite();
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
  static const _defaultName = 'playlist';
  static final Map<Uri, Spiff> _cache = {};

  static Future<File> _cacheFile(Uri uri) async {
    var fileName;
    final location = uri.toString();
    if (location.endsWith('/api/playlist')) {
      fileName = 'playlist.json';
    } else {
      final regexp = RegExp(r'.*/api/([a-z]+)/([0-9]+)');
      final matches = regexp.allMatches(location);
      if (matches.isNotEmpty) {
        final match = matches.elementAt(0);
        fileName = '${match.group(1)}_${match.group(2)}.json';
      }
    }
    if (fileName == null) {
      fileName = '$_defaultName.json';
    }

    print('_cacheFile $location -> $fileName');

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
    final key = Uri.parse(spiff.playlist.location);
    if (spiff.isRemote()) {
      await _save(key, spiff);
    } else {
      print('XXX dont put ${spiff.playlist.location}');
    }
    print('put ${key.toString()} -> $spiff, ${key.hashCode}, ${spiff.playlist.tracks.length} tracks');
    _cache[key] = spiff;
  }

  static Future<Spiff> get(Uri uri) async {
    // TODO more?
    print('get $uri -> ${_cache[uri]}, ${uri.hashCode}');
    return _cache[uri];
  }

  static Future<Spiff> load(Uri uri) async {
    print('load ${uri.toString()}');
    File file;
    if (uri.scheme == 'file') {
      file = File.fromUri(uri);
    } else {
      file = await _cacheFile(uri);
    }
    print('file is $file');
    final spiff = await Spiff.fromFile(file);
    print('spiff ${spiff.playlist.title} ${spiff.playlist.tracks.length}');
    if (spiff.isRemote()) {
      await put(spiff);
    }
    return spiff;
  }

  static Future<List<Spiff>> entries() async {
    final list = _cache.values.toList();
    list.sort((a, b) => a.playlist.title.compareTo(b.playlist.title));
    return list;
  }
}

