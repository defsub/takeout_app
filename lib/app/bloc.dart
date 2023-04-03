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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:takeout_app/cache/json_repository.dart';
import 'package:takeout_app/cache/offset.dart';
import 'package:takeout_app/cache/offset_repository.dart';
import 'package:takeout_app/cache/prune.dart';
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
import 'package:path_provider/path_provider.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import 'app.dart';
import 'context.dart';

late final Directory _appDir;

Future<void> appMain() async {
  _appDir = await getApplicationDocumentsDirectory();
  final storageDir = Directory('${_appDir.path}/state');
  HydratedBloc.storage =
      await HydratedStorage.build(storageDirectory: storageDir);
}

mixin AppBloc {
  Widget appInit(BuildContext context, {required Widget child}) {
    return _repositories(_appDir,
        child: _blocs(child: _listeners(context, child: child)));
  }

  Widget _repositories(Directory directory, {required Widget child}) {
    final d = (String name) => Directory('${directory.path}/$name');

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
      BlocProvider(create: (_) => MediaTypeCubit()),
      BlocProvider(create: (_) => NowPlayingCubit()),
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
          lazy: false,
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

  /// NowPlaying manages the playlist that should be playing.
  void onNowPlayingChange(BuildContext context, Spiff spiff, bool autoplay) {
    // load now playing playlist into player
    context.player.load(spiff, autoplay: autoplay);
  }

  void onPlaylistChange(BuildContext context, PlaylistChange state) {
    context.play(state.spiff);
  }

  /// Restore playlist once the player is ready.
  void onPlayerReady(BuildContext context, PlayerReady state) {
    final nowPlaying = context.nowPlaying.state;
    onNowPlayingChange(context, nowPlaying.spiff, false);

    context.player.stream.timeout(const Duration(minutes: 1), onTimeout: (_) {
      context.player.stop();
    }).listen((event) {});
  }

  void onPlayerLoad(BuildContext context, PlayerLoad state) {
    if (state.autoplay) {
      context.player.play();
    }
  }

  void onPlayerPlay(BuildContext context, PlayerPlay state) {}

  void _updateProgress(BuildContext context, PlayerPositionState state) {
    if (state.spiff.isPodcast()) {
      final currentTrack = state.currentTrack;
      if (currentTrack != null) {
        context.updateProgress(currentTrack.etag,
            position: state.position, duration: state.duration);
      }
    }
  }

  void onPlayerPause(BuildContext context, PlayerPause state) {
    _updateProgress(context, state);
  }

  void onPlayerIndexChange(BuildContext context, PlayerIndexChange state) {
    context.nowPlaying.index(state.currentIndex);
  }

  void onPlayerTrackEnd(BuildContext context, PlayerTrackEnd state) {
    _updateProgress(context, state);
  }

  void onDownloadComplete(BuildContext context, DownloadComplete state) {
    // add completed download to TrackCache
    final download = state.get(state.id);
    final file = download?.file;
    if (download != null && file != null) {
      context.trackCache.add(state.id, file);
    }
  }

  void onDownloadChange(BuildContext context, DownloadState state) {
    // check if downloads should be started
    // TODO this will only prevent the next download from starting
    // the current one will continue if network switched from to mobile
    // during the download.
    if (context.connectivity.state.mobile
        ? context.settings.state.settings.allowMobileDownload
        : true) {
      context.downloads.check();
    }
  }

  Widget _listeners(BuildContext context, {required Widget child}) {
    return MultiBlocListener(listeners: [
      BlocListener<NowPlayingCubit, NowPlayingState>(
          listenWhen: (_, state) => state is NowPlayingChange,
          listener: (context, state) {
            if (state is NowPlayingChange) {
              onNowPlayingChange(context, state.spiff, state.autoplay);
            }
          }),
      BlocListener<Player, PlayerState>(
          listenWhen: (_, state) =>
              state is PlayerReady ||
              state is PlayerLoad ||
              state is PlayerPlay ||
              state is PlayerPause ||
              state is PlayerIndexChange ||
              state is PlayerTrackEnd,
          listener: (context, state) {
            if (state is PlayerReady) {
              onPlayerReady(context, state);
            } else if (state is PlayerLoad) {
              onPlayerLoad(context, state);
            } else if (state is PlayerPlay) {
              onPlayerPlay(context, state);
            } else if (state is PlayerPause) {
              onPlayerPause(context, state);
            } else if (state is PlayerIndexChange) {
              onPlayerIndexChange(context, state);
            } else if (state is PlayerTrackEnd) {
              onPlayerTrackEnd(context, state);
            }
          }),
      BlocListener<PlaylistCubit, PlaylistState>(
          listenWhen: (_, state) => state is PlaylistChange,
          listener: (context, state) {
            if (state is PlaylistChange) {
              onPlaylistChange(context, state);
            }
          }),
      BlocListener<DownloadCubit, DownloadState>(
          listenWhen: (_, state) =>
              state is DownloadAdd ||
              state is DownloadComplete ||
              state is DownloadError,
          listener: (context, state) {
            if (state is DownloadComplete) {
              onDownloadComplete(context, state);
            }
            onDownloadChange(context, state);
          }),
    ], child: child);
  }
}

mixin AppBlocState {
  StreamSubscription<PlayerProgressChange>? _considerPlayedSubscription;

  void appInitState(BuildContext context) {
    if (context.tokens.state.tokens.authenticated) {
      // restore authenticated state
      context.app.authenticated();
    }

    // keep track of position changes and update history once a track is considered played
    // TODO consider a more efficient way to do this
    //
    // TODO: not happy with this code. currently this will send history/activity event again
    // when you resume playing something that is more than 1/2 way through.

    // _considerPlayedSubscription = context.player.stream
    //     .where((state) => state is PlayerProgressChange)
    //     .cast<PlayerProgressChange>()
    //     .distinct((a, b) =>
    //         a.currentTrack?.etag == b.currentTrack?.etag &&
    //         a.considerPlayed == b.considerPlayed)
    //     .listen((state) {
    //   if (state.considerPlayed) {
    //     final currentTrack = state.currentTrack;
    //     if (currentTrack != null) {
    //       print('consider played ${state.currentTrack?.title}');
    //       // add track to history & activity
    //       context.history.add(track: currentTrack);
    //       context.clientRepository.updateActivity(
    //           Events(trackEvents: [TrackEvent.now(currentTrack.etag)]));
    //     }
    //   }
    // });

    // prune incomplete/partial downloads
    pruneCache(context.spiffCache.repository, context.trackCache.repository);
  }

  void appDispose() {
    _considerPlayedSubscription?.cancel();
  }
}
