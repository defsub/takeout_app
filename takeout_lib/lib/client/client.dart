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
import 'package:takeout_lib/api/client.dart';
import 'package:takeout_lib/api/model.dart';
import 'package:takeout_lib/spiff/model.dart';

import 'repository.dart';

class ClientState {}

class ClientReady extends ClientState {}

class ClientLoading extends ClientState {}

class ClientError extends ClientState {
  final Object? error;
  final StackTrace? stackTrace;

  ClientError(this.error, this.stackTrace);
}

class ClientAuthError extends ClientError {
  final int statusCode;

  ClientAuthError(this.statusCode, super.error, super.stackTrace);
}

class ClientResult<T> extends ClientState {
  final T result;

  ClientResult(this.result);
}

typedef ClientRequest<T> = Future<T> Function({Duration? ttl});

class ClientCubit extends Cubit<ClientState> {
  final ClientRepository repository;
  final Duration _timeout;

  ClientCubit(this.repository, {Duration? timeout})
      : _timeout = timeout ?? const Duration(seconds: 10),
        super(ClientReady());

  void login(String user, String password) =>
      _doit<bool>(({Duration? ttl}) => repository.login(user, password),
          ttl: Duration.zero);

  void code() => _doit<AccessCode>(({Duration? ttl}) => repository.code(),
      ttl: Duration.zero);

  void checkCode(AccessCode accessCode) =>
      _doit<bool>(({Duration? ttl}) => repository.checkCode(accessCode),
          ttl: Duration.zero);

  void artists({Duration? ttl}) =>
      _doit<ArtistsView>(({Duration? ttl}) => repository.artists(ttl: ttl),
          ttl: ttl);

  void artist(int id, {Duration? ttl}) =>
      _doit<ArtistView>(({Duration? ttl}) => repository.artist(id, ttl: ttl),
          ttl: ttl);

  void artistPlaylist(int id, {Duration? ttl}) =>
      _doit<Spiff>(({Duration? ttl}) => repository.artistPlaylist(id, ttl: ttl),
          ttl: ttl);

  void artistPopular(int id, {Duration? ttl}) => _doit<PopularView>(
      ({Duration? ttl}) => repository.artistPopular(id, ttl: ttl),
      ttl: ttl);

  void artistPopularPlaylist(int id, {Duration? ttl}) => _doit<Spiff>(
      ({Duration? ttl}) => repository.artistPopularPlaylist(id, ttl: ttl),
      ttl: ttl);

  void artistSingles(int id, {Duration? ttl}) => _doit<SinglesView>(
      ({Duration? ttl}) => repository.artistSingles(id, ttl: ttl),
      ttl: ttl);

  void artistSinglesPlaylist(int id, {Duration? ttl}) => _doit<Spiff>(
      ({Duration? ttl}) => repository.artistSinglesPlaylist(id, ttl: ttl),
      ttl: ttl);

  void artistRadio(int id, {Duration? ttl}) =>
      _doit<Spiff>(({Duration? ttl}) => repository.artistRadio(id, ttl: ttl),
          ttl: ttl);

  void artistWantList(int id, {Duration? ttl}) => _doit<WantListView>(
      ({Duration? ttl}) => repository.artistWantList(id, ttl: ttl),
      ttl: ttl);

  void movie(int id, {Duration? ttl}) =>
      _doit<MovieView>(({Duration? ttl}) => repository.movie(id, ttl: ttl),
          ttl: ttl);

  void moviePlaylist(int id, {Duration? ttl}) =>
      _doit<Spiff>(({Duration? ttl}) => repository.moviePlaylist(id, ttl: ttl),
          ttl: ttl);

  void moviesGenre(String genre, {Duration? ttl}) => _doit<GenreView>(
      ({Duration? ttl}) => repository.moviesGenre(genre, ttl: ttl),
      ttl: ttl);

  void profile(int id, {Duration? ttl}) =>
      _doit<ProfileView>(({Duration? ttl}) => repository.profile(id, ttl: ttl),
          ttl: ttl);

  void radio({Duration? ttl}) =>
      _doit<RadioView>(({Duration? ttl}) => repository.radio(ttl: ttl),
          ttl: ttl);

  void release(int id, {Duration? ttl}) =>
      _doit<ReleaseView>(({Duration? ttl}) => repository.release(id, ttl: ttl),
          ttl: ttl);

  void releasePlaylist(int id, {Duration? ttl}) => _doit<Spiff>(
      ({Duration? ttl}) => repository.releasePlaylist(id, ttl: ttl),
      ttl: ttl);

  void search(String query, {Duration? ttl}) =>
      _doit<SearchView>(({Duration? ttl}) => repository.search(query, ttl: ttl),
          ttl: ttl);

  void series(int id, {Duration? ttl}) =>
      _doit<SeriesView>(({Duration? ttl}) => repository.series(id, ttl: ttl),
          ttl: ttl);

  void seriesPlaylist(int id, {Duration? ttl}) =>
      _doit<Spiff>(({Duration? ttl}) => repository.seriesPlaylist(id, ttl: ttl),
          ttl: ttl);

  void episodePlaylist(int id, {Duration? ttl}) => _doit<Spiff>(
      ({Duration? ttl}) => repository.episodePlaylist(id, ttl: ttl),
      ttl: ttl);

  void station(int id, {Duration? ttl}) =>
      _doit<Spiff>(({Duration? ttl}) => repository.station(id, ttl: ttl),
          ttl: ttl);

  void index({Duration? ttl}) =>
      _doit<IndexView>(({Duration? ttl}) => repository.index(ttl: ttl),
          ttl: ttl);

  void home({Duration? ttl}) =>
      _doit<HomeView>(({Duration? ttl}) => repository.home(ttl: ttl), ttl: ttl);

  void recentTracks({Duration? ttl}) =>
      _doit<Spiff>(({Duration? ttl}) => repository.recentTracks(ttl: ttl),
          ttl: ttl);

  void popularTracks({Duration? ttl}) =>
      _doit<Spiff>(({Duration? ttl}) => repository.popularTracks(ttl: ttl),
          ttl: ttl);

  void patch(List<Map<String, dynamic>> body) =>
      _doit<PatchResult>(({Duration? ttl}) => repository.patch(body));

  void playlist({Duration? ttl}) =>
      _doit<Spiff>(({Duration? ttl}) => repository.playlist(ttl: ttl),
          ttl: ttl);

  void progress({Duration? ttl}) =>
      _doit<ProgressView>(({Duration? ttl}) => repository.progress(ttl: ttl),
          ttl: ttl);

  void updateProgress(Offsets offsets) =>
      _doit<int>(({Duration? ttl}) => repository.updateProgress(offsets));

  void activity({Duration? ttl}) =>
      _doit<ActivityView>(({Duration? ttl}) => repository.activity(ttl: ttl),
          ttl: ttl);

  void updateActivity(Events events) =>
      _doit<int>(({Duration? ttl}) => repository.updateActivity(events));

  Future<void> _doit<T>(ClientRequest<T> call, {Duration? ttl}) async {
    emit(ClientLoading());
    return call(ttl: ttl)
        .timeout(_timeout)
        .then((T result) => emit(ClientResult<T>(result)))
        .onError((error, stackTrace) {
      if (error is ClientException && error.authenticationFailed) {
        emit(ClientAuthError(error.statusCode, error, stackTrace));
      } else {
        emit(ClientError(error, stackTrace));
      }
    });
  }
}
