import 'dart:io';
import 'dart:convert';

import 'package:takeout_app/model.dart';
import 'package:takeout_app/spiff/model.dart';
import 'model.dart';

abstract class HistoryProvider {
  Future<History> add({String? search, Spiff? spiff, MediaTrack? track});

  Future<History> get();

  Future<History> remove();
}

class JsonHistoryProvider implements HistoryProvider {
  final Directory directory;
  final File _file;
  History? _history;

  JsonHistoryProvider(this.directory)
      : _file = File('${directory.path}/history.json');

  Future<History> add({String? search, Spiff? spiff, MediaTrack? track}) async {
    final history = await _checkLoaded();
    if (search != null) {
      // append search or merge duplicate
      final entry = SearchHistory(search, DateTime.now());
      if (history.searches.isNotEmpty &&
          history.searches.last.compareTo(entry) == 0) {
        history.searches.removeLast();
      }
      history.searches.add(entry);
    }
    if (spiff != null) {
      // append spiff or merge duplicate
      final entry = SpiffHistory(spiff, DateTime.now());
      if (history.spiffs.isNotEmpty &&
          history.spiffs.last.compareTo(entry) == 0) {
        history.spiffs.removeLast();
      }
      history.spiffs.add(entry);
    }
    if (track != null) {
      // maintain map of unique tracks by etag with play counts
      final entry = history.tracks[track.etag];
      history.tracks[track.etag] = entry == null
          ? history.tracks[track.etag] = TrackHistory(
              track.creator,
              track.album,
              track.title,
              track.image,
              track.etag,
              1,
              DateTime.now())
          : history.tracks[track.etag] =
              entry.copyWith(count: entry.count + 1, dateTime: DateTime.now());
    }
    _prune(history);
    _save(_file, history);
    return history;
  }

  Future<History> get() async {
    return _checkLoaded();
  }

  Future<History> _checkLoaded() async {
    if (_history == null) {
      _history = await _load(_file);
    }
    return Future.value(_history);
  }

  Future<History> _load(File file) async {
    if (file.existsSync() == false) {
      return History(spiffs: [], searches: [], tracks: {});
    }

    final json =
        await file.readAsBytes().then((body) => jsonDecode(utf8.decode(body)));
    if (json is Map<String, dynamic>) {
      // Allow for older version w/o tracks
      if (json.containsKey('Tracks') == false) {
        json['Tracks'] = <String, TrackHistory>{};
      }
    }

    final history = History.fromJson(json);
    // load with oldest first
    history.searches.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    history.spiffs.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return history;
  }

  static const maxSearchHistory = 25;
  static const maxSpiffHistory = 25;
  static const maxTrackHistory = 100;

  void _prune(History history) {
    if (history.searches.length > maxSearchHistory) {
      // remove oldest first
      history.searches
          .removeRange(0, history.searches.length - maxSearchHistory);
    }
    if (history.spiffs.length > maxSpiffHistory) {
      // remove oldest first
      history.spiffs.removeRange(0, history.spiffs.length - maxSpiffHistory);
    }
    if (history.tracks.length > maxTrackHistory) {
      // remove oldest first
      final oldest = history.tracks.values
          .reduce((a, b) => a.dateTime.isBefore(b.dateTime) ? a : b);
      history.tracks.remove(oldest.etag);
    }
  }

  Future _save(File file, History history) async {
    final data = jsonEncode(history.toJson());
    try {
      await file.writeAsString(data);
    } catch (e) {
      return Future.error(e);
    }
  }

  Future<History> remove() async {
    final history = await _checkLoaded();
    history.searches.clear();
    history.spiffs.clear();
    history.tracks.clear();
    await _save(_file, history);
    return history;
  }
}
