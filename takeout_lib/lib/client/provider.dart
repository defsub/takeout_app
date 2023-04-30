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

import 'dart:io';

import 'package:http/http.dart';
import 'package:takeout_lib/api/model.dart';
import 'package:takeout_lib/spiff/model.dart';

abstract class ClientProvider {
  Client get client;

  Future<bool> login(String user, String password);

  Future<ArtistsView> artists({Duration? ttl});

  Future<ArtistView> artist(int id, {Duration? ttl});

  Future<Spiff> artistRadio(int id, {Duration? ttl});

  Future<Spiff> artistPlaylist(int id, {Duration? ttl});

  Future<PopularView> artistPopular(int id, {Duration? ttl});

  Future<Spiff> artistPopularPlaylist(int id, {Duration? ttl});

  Future<SinglesView> artistSingles(int id, {Duration? ttl});

  Future<Spiff> artistSinglesPlaylist(int id, {Duration? ttl});

  Future<WantListView> artistWantList(int id, {Duration? ttl});

  Future<SearchView> search(String q, {Duration? ttl = Duration.zero});

  Future<Spiff> station(int id, {Duration? ttl = Duration.zero});

  Future<IndexView> index({Duration? ttl});

  Future<HomeView> home({Duration? ttl});

  Future<MovieView> movie(int id, {Duration? ttl});

  Future<Spiff> moviePlaylist(int id, {Duration? ttl});

  Future<GenreView> moviesGenre(String genre, {Duration? ttl});

  Future<ProfileView> profile(int id, {Duration? ttl});

  Future<RadioView> radio({Duration? ttl});

  Future<ReleaseView> release(int id, {Duration? ttl});

  Future<Spiff> releasePlaylist(int id, {Duration? ttl});

  Future<SeriesView> series(int id, {Duration? ttl});

  Future<Spiff> seriesPlaylist(int id, {Duration? ttl});

  Future<Spiff> episodePlaylist(int id, {Duration? ttl});

  Future<Spiff> recentTracks({Duration? ttl});

  Future<Spiff> popularTracks({Duration? ttl});

  Future<int> download(Uri uri, File file, int size, {Sink<int>? progress});

  Future<PatchResult> patch(List<Map<String, dynamic>> body);

  Future<Spiff> playlist({Duration? ttl});

  Future<ProgressView> progress({Duration? ttl});

  Future<int> updateProgress(Offsets offsets);

  Future<ActivityView> activity({Duration? ttl});

  Future<int> updateActivity(Events events);
}
