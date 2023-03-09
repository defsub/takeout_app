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
import 'package:path/path.dart';

abstract class FileIdentifier {
  String get key;
}

abstract class FileCacheProvider {
  Future<File?> get(FileIdentifier id);

  Future<bool> contains(FileIdentifier id);

  Future put(FileIdentifier id, File file);

  Future remove(FileIdentifier id, {bool delete = true});

  File create(FileIdentifier id);

  Future retain(Iterable<FileIdentifier> ids);

  Future<Iterable<String>> keys();
}

class DirectoryFileCache implements FileCacheProvider {
  final Directory directory;
  final Map<String, File> _entries = {};
  bool _initialized = false;

  DirectoryFileCache({required this.directory});

  Future _checkInitialized() async {
    if (_initialized) {
      return;
    }
    final files = await directory.list().toList();
    return Future.forEach(files, (FileSystemEntity entity) async {
      // entry keys are file names
      _entries[basename(entity.path)] = entity as File;
    }).whenComplete(() {
      _initialized = true;
    });
  }

  File _toFile(FileIdentifier id) {
    return File('${directory.path}/${id.key}');
  }

  @override
  Future<bool> contains(FileIdentifier id) async {
    final file = await get(id);
    return file is File && file.existsSync();
  }

  @override
  Future<File?> get(FileIdentifier id) async {
    await _checkInitialized();
    final file = _toFile(id);
    return file.exists().then((exists) {
      return exists ? file : null;
    });
  }

  @override
  Future put(FileIdentifier id, File file) async {
    await _checkInitialized();
    // key should be the cleaned etag or similar hash
    _entries[id.key] = file;
  }

  // Create a file that will later be stored in the cache
  @override
  File create(FileIdentifier id) {
    return _toFile(id);
  }

  @override
  Future remove(FileIdentifier id, {bool delete = true}) async {
    final file = await get(id);
    if (file != null) {
      _remove(id.key, delete: delete);
    }
  }

  Future _remove(String key, {bool delete = true}) async {
    final file = _entries.remove(key);
    if (delete) {
      await file?.delete();
    }
  }

  @override
  Future retain(Iterable<FileIdentifier> keep) async {
    final removal = Set<String>.from(_entries.keys);
    keep.forEach((e) => removal.remove(e.key));
    return Future.forEach(removal, (String key) async {
      _remove(key, delete: true);
    });
  }

  @override
  Future<Iterable<String>> keys() async {
    await _checkInitialized();
    return _entries.keys;
  }
}
