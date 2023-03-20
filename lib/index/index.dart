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
import 'package:takeout_app/client/repository.dart';

class IndexState {
  final bool movies;
  final bool music;
  final bool podcasts;

  IndexState(
      {required this.movies, required this.music, required this.podcasts});

  factory IndexState.initial() =>
      IndexState(movies: false, music: false, podcasts: false);
}

class IndexCubit extends Cubit<IndexState> {
  final ClientRepository clientRepository;

  IndexCubit(this.clientRepository) : super(IndexState.initial()) {
    _load();
  }

  void _load({Duration? ttl}) {
    clientRepository.index(ttl: ttl).then((view) {
      emit(IndexState(
          movies: view.hasMovies,
          music: view.hasMusic,
          podcasts: view.hasPodcasts));
    }).onError((error, stackTrace) {
      Future.delayed(Duration(minutes: 3), () => _load());
    });
  }

  void reload() {
    _load(ttl: Duration.zero);
  }
}
