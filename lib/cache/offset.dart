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

import 'package:bloc/bloc.dart';

import 'package:takeout_app/api/model.dart';
import 'package:takeout_app/client/repository.dart';

import 'offset_repository.dart';

class OffsetCacheState {
  final Map<String, Offset> offsets;

  OffsetCacheState(this.offsets);

  factory OffsetCacheState.empty() {
    return OffsetCacheState({});
  }

  OffsetCacheState copyWith({Map<String, Offset>? offsets}) =>
      OffsetCacheState(offsets ?? this.offsets);

  bool contains(OffsetIdentifier id) {
    return offsets.containsKey(id.key);
  }

  Offset? get(OffsetIdentifier id) {
    return offsets[id.key];
  }

  Duration? duration(OffsetIdentifier id) {
    final offset = offsets[id.key];
    return offset != null && offset.hasDuration()
        ? Duration(seconds: offset.duration)
        : null;
  }

  Duration? position(OffsetIdentifier id) {
    final offset = offsets[id.key];
    return offset?.position();
  }

  Duration? remaining(OffsetIdentifier id) {
    final offset = offsets[id.key];
    return offset != null
        ? Duration(seconds: offset.duration - offset.offset)
        : null;
  }

  DateTime? when(OffsetIdentifier id) {
    final offset = offsets[id.key];
    return offset?.dateTime;
  }

  double? value(OffsetIdentifier id) {
    final offset = offsets[id.key];
    final pos = offset?.offset ?? null;
    final end = offset?.duration;
    if (pos != null && end != null) {
      final value = pos.toDouble() / end.toDouble();
      return value;
    }
    return null;
  }
}

class OffsetCacheCubit extends Cubit<OffsetCacheState> {
  final OffsetCacheRepository repository;
  final ClientRepository clientRepository;

  OffsetCacheCubit(this.repository, this.clientRepository)
      : super(OffsetCacheState.empty()) {
    _emitState();
  }

  void _emitState() async {
    emit(OffsetCacheState(await repository.entries));
  }

  void add(Offset offset) async {
    repository.put(offset).whenComplete(() => _emitState());
  }

  void remove(Offset offset) {
    repository.remove(offset);
    _emitState();
  }
}
