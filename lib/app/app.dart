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

  // void ready() => emit(AppReady());

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
