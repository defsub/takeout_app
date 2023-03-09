import 'dart:io';

import 'package:bloc/bloc.dart';

import 'file.dart';
import 'track_repository.dart';

class TrackCacheState extends FileCacheState {
  TrackCacheState(super.keys);

  factory TrackCacheState.empty() {
    return TrackCacheState(<String>{});
  }
}

class TrackCacheCubit extends Cubit<TrackCacheState> {
  final TrackCacheRepository repository;

  TrackCacheCubit(this.repository) : super(TrackCacheState.empty()) {
    _emitState();
  }

  void _emitState() async {
    final keys = await repository.keys();
    emit(TrackCacheState(Set<String>.from(keys)));
  }

  void add(TrackIdentifier id, File file) async {
    repository.put(id, file).whenComplete(() => _emitState());
  }

  void remove(TrackIdentifier id) async {
    repository.remove(id).whenComplete(() => _emitState());
  }

  void retain(Iterable<TrackIdentifier> ids) async {
    repository.retain(ids).whenComplete(() => _emitState());
  }
}