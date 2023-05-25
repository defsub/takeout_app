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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:takeout_lib/art/provider.dart';
import 'package:takeout_lib/api/model.dart';
import 'package:takeout_lib/cache/offset.dart';
import 'package:takeout_lib/cache/spiff.dart';
import 'package:takeout_lib/cache/track.dart';
import 'package:takeout_lib/client/client.dart';
import 'package:takeout_lib/client/download.dart';
import 'package:takeout_lib/client/repository.dart';
import 'package:takeout_lib/client/resolver.dart';
import 'package:takeout_lib/connectivity/connectivity.dart';
import 'package:takeout_lib/db/search.dart';
import 'package:takeout_lib/index/index.dart';
import 'package:takeout_lib/media_type/media_type.dart';
import 'package:takeout_lib/player/player.dart';
import 'package:takeout_lib/player/playing.dart';
import 'package:takeout_lib/player/playlist.dart';
import 'package:takeout_lib/settings/settings.dart';
import 'package:takeout_lib/spiff/model.dart';
import 'package:takeout_lib/tokens/repository.dart';
import 'package:takeout_lib/tokens/tokens.dart';
import 'package:takeout_lib/history/history.dart';

extension TakeoutContext on BuildContext {
  void play(Spiff spiff) {
    nowPlaying.add(spiff, autoplay: true);
  }

  void stream(int station) {
    clientRepository
        .station(station, ttl: Duration.zero)
        .then((spiff) => play(spiff));
  }

  void download(Spiff spiff) {
    spiffCache.add(spiff);
    final events = spiff.playlist.tracks
        .map((t) => DownloadEvent(t, Uri.parse(t.location), t.size));
    downloads.addAll(events);
  }

  void remove(Spiff spiff) {
    trackCache.removeIds(spiff.playlist.tracks);
    spiffCache.remove(spiff);
  }

  void downloadRelease(Release release) {
    clientRepository
        .releasePlaylist(release.id)
        .then((spiff) => download(spiff));
  }

  void downloadTracks(Iterable<Track> tracks) {
    final events =
        tracks.map((t) => DownloadEvent(t, Uri.parse(t.location), t.size));
    downloads.addAll(events);
  }

  void downloadSeries(Series series) {
    clientRepository.seriesPlaylist(series.id).then((spiff) => download(spiff));
  }

  void downloadEpisode(Episode episode) {
    clientRepository
        .episodePlaylist(episode.id)
        .then((spiff) => download(spiff));
  }

  void downloadEpisodes(Iterable<Episode> episodes) {
    final events =
        episodes.map((t) => DownloadEvent(t, Uri.parse(t.location), t.size));
    downloads.addAll(events);
  }

  void downloadStation(Station station) {
    clientRepository
        .station(station.id, ttl: Duration.zero)
        .then((spiff) => download(spiff));
  }

  void downloadMovie(Movie movie) {
    clientRepository.moviePlaylist(movie.id).then((spiff) => download(spiff));
  }

  void reload() {
    index.reload();
    search.reload();
    offsets.reload();
  }

  void removeDownloads() {
    spiffCache.removeAll();
    trackCache.removeAll();
  }

  Future<void> updateProgress(String etag,
      {required Duration position, Duration? duration}) async {
    final offset = Offset.now(etag: etag, offset: position, duration: duration);
    if (await offsets.repository.contains(offset) == false) {
      // add local offset
      offsets.add(offset);
      // send to server
      await clientRepository.updateProgress(Offsets(offsets: [offset]));
    }
  }

  ArtProvider get imageProvider => read<ArtProvider>();

  ClientCubit get client => read<ClientCubit>();

  ClientRepository get clientRepository => read<ClientRepository>();

  ConnectivityCubit get connectivity => read<ConnectivityCubit>();

  DownloadCubit get downloads => read<DownloadCubit>();

  HistoryCubit get history => read<HistoryCubit>();

  IndexCubit get index => read<IndexCubit>();

  MediaTrackResolver get resolver => read<MediaTrackResolver>();

  MediaTypeCubit get selectedMediaType => read<MediaTypeCubit>();

  NowPlayingCubit get nowPlaying => read<NowPlayingCubit>();

  OffsetCacheCubit get offsets => read<OffsetCacheCubit>();

  Player get player => read<Player>();

  PlaylistCubit get playlist => read<PlaylistCubit>();

  Search get search => read<Search>();

  SettingsCubit get settings => read<SettingsCubit>();

  SpiffCacheCubit get spiffCache => read<SpiffCacheCubit>();

  TokenRepository get tokenRepository => read<TokenRepository>();

  TokensCubit get tokens => read<TokensCubit>();

  TrackCacheCubit get trackCache => read<TrackCacheCubit>();
}
