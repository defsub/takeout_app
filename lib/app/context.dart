import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:takeout_app/player/playing.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/client/client.dart';
import 'package:takeout_app/client/repository.dart';
import 'package:takeout_app/connectivity/connectivity.dart';
import 'package:takeout_app/player/player.dart';
import 'package:takeout_app/player/playlist.dart';
import 'package:takeout_app/settings/settings.dart';
import 'package:takeout_app/client/download.dart';
import 'package:takeout_app/client/resolver.dart';
import 'package:takeout_app/history/history.dart';
import 'package:takeout_app/media_type/media_type.dart';
import 'package:takeout_app/cache/spiff.dart';
import 'package:takeout_app/cache/track.dart';
import 'package:takeout_app/cache/offset.dart';
import 'package:takeout_app/tokens/tokens.dart';
import 'package:takeout_app/tokens/repository.dart';
import 'package:takeout_app/db/search.dart';
import 'package:takeout_app/index/index.dart';
import 'package:takeout_app/model.dart';

import 'app.dart';

extension AppContext on BuildContext {

  void play(Spiff spiff) {
    nowPlaying.add(spiff);
    history.add(spiff: Spiff.cleanup(spiff));
    app.showPlayer();
  }

  void download(Spiff spiff) {

  }

  void showMovie(MediaTrack movie) {
    // app.showMovie(movie);
  }

  void showArtist(String artist) {
    // app.showArtist(artist);
  }

  AppCubit get app => read<AppCubit>();

  ClientCubit get client => read<ClientCubit>();

  ClientRepository get clientRepository => read<ClientRepository>();

  ConnectivityCubit get connectivity => read<ConnectivityCubit>();

  DownloadCubit get downloads => read<DownloadCubit>();

  HistoryCubit get history => read<HistoryCubit>();

  IndexCubit get index => read<IndexCubit>();

  MediaTrackResolver get resolver => read<MediaTrackResolver>();

  NowPlaying get nowPlaying => read<NowPlaying>();

  OffsetCacheCubit get offsetCache => read<OffsetCacheCubit>();

  Player get player => read<Player>();

  PlaylistCubit get playlist => read<PlaylistCubit>();

  Search get search => read<Search>();

  SelectedMediaType get selectedMediaType => read<SelectedMediaType>();

  SettingsCubit get settings => read<SettingsCubit>();

  SpiffCacheCubit get spiffCache => read<SpiffCacheCubit>();

  TokensCubit get tokens => read<TokensCubit>();

  TokenRepository get tokenRepository => read<TokenRepository>();

  TrackCacheCubit get trackCache => read<TrackCacheCubit>();
}
