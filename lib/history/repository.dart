import 'dart:io';

import 'package:takeout_app/model.dart';
import 'package:takeout_app/spiff/model.dart';

import 'provider.dart';
import 'model.dart';

class HistoryRepository {
  final Directory directory;
  final HistoryProvider _provider;

  HistoryRepository({required this.directory, HistoryProvider? provider})
      : _provider = provider ?? JsonHistoryProvider(directory);

  Future<History> get() async {
    return _provider.get();
  }

  Future<History> add({String? search, Spiff? spiff, MediaTrack? track}) async {
    return _provider.add(search: search, spiff: spiff, track: track);
  }

  Future<History> remove() async {
    return _provider.remove();
  }
}
