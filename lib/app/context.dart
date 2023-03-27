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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:takeout_app/api/model.dart';
import 'package:takeout_app/cache/offset.dart';
import 'package:takeout_app/cache/spiff.dart';
import 'package:takeout_app/cache/track.dart';
import 'package:takeout_app/client/client.dart';
import 'package:takeout_app/client/download.dart';
import 'package:takeout_app/client/repository.dart';
import 'package:takeout_app/client/resolver.dart';
import 'package:takeout_app/connectivity/connectivity.dart';
import 'package:takeout_app/db/search.dart';
import 'package:takeout_app/history/history.dart';
import 'package:takeout_app/index/index.dart';
import 'package:takeout_app/media_type/media_type.dart';
import 'package:takeout_app/model.dart';
import 'package:takeout_app/player/player.dart';
import 'package:takeout_app/player/playing.dart';
import 'package:takeout_app/player/playlist.dart';
import 'package:takeout_app/settings/settings.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/tokens/repository.dart';
import 'package:takeout_app/tokens/tokens.dart';

import 'app.dart';

extension AppContext on BuildContext {
  AppLocalizations get strings => AppLocalizations.of(this)!;

  void logout() {
    tokens.removeAll();
    app.logout();
  }

  void play(Spiff spiff) {
    nowPlaying.add(spiff, autoplay: true);
    // TODO consider moving history.add from here to onNowPLayingChange
    history.add(spiff: Spiff.cleanup(spiff));
    app.showPlayer();
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

  void showMovie(MediaTrack movie) {
    // app.showMovie(movie);
  }

  void showArtist(String artist) {
    // app.showArtist(artist);
  }

  void reload() {
    index.reload();
    search.reload();
    offsets.reload();
  }

  Future<void> updateProgress(String etag,
      {required Duration position, Duration? duration}) async {
    final offset = Offset.now(etag: etag, offset: position, duration: duration);
    if (await offsets.repository.contains(offset) == false) {
      // add local offset
      offsets.add(offset);
      // send to server
      clientRepository.updateProgress(Offsets(offsets: [offset]));
    }
  }

  AppCubit get app => read<AppCubit>();

  ClientCubit get client => read<ClientCubit>();

  ClientRepository get clientRepository => read<ClientRepository>();

  ConnectivityCubit get connectivity => read<ConnectivityCubit>();

  DownloadCubit get downloads => read<DownloadCubit>();

  HistoryCubit get history => read<HistoryCubit>();

  IndexCubit get index => read<IndexCubit>();

  MediaTrackResolver get resolver => read<MediaTrackResolver>();

  NowPlayingCubit get nowPlaying => read<NowPlayingCubit>();

  OffsetCacheCubit get offsets => read<OffsetCacheCubit>();

  Player get player => read<Player>();

  PlaylistCubit get playlist => read<PlaylistCubit>();

  Search get search => read<Search>();

  MediaTypeCubit get selectedMediaType => read<MediaTypeCubit>();

  SettingsCubit get settings => read<SettingsCubit>();

  SpiffCacheCubit get spiffCache => read<SpiffCacheCubit>();

  TokensCubit get tokens => read<TokensCubit>();

  TokenRepository get tokenRepository => read<TokenRepository>();

  TrackCacheCubit get trackCache => read<TrackCacheCubit>();
}
