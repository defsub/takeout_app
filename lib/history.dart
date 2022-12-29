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
import 'spiff.dart';

part 'history.g.dart';

@JsonSerializable(fieldRename: FieldRename.pascal)
class History {
  final List<SearchHistory> searches;
  final List<SpiffHistory> spiffs;
  late File _file;

  static final _subject = BehaviorSubject<History>();
  static ValueStream<History> get stream => _subject.stream;
  static History? _instance;

  static Future<History> get instance async => _instance ??= await History.load();

  History({this.searches = const [], this.spiffs = const []});

  History _copy() =>
      History(
        searches: List.from(this.searches),
        spiffs: List.from(this.spiffs)
      );

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
      final history = History(spiffs: [], searches: []);
      history._file = file;
      return history;
    }
  }

  static Future<History> _load(File file) async {
    final json = await file.readAsBytes().then((body) =>
        jsonDecode(utf8.decode(body)));
    final history = History.fromJson(json);
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
    final max = 25;
    if (searches.length > max) {
      searches.removeRange(0, searches.length - max);
    }
    if (spiffs.length > max) {
      spiffs.removeRange(0, spiffs.length - max);
    }
  }

  Future delete() async {
    searches.clear();
    spiffs.clear();
    await save();
    _share();
  }

  Future save() async {
    return _save(_file);
  }

  Future _save(File file) async {
    final completer = Completer();
    final data = jsonEncode(toJson());
    file.writeAsString(data).then((f) {
      completer.complete();
    }).catchError((e) {
      completer.completeError(e);
    });
    return completer;
  }

  void add({String? search, Spiff? spiff}) {
    if (search != null) {
      searches.add(SearchHistory(search, DateTime.now()));
    }
    if (spiff != null) {
      if (spiff.playlist.creator == null) {
        final playlist = spiff.playlist.copyWith(creator: playlistCreator(spiff));
        spiff = spiff.copyWith(playlist: playlist);
      }
      if (spiff.playlist.title.isEmpty) {
        final playlist = spiff.playlist.copyWith(title: playlistTitle(spiff));
        spiff = spiff.copyWith(playlist: playlist);
      }
      spiffs.add(SpiffHistory(spiff, DateTime.now()));
    }
    _prune();
    _share();
    Future.delayed(Duration(seconds: 1), () {
      save();
    });
  }
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class SearchHistory {
  final String search;
  final DateTime dateTime;

  SearchHistory(this.search, this.dateTime);

  factory SearchHistory.fromJson(Map<String, dynamic> json) =>
      _$SearchHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$SearchHistoryToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class SpiffHistory {
  final Spiff spiff;
  final DateTime dateTime;

  SpiffHistory(this.spiff, this.dateTime);

  factory SpiffHistory.fromJson(Map<String, dynamic> json) =>
      _$SpiffHistoryFromJson(json);

  Map<String, dynamic> toJson() => _$SpiffHistoryToJson(this);
}
