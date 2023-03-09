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

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'provider.dart';
import 'repository.dart';

class ConnectivityState {
  final ConnectivityType type;

  ConnectivityState(this.type);

  bool get wifi => type == ConnectivityType.wifi;

  bool get mobile => type == ConnectivityType.mobile;

  bool get ethernet => type == ConnectivityType.ethernet;

  bool get none => type == ConnectivityType.none;

  bool get any =>
      type == ConnectivityType.wifi ||
      type == ConnectivityType.mobile ||
      type == ConnectivityType.ethernet;
}

class ConnectivityCubit extends Cubit<ConnectivityState> {
  final ConnectivityRepository repository;
  StreamSubscription<ConnectivityType>? _subscription;

  ConnectivityCubit(this.repository)
      : super(ConnectivityState(ConnectivityType.none)) {
    _init();
  }

  void _init() {
    _subscription =
        repository.stream.listen((event) => emit(ConnectivityState(event)));
    repository.check();
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }

  void check() async {
    await repository.check().then((type) => emit(ConnectivityState(type)));
  }
}
