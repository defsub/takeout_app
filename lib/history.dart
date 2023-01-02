// Copyright (C) 2022 The Takeout Authors.
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
import 'dart:io';
import 'dart:convert';
import 'package:rxdart/rxdart.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';
import 'spiff.dart';
import 'model.dart';

part 'history.g.dart';

@JsonSerializable(fieldRename: FieldRename.pascal)
class History {
  static final log = Logger('History');

  static const maxSearchHistory = 25;
  static const maxSpiffHistory = 25;
  static const maxTrackHistory = 100;

  final int version = 1;
  final List<SearchHistory> searches;
  final List<SpiffHistory> spiffs;
  final Map<String, TrackHistory> tracks;
  late File _file;

  static final _subject = BehaviorSubject<History>();

  static ValueStream<History> get stream => _subject.stream;
  static History? _instance;

  static Future<History> get instance async =>
      _instance ??= await History.load();

  History(
      {this.searches = const [],
      this.spiffs = const [],
      this.tracks = const {}});

  History _copy() => History(
      searches: List.from(this.searches),
      spiffs: List.from(this.spiffs),
      tracks: Map.from(this.tracks));

  factory History.fromJson(Map<String, dynamic> json) =>
      _$HistoryFromJson(json);

  Map<String, dynamic> toJson() => _$HistoryToJson(this);

  static Future<History> load() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/history.json');
    if (file.existsSync()) {
      final history = await _load(file);
      history._share();
      return history;
    } else {
      final history = History(spiffs: [], searches: [], tracks: {});
      history._file = file;
      return history;
    }
  }

  static Future<History> _load(File file) async {
    final json =
        await file.readAsBytes().then((body) => jsonDecode(utf8.decode(body)));
    if (json is Map<String, dynamic>) {
      // Allow for older version w/o tracks
      if (json.containsKey('Tracks') == false) {
        json['Tracks'] = <String, TrackHistory>{};
      }
    }
    final history = History.fromJson(json);
    log.info('version: ${history.version}, searches: ${history.searches.length}, spiffs: ${history.spiffs.length}, tracks: ${history.tracks.length}');
    history._file = file;
    // load with oldest first
    history.searches.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    history.spiffs.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return history;
  }

  void _share() {
    _subject.add(_copy());
  }

  void _prune() {
    if (searches.length > maxSearchHistory) {
      // remove oldest first
      searches.removeRange(0, searches.length - maxSearchHistory);
    }
    if (spiffs.length > maxSpiffHistory) {
      // remove oldest first
      spiffs.removeRange(0, spiffs.length - maxSpiffHistory);
    }
    if (tracks.length > maxTrackHistory) {
      // remove oldest first
      final oldest = tracks.values
          .reduce((a, b) => a.dateTime.isBefore(b.dateTime) ? a : b);
      tracks.remove(oldest.etag);
    }
  }

  Future delete() async {
    searches.clear();
    spiffs.clear();
    tracks.clear();
    await save();
    _share();
  }

  Future save() async {
    return _save(_file);
  }

  Future _save(File file) async {
    final completer = Completer();
    // log.fine('searches: ${searches.first.search}..${searches.last.search}');
    // log.fine('spiffs: ${spiffs.first.spiff.title}..${spiffs.last.spiff.title}');
    // if (tracks.isNotEmpty) {
    //   final oldest = tracks.values
    //       .reduce((a, b) => a.dateTime.isBefore(b.dateTime) ? a : b);
    //   final newest = tracks.values
    //       .reduce((a, b) => a.dateTime.isAfter(b.dateTime) ? a : b);
    //   log.fine(
    //       'tracks: ${oldest.title} (${oldest.count})..${newest.title} (${newest
    //           .count})');
    // }

    final data = jsonEncode(toJson());
    file.writeAsString(data).then((f) {
      completer.complete();
    }).catchError((e) {
      completer.completeError(e);
    });
    return completer;
  }

  void add({String? search, Spiff? spiff, Media? track}) {
    if (search != null) {
      // append search or merge duplicate
      final history = SearchHistory(search, DateTime.now());
      if (searches.isNotEmpty && searches.last.compareTo(history) == 0) {
        searches.removeLast();
      }
      searches.add(history);
    }
    if (spiff != null) {
      // append spiff or merge duplicate
      final history = SpiffHistory(spiff, DateTime.now());
      if (spiffs.isNotEmpty && spiffs.last.compareTo(history) == 0) {
        spiffs.removeLast();
      }
      spiffs.add(history);
    }
    if (track != null) {
      // maintain map of unique tracks by etag with play counts
      final entry = tracks[track.etag];
      tracks[track.etag] = entry == null
          ? tracks[track.etag] = TrackHistory(track.creator, track.album,
              track.title, track.image, track.etag, 1, DateTime.now())
          : tracks[track.etag] =
              entry.copyWith(count: entry.count + 1, dateTime: DateTime.now());
    }
    _prune();
    _share();
    Future.delayed(Duration(seconds: 1), () {
      save();
    });
  }
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class SearchHistory implements Comparable<SearchHistory> {
  final String search;
  final DateTime dateTime;

  SearchHistory(this.search, this.dateTime);

  factory SearchHistory.fromJson(Map<String, dynamic> json) =>
      _$SearchHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$SearchHistoryToJson(this);

  @override
  int compareTo(SearchHistory other) {
    return search.compareTo(other.search);
  }
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class SpiffHistory implements Comparable<SpiffHistory> {
  final Spiff spiff;
  final DateTime dateTime;

  SpiffHistory(this.spiff, this.dateTime);

  factory SpiffHistory.fromJson(Map<String, dynamic> json) =>
      _$SpiffHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$SpiffHistoryToJson(this);

  @override
  int compareTo(SpiffHistory other) {
    return spiff == other.spiff ? 0 : dateTime.compareTo(other.dateTime);
  }
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class TrackHistory {
  final String creator;
  final String album;
  final String title;
  final String image;
  final String etag;
  final int count;
  final DateTime dateTime;

  TrackHistory(this.creator, this.album, this.title, this.image, this.etag,
      this.count, this.dateTime);

  factory TrackHistory.fromJson(Map<String, dynamic> json) =>
      _$TrackHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$TrackHistoryToJson(this);

  TrackHistory copyWith({required int count, required DateTime dateTime}) =>
      TrackHistory(this.creator, this.album, this.title, this.image, this.etag,
          count, dateTime);
}
