import 'dart:io';

import 'package:http/http.dart';
import 'package:takeout_app/cache/json_repository.dart';

import 'package:takeout_app/api/model.dart';
import 'package:takeout_app/api/client.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/settings/repository.dart';
import 'package:takeout_app/tokens/repository.dart';
import 'provider.dart';

class ClientRepository {
  final ClientProvider _provider;

  ClientRepository(
      {required SettingsRepository settingsRepository,
      required JsonCacheRepository jsonCacheRepository,
      required TokenRepository tokenRepository,
      ClientProvider? provider})
      : _provider = provider ??
            TakeoutClient(
                settingsRepository: settingsRepository,
                jsonCacheRepository: jsonCacheRepository,
                tokenRepository: tokenRepository);

  Client get client => _provider.client;

  Future<bool> login(String user, String password) async {
    return _provider.login(user, password);
  }

  Future<ArtistsView> artists({Duration? ttl}) async {
    return _provider.artists(ttl: ttl);
  }

  Future<ArtistView> artist(int id, {Duration? ttl}) async {
    return _provider.artist(id, ttl: ttl);
  }

  Future<Spiff> artistRadio(int id, {Duration? ttl}) async {
    return _provider.artistRadio(id, ttl: ttl);
  }

  Future<Spiff> artistPlaylist(int id, {Duration? ttl}) async {
    return _provider.artistPlaylist(id, ttl: ttl);
  }

  Future<PopularView> artistPopular(int id, {Duration? ttl}) async {
    return _provider.artistPopular(id, ttl: ttl);
  }

  Future<Spiff> artistPopularPlaylist(int id, {Duration? ttl}) async {
    return _provider.artistPopularPlaylist(id, ttl: ttl);
  }

  Future<SinglesView> artistSingles(int id, {Duration? ttl}) async {
    return _provider.artistSingles(id, ttl: ttl);
  }

  Future<Spiff> artistSinglesPlaylist(int id, {Duration? ttl}) async {
    return _provider.artistSinglesPlaylist(id, ttl: ttl);
  }

  Future<SearchView> search(String q, {Duration? ttl = Duration.zero}) async {
    return _provider.search(q, ttl: ttl);
  }

  Future<SeriesView> series(int id, {Duration? ttl = Duration.zero}) async {
    return _provider.series(id, ttl: ttl);
  }

  Future<Spiff> seriesPlaylist(int id, {Duration? ttl = Duration.zero}) async {
    return _provider.seriesPlaylist(id, ttl: ttl);
  }

  Future<Spiff> station(int id, {Duration? ttl = Duration.zero}) async {
    return _provider.station(id, ttl: ttl);
  }

  Future<IndexView> index({Duration? ttl}) async {
    return _provider.index(ttl: ttl);
  }

  Future<HomeView> home({Duration? ttl}) async {
    return _provider.home(ttl: ttl);
  }

  Future<MovieView> movie(int id, {Duration? ttl = Duration.zero}) async {
    return _provider.movie(id, ttl: ttl);
  }

  Future<GenreView> moviesGenre(String genre, {Duration? ttl = Duration.zero}) async {
    return _provider.moviesGenre(genre, ttl: ttl);
  }

  Future<ProfileView> profile(int id, {Duration? ttl = Duration.zero}) async {
    return _provider.profile(id, ttl: ttl);
  }

  Future<RadioView> radio({Duration? ttl}) async {
    return _provider.radio(ttl: ttl);
  }

  Future<ReleaseView> release(int id, {Duration? ttl = Duration.zero}) async {
    return _provider.release(id, ttl: ttl);
  }

  Future<Spiff> releasePlaylist(int id, {Duration? ttl}) async {
    return _provider.releasePlaylist(id, ttl: ttl);
  }

  Future<Spiff> recentTracks({Duration? ttl}) async {
    return _provider.recentTracks(ttl: ttl);
  }

  Future<Spiff> popularTracks({Duration? ttl}) async {
    return _provider.popularTracks(ttl: ttl);
  }

  Future<int> download(Uri uri, File file, int size, {Sink<int>? progress}) {
    return _provider.download(uri, file, size, progress: progress);
  }

  Future<int> updateActivity(Events events) {
    return _provider.updateActivity(events);
  }

  Future<PatchResult> patch(List<Map<String, dynamic>> body) {
    return _provider.patch(body);
  }

  Future<Spiff> playlist({Duration? ttl}) async {
    return _provider.playlist(ttl: ttl);
  }
}
