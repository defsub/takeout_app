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

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'client.dart';
import 'spiff.dart';

Future<Directory> _checkDir(Directory dir) {
  final completer = Completer<Directory>();
  dir.exists().then((exists) {
    if (!exists) {
      dir.create()
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
    var dir = await getApplicationDocumentsDirectory();
    return await _checkDir(Directory('${dir.path}/$_dir')).then((dir) {
      final key = _md5(uri);
      final path = '${dir.path}/$key.json';
      return File(path);
    });
  }

  Future<void> put(String uri, String body) async {
    final completer = Completer<dynamic>();
    final file = await _jsonFile(uri);
    file.writeAsString(body).then((f) {
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
    var dir = await getApplicationDocumentsDirectory();
    return await _checkDir(Directory('${dir.path}/$_dir')).then((dir) {
      final path = '${dir.path}/${d.key}';
      return File(path);
    });
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

  Future<void> _fetchPlaylist(Spiff spiff) async {
    for (var entry in spiff.playlist.tracks) {
      await get(entry);
    }
  }
}
