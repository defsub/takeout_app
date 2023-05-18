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

import 'file_provider.dart';

class FileCacheRepository {
  final Directory directory;
  final FileCacheProvider _cache;

  FileCacheRepository({required this.directory, FileCacheProvider? cache})
      : _cache = cache ?? DirectoryFileCache(directory: directory);

  Future<File?> get(FileIdentifier id) async {
    return _cache.get(id);
  }

  Future<void> put(FileIdentifier id, File file) async {
    return _cache.put(id, file);
  }

  Future<void> remove(FileIdentifier id, {bool delete = true}) async {
    return _cache.remove(id, delete: delete);
  }

  Future<void> removeAll() {
    return _cache.removeAll();
  }

  File create(FileIdentifier id) {
    return _cache.create(id);
  }

  Future<bool> contains(FileIdentifier id) async {
    return _cache.contains(id);
  }

  Future<bool> containsAll(List<FileIdentifier> ids) async {
    int count = 0;
    for (final id in ids) {
      final result = await get(id);
      if (result is File) {
        count++;
      }
    }
    return ids.length == count;
  }

  Future<int> size(Iterable<FileIdentifier> ids) async {
    int size = 0;
    for (final id in ids) {
      final file = await get(id);
      if (file is File) {
        size += file.lengthSync();
      }
    }
    return size;
  }

  Future<void> retain(Iterable<FileIdentifier> ids) async {
    return _cache.retain(ids);
  }

  Future<Iterable<String>> keys() async {
    return _cache.keys();
  }
}
