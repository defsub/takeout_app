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

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:bloc/bloc.dart';

import 'package:takeout_app/spiff/model.dart';

class SpiffCacheState {
  final Iterable<Spiff>? spiffs;

  SpiffCacheState(this.spiffs);

  factory SpiffCacheState.empty() => SpiffCacheState([]);

  bool contains(Spiff spiff) {
    return spiffs?.contains(spiff) ?? false;
  }
}

class SpiffCacheCubit extends Cubit<SpiffCacheState> {
  final SpiffCacheRepository repository;

  SpiffCacheCubit(this.repository) : super(SpiffCacheState.empty()) {
    _emitState();
  }

  void _emitState() async {
    emit(SpiffCacheState(await repository.entries));
  }

  void add(Spiff spiff) async {
    repository.add(spiff).whenComplete(() => _emitState());
  }

  void remove(Spiff spiff) async {
    repository.remove(spiff).whenComplete(() => _emitState());
  }

  void removeAll() async {
    repository.removeAll().whenComplete(() => _emitState());
  }
}

class SpiffCacheRepository {
  final Directory directory;
  final SpiffCache _cache;

  SpiffCacheRepository({required this.directory, SpiffCache? cache})
      : _cache = cache ?? DirectorySpiffCache(directory);

  Future add(Spiff spiff) {
    return _cache.add(spiff);
  }

  Future remove(Spiff spiff) async {
    return _cache.remove(spiff);
  }

  Future removeAll() async {
    return _cache.removeAll();
  }

  Future<Iterable<Spiff>> get entries async => _cache.entries;
}

abstract class SpiffCache {
  Future add(Spiff spiff);

  Future<Iterable<Spiff>> get entries;

  Future remove(Spiff spiff);

  Future removeAll();
}

class DirectorySpiffCache implements SpiffCache {
  static final log = Logger('DirectorySpiffCache');

  final Directory directory;
  final Map<String, Spiff> _cache = {};
  bool _initialized = false;

  DirectorySpiffCache(this.directory) {
    try {
      if (directory.existsSync() == false) {
        directory.createSync(recursive: true);
      }
    } catch (e, stack) {
      log.warning(directory, e, stack);
    }
  }

  Future _checkInitialized() async {
    if (_initialized) {
      return;
    }
    final files = await directory.list().toList();
    return Future.forEach<FileSystemEntity>(files, (file) async {
      final spiff = _decode(file as File);
      if (spiff != null) {
        await _add(spiff);
      } else {
        // corrupt? delete it
        log.warning('spiff deleting $file');
        file.deleteSync();
      }
    }).whenComplete(() {
      _initialized = true;
    });
  }

  Spiff? _decode(File file) {
    try {
      return Spiff.fromJson(jsonDecode(file.readAsStringSync()))
          .copyWith(lastModified: file.lastModifiedSync());
    } on FormatException {
      log.warning(
          '_decode failed to parse $file with "${file.readAsStringSync()}"');
      return null;
    }
  }

  File _cacheFile(String key) {
    return File('${directory.path}/${key}.json');
  }

  String _md5(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  String _cacheKey(Spiff spiff) {
    return _md5('${spiff.title}${spiff.location}${spiff.date}');
  }

  Future<File?> _save(String key, Spiff spiff) async {
    log.fine('_saving $spiff');
    final data = jsonEncode(spiff.toJson());
    try {
      File file = _cacheFile(key);
      await file.writeAsString(data);
      return file;
    } catch (e) {
      log.warning(e);
      return Future.error(e);
    }
  }

  @override
  Future add(Spiff spiff) async {
    await _checkInitialized();
    return _add(spiff);
  }

  Future _add(Spiff spiff) async {
    final key = _cacheKey(spiff);
    final curr = _cache[key];
    log.fine('put ${key.toString()} -> ${spiff.title} with ${spiff.playlist.tracks.length} tracks');
    if (curr != null &&
        spiff == curr &&
        spiff.index == curr.index &&
        spiff.position == curr.position) {
      log.fine('put unchanged');
    } else {
      final file = await _save(key, spiff);
      if (file != null) {
        _cache[key] = spiff;
      }
    }
  }

  @override
  Future<Iterable<Spiff>> get entries async {
    await _checkInitialized();
    return List.unmodifiable(_cache.values);
  }

  @override
  Future remove(Spiff spiff) async {
    await _checkInitialized();
    final key = _cacheKey(spiff);
    _cache.remove(key);
    try {
      _cacheFile(key).deleteSync();
    } catch (e) {
      return Future.error(e);
    }
  }

  @override
  Future removeAll() async {
    await _checkInitialized();
    // copy list to avoid concurrent modification
    final values = List<Spiff>.from(_cache.values);
    return values.forEach((spiff) async {
      await remove(spiff);
    });
  }
}
