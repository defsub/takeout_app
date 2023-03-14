import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:takeout_app/cache/json_repository.dart';
import 'package:takeout_app/cache/offset.dart';
import 'package:takeout_app/cache/offset_repository.dart';
import 'package:takeout_app/cache/spiff.dart';
import 'package:takeout_app/cache/track.dart';
import 'package:takeout_app/cache/track_repository.dart';
import 'package:takeout_app/client/download.dart';
import 'package:takeout_app/client/repository.dart';
import 'package:takeout_app/client/resolver.dart';
import 'package:takeout_app/connectivity/connectivity.dart';
import 'package:takeout_app/connectivity/repository.dart';
import 'package:takeout_app/db/search.dart';
import 'package:takeout_app/history/history.dart';
import 'package:takeout_app/history/repository.dart';
import 'package:takeout_app/index/index.dart';
import 'package:takeout_app/media_type/media_type.dart';
import 'package:takeout_app/player/player.dart';
import 'package:takeout_app/player/playing.dart';
import 'package:takeout_app/player/playlist.dart';
import 'package:takeout_app/settings/repository.dart';
import 'package:takeout_app/settings/settings.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/tokens/repository.dart';
import 'package:takeout_app/tokens/tokens.dart';

import 'app.dart';
import 'context.dart';

mixin AppBloc {
  Widget appInit(BuildContext context,
      {required Directory directory, required Widget child}) {
    return _repositories(directory,
        child: _blocs(child: _listeners(context, child: child)));
  }

  Widget _repositories(Directory directory, {required Widget child}) {
    final d = (String name) => Directory('${directory.path}/${name}');

    final settingsRepository = SettingsRepository();

    final trackCacheRepository =
        TrackCacheRepository(directory: d('track_cache'));

    final jsonCacheRepository = JsonCacheRepository(directory: d('json_cache'));

    final offsetCacheRepository =
        OffsetCacheRepository(directory: d('offset_cache'));

    final spiffCacheRepository =
        SpiffCacheRepository(directory: d('spiff_cache'));

    final historyRepository = HistoryRepository(directory: directory);

    final tokenRepository = TokenRepository();

    final clientRepository = ClientRepository(
        settingsRepository: settingsRepository,
        tokenRepository: tokenRepository,
        jsonCacheRepository: jsonCacheRepository);

    final connectivityRepository = ConnectivityRepository();

    final search = Search(clientRepository: clientRepository);

    final trackResolver =
        MediaTrackResolver(trackCacheRepository: trackCacheRepository);

    return MultiRepositoryProvider(providers: [
      RepositoryProvider(create: (_) => search),
      RepositoryProvider(create: (_) => settingsRepository),
      RepositoryProvider(create: (_) => trackCacheRepository),
      RepositoryProvider(create: (_) => jsonCacheRepository),
      RepositoryProvider(create: (_) => offsetCacheRepository),
      RepositoryProvider(create: (_) => spiffCacheRepository),
      RepositoryProvider(create: (_) => historyRepository),
      RepositoryProvider(create: (_) => clientRepository),
      RepositoryProvider(create: (_) => connectivityRepository),
      RepositoryProvider(create: (_) => tokenRepository),
      RepositoryProvider(create: (_) => trackResolver),
    ], child: child);
  }

  Widget _blocs({required Widget child}) {
    return MultiBlocProvider(providers: [
      BlocProvider(
          lazy: false,
          create: (context) {
            final settings = SettingsCubit();
            context.read<SettingsRepository>().init(settings);
            return settings;
          }),
      BlocProvider(create: (_) => AppCubit()),
      BlocProvider(create: (_) => SelectedMediaType()),
      BlocProvider(create: (_) => NowPlaying()),
      BlocProvider(
          create: (context) => PlaylistCubit(context.read<ClientRepository>())),
      BlocProvider(
          create: (context) =>
              ConnectivityCubit(context.read<ConnectivityRepository>())),
      BlocProvider(create: (context) {
        final tokens = TokensCubit();
        context.read<TokenRepository>().init(tokens);
        return tokens;
      }),
      BlocProvider(
          create: (context) => Player(
              offsetRepository: context.read<OffsetCacheRepository>(),
              settingsRepository: context.read<SettingsRepository>(),
              tokenRepository: context.read<TokenRepository>(),
              trackResolver: context.read<MediaTrackResolver>())),
      BlocProvider(
          create: (context) =>
              SpiffCacheCubit(context.read<SpiffCacheRepository>())),
      BlocProvider(
          create: (context) => OffsetCacheCubit(
              context.read<OffsetCacheRepository>(),
              context.read<ClientRepository>())),
      BlocProvider(
          create: (context) => DownloadCubit(
                trackCacheRepository: context.read<TrackCacheRepository>(),
                clientRepository: context.read<ClientRepository>(),
              )),
      BlocProvider(
          create: (context) => TrackCacheCubit(
                context.read<TrackCacheRepository>(),
              )),
      BlocProvider(
          create: (context) => HistoryCubit(context.read<HistoryRepository>())),
      BlocProvider(
          create: (context) => IndexCubit(context.read<ClientRepository>()))
    ], child: child);
  }

  Widget _listeners(BuildContext context, {required Widget child}) {
    return MultiBlocListener(listeners: [
      BlocListener<NowPlaying, Spiff?>(listener: (context, spiff) {
        if (spiff != null) {
          // load now playing playlist into player
          context.player.load(spiff);
        }
      }),
      BlocListener<Player, PlayerState>(
          listenWhen: (_, state) =>
              state is PlayerReady || state is PlayerLoaded,
          listener: (context, state) {
            if (state is PlayerReady) {
              // restore playlist at startup
              final spiff = context.nowPlaying.state;
              if (spiff != null) {
                context.player.load(spiff);
              }
            }
          }),
      BlocListener<PlaylistCubit, PlaylistState>(
          listenWhen: (_, state) => state is PlaylistChanged,
          listener: (context, state) {
            if (state is PlaylistChanged) {
              context.play(state.spiff);
            }
          }),
      BlocListener<DownloadCubit, DownloadState>(
          listenWhen: (_, state) =>
              state is DownloadAdded ||
              state is DownloadCompleted ||
              state is DownloadError,
          listener: (context, state) {
            if (state is DownloadCompleted) {
              // add completed download to TrackCache
              final download = state.get(state.id);
              final file = download?.file;
              if (download != null && file != null) {
                context.trackCache.add(state.id, file);
              }
            }
            // always check if downloads should be started
            context.downloads.check();
          }),
    ], child: child);
  }
}

mixin AppBlocState {
  StreamSubscription<PlayerPositionChanged>? _considerPlayedSubscription;

  void appInitState(BuildContext context) {
    if (context.tokens.state.authenticated) {
      // restore authenticated state
      context.app.authenticated();
    }

    // keep track of position changes and update history once a track is considered played
    _considerPlayedSubscription = context.player.stream
        .where((state) => state is PlayerPositionChanged)
        .cast<PlayerPositionChanged>()
        .distinct((a, b) =>
            a.currentTrack.etag == b.currentTrack.etag &&
            a.considerPlayed == b.considerPlayed)
        .listen((state) {
      if (state.considerPlayed) {
        print(
            'consider played ${state.position} ${state.duration} ${state.currentTrack.title}');
        context.history.add(track: state.currentTrack);
      }
    });
  }

  void appDispose() {
    _considerPlayedSubscription?.cancel();
  }
}
