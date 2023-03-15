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

enum NavigationIndex { home, artists, history, radio, player }

class AppState {
  final NavigationIndex index;
  final bool authenticated;

  AppState(this.index, this.authenticated);

  factory AppState.initial() => AppState(NavigationIndex.home, false);

  AppState copyWith({NavigationIndex? index, bool? authenticated}) =>
      AppState(index ?? this.index, authenticated ?? this.authenticated);

  int get navigationBarIndex => index.index;
}

class AppCubit extends Cubit<AppState> {
  AppCubit() : super(AppState.initial());

  void authenticated() => emit(state.copyWith(authenticated: true));

  void logout() => emit(state.copyWith(authenticated: false));

  void go(int index) =>
      emit(state.copyWith(index: NavigationIndex.values[index]));

  void home() => emit(state.copyWith(index: NavigationIndex.home));

  void artists() => emit(state.copyWith(index: NavigationIndex.artists));

  // void search() => emit(AppShowSearch());

  void history() => emit(state.copyWith(index: NavigationIndex.history));

  void radio() => emit(state.copyWith(index: NavigationIndex.radio));

  void player() => emit(state.copyWith(index: NavigationIndex.player));

  // void showArtist(String name) => emit(AppShowArtist(name));
  //
  // void showMovie(MediaTrack mediaTrack) => emit(AppShowMovie(mediaTrack));

  void showPlayer() => player();
}
