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
