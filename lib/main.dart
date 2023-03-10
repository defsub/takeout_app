// Copyright (C) 2020 The Takeout Authors.
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

// The navigation stack and routing code is heavily based on example code.
// Still looking for the original reference.

import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'package:takeout_app/connectivity/connectivity.dart';
import 'package:takeout_app/connectivity/repository.dart';
import 'package:takeout_app/index/index.dart';

import 'media_type/media_type.dart';

import 'package:takeout_app/app/app.dart';
import 'package:takeout_app/app/context.dart';
import 'package:takeout_app/db/search.dart';
import 'package:takeout_app/cache/offset.dart';
import 'package:takeout_app/cache/offset_repository.dart';
import 'package:takeout_app/cache/spiff.dart';
import 'package:takeout_app/cache/json_repository.dart';
import 'package:takeout_app/cache/track_repository.dart';
import 'package:takeout_app/cache/track.dart';
import 'package:takeout_app/client/repository.dart';
import 'package:takeout_app/client/download.dart';
import 'package:takeout_app/history/history.dart';
import 'package:takeout_app/history/repository.dart';
import 'package:takeout_app/tokens/tokens.dart';
import 'package:takeout_app/tokens/repository.dart';
import 'package:takeout_app/client/resolver.dart';
import 'package:takeout_app/player/player.dart';
import 'package:takeout_app/player/widget.dart';
import 'package:takeout_app/settings/settings.dart';
import 'package:takeout_app/settings/repository.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/player/playing.dart';
import 'package:takeout_app/player/playlist.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:takeout_app/history/widget.dart';

import 'artists.dart';
import 'home.dart';
import 'login.dart';
import 'radio.dart';
import 'search.dart';
import 'global.dart';

void main() async {
  // setup the logger
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName}: ${record.message}');
  });

  WidgetsFlutterBinding.ensureInitialized();

  final appDir = await getApplicationDocumentsDirectory();
  final storageDir = Directory('${appDir.path}/state');
  HydratedBloc.storage =
      await HydratedStorage.build(storageDirectory: storageDir);

  runApp(TakeoutApp(appDir));
}

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class TakeoutApp extends StatelessWidget {
  final Directory directory;

  TakeoutApp(this.directory);

  @override
  Widget build(BuildContext context) {
    return repositories(directory,
        child: blocs(
            child: listeners(context, child: DynamicColorBuilder(
                builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return MaterialApp(
              onGenerateTitle: (context) {
                return AppLocalizations.of(context)!.takeoutTitle;
              },
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [
                const Locale('en', ''),
              ],
              home: _TakeoutWidget(),
              theme: ThemeData.light()
                  .copyWith(useMaterial3: true, colorScheme: lightDynamic),
              darkTheme: ThemeData.dark()
                  .copyWith(useMaterial3: true, colorScheme: darkDynamic));
        }))));
  }

  Widget repositories(Directory directory, {required Widget child}) {
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
    ], child: child);
  }

  Widget blocs({required Widget child}) {
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
              trackResolver: MediaTrackResolver(
                  trackCacheRepository: context.read<TrackCacheRepository>()))),
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

  Widget listeners(BuildContext context, {required Widget child}) {
    return BlocListener<NowPlaying, Spiff?>(
        listener: (context, spiff) {
          if (spiff != null) {
            context.player.load(spiff);
          }
        },
        child: BlocListener<Player, PlayerState>(
            listenWhen: (_, state) => state is PlayerReady,
            listener: (context, state) {
              if (state is PlayerReady) {
                final spiff = context.nowPlaying.state;
                if (spiff != null) {
                  context.player.load(spiff);
                }
              }
            },
            child: BlocListener<PlaylistCubit, PlaylistState>(
                listenWhen: (_, state) => state is PlaylistChanged,
                listener: (context, state) {
                  print('playlist got $state');
                  if (state is PlaylistChanged) {
                    context.nowPlaying.add(state.spiff);
                  }
                },
                child: child)));
  }
}

class _TakeoutWidget extends StatefulWidget {
  _TakeoutWidget({Key? key}) : super(key: key);

  @override
  _TakeoutState createState() => _TakeoutState();
}

class _TakeoutState extends State<_TakeoutWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    if (context.tokens.state.authenticated) {
      context.app.authenticated();
    }

    // TODO prune cache
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    snackBarStateSubject.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final connectivity = context.connectivity;
    switch (state) {
      case AppLifecycleState.resumed:
        connectivity.check();
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  // This will auto-pause playback for remote media when streaming is disabled.
  // void _onMediaItem(MediaItem? mediaItem) {
  //   if (audioHandler.playbackState.hasValue &&
  //       audioHandler.playbackState.value == true) {
  //     final streaming = mediaItem?.isRemote() ?? false;
  //     if (streaming && allowStreaming(connectivityStream.value) == false) {
  //       log.finer('mediaItem pause due to loss of wifi');
  //       audioHandler.pause();
  //     }
  //   }
  // }

  // Future<LiveClient> _createLiveClient(Client client) async {
  //   final token = await client.getAccessToken();
  //   final url = await client.getEndpoint();
  //   final uri = Uri.parse(url);
  //   return LiveClient('${uri.host}:${uri.port}', token!);
  // }
  //
  // LiveFollow? _liveFollow;
  // LiveShare? _liveShare;
  //
  // void _onLiveChange(LiveType liveType) async {
  //   _liveFollow?.stop();
  //   _liveFollow = null;
  //   _liveShare?.stop();
  //   _liveShare = null;
  //   if (liveType == LiveType.none) {
  //     return;
  //   }
  //   final client = Client();
  //   final live = await _createLiveClient(client);
  //   if (liveType == LiveType.follow) {
  //     _liveFollow = LiveFollow(live, audioHandler);
  //     _liveFollow!.start();
  //   } else if (settingsLiveType() == LiveType.share) {
  //     _liveShare = LiveShare(live, audioHandler);
  //     _liveShare!.start();
  //   }
  // }
  //
  // void _live() async {
  //   // start with the current value
  //   _onLiveChange(settingsLiveType());
  //   // listen for changes
  //   settingsChangeSubject.listen((setting) {
  //     if (setting == settingLiveMode) {
  //       _onLiveChange(settingsLiveType());
  //     }
  //   });
  // }

  void _load() async {
    // Artwork.endpoint = await Client().getEndpoint();

    // audioHandler.mediaItem
    //     .distinct()
    //     .listen((mediaItem) => _onMediaItem(mediaItem));

    // await TrackCache.init();
    // await OffsetCache.init();
    // await Downloads.prune().whenComplete(() => Downloads.load());
    // try {
    //   final client = Client();
    //   client.index().then((view) => _onIndexUpdated(view));
    //   client.home().then((view) => _onHomeUpdated(view));
    //   await Progress.sync();
    //   await MediaQueue.sync();
    //   if (audioHandler.playbackState.hasValue == false ||
    //       (audioHandler.playbackState.hasValue &&
    //           audioHandler.playbackState.value.playing == false)) {
    //     MediaQueue.restore();
    //   }
    // } on ClientException catch (e) {
    //   if (e.authenticationFailed) {
    //     logout();
    //   }
    // } on TlsException catch (e) {
    //   showErrorDialog(context, e.message);
    // }
  }

  static final _routes = [
    '/home',
    '/artists',
    '/history',
    '/radio',
    '/player',
  ];

  NavigatorState? _navigatorState(NavigationIndex index) {
    NavigatorState? navState;
    switch (index) {
      case NavigationIndex.home:
        navState = homeKey.currentState;
        break;
      case NavigationIndex.artists:
        navState = artistsKey.currentState;
        break;
      case NavigationIndex.history:
        navState = historyKey.currentState;
        break;
      case NavigationIndex.radio:
        navState = radioKey.currentState;
        break;
      case NavigationIndex.player:
        navState = playerKey.currentState;
        break;
    }
    return navState;
  }

  void _onNavTapped(BuildContext context, int index) {
    final currentIndex = context.app.state.navigationBarIndex;
    if (currentIndex == index) {
      NavigatorState? navState = _navigatorState(context.app.state.index);
      if (navState != null && navState.canPop()) {
        navState.popUntil((route) => route.isFirst);
      }
    } else {
      context.app.go(index);
    }
  }

  StreamSubscription<SnackBarState>? snackBarSubscription;

  @override
  Widget build(final BuildContext context) {
    snackBarSubscription?.cancel();
    snackBarSubscription = snackBarStateSubject.listen((e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: e.content));
    });

    final builders = _pageBuilders();
    final pages = List.generate(
        _routes.length, (index) => builders[_routes[index]]!(context));

    return WillPopScope(onWillPop: () async {
      NavigatorState? navState = _navigatorState(context.app.state.index);
      if (navState != null) {
        final handled = await navState.maybePop();
        if (!handled && context.app.state.index == NavigationIndex.home) {
          // allow pop and app to exit
          return true;
        }
      }
      return false;
    }, child: BlocBuilder<AppCubit, AppState>(builder: (context, state) {
      if (state.authenticated == false) {
        return LoginWidget();
      } else {
        return Scaffold(
            key: _scaffoldMessengerKey,
            floatingActionButton: _fab(context),
            body:
                IndexedStack(index: state.navigationBarIndex, children: pages),
            bottomNavigationBar: _bottomNavigation());
      }
    }));
    //
    // _loggedIn == null
    //     ? Center(child: CircularProgressIndicator())
    //     : _loggedIn == false
    //     ? LoginWidget(() => login())
    //     : Scaffold(
    //     key: _scaffoldMessengerKey,
    //     floatingActionButton: _fab(context),
    //     body: StreamBuilder<int>(
    //         stream: _navIndexStream,
    //         builder: (context, snapshot) {
    //           final index = snapshot.data ?? 0;
    //           return IndexedStack(index: index, children: pages);
    //         }),
    //     bottomNavigationBar: _bottomNavigation())
    // );
  }

  // bool _showingPlayer() {
  //   return _selectedIndex == 4;
  // }

  Widget _fab(BuildContext context) {
    return BlocBuilder<Player, PlayerState>(builder: (context, state) {
      bool playing = false;
      double? progress;

      // navIndex == 4 don't snow

      if (state is PlayerInit ||
          state is PlayerReady ||
          state is PlayerLoaded ||
          state is PlayerStopped) {
        return SizedBox.shrink();
      }

      if (state is PlayerPositionState) {
        playing = state.playing;
        progress = state.progress;
      }

      return Container(
          child: Stack(alignment: Alignment.center, children: [
        FloatingActionButton(
            onPressed: () =>
                playing ? context.player.pause() : context.player.play(),
            shape: const CircleBorder(),
            child: playing ? Icon(Icons.pause) : Icon(Icons.play_arrow)),
        IgnorePointer(
            child: SizedBox(
                width: 52, // non-mini FAB is 56, progress is 4
                height: 52,
                child: CircularProgressIndicator(value: progress))),
      ]));
    });
  }

  Widget _bottomNavigation() {
    return Stack(children: [
      BlocBuilder<AppCubit, AppState>(builder: (context, state) {
        final index = state.navigationBarIndex;
        return BottomNavigationBar(
          key: bottomNavKey,
          showUnselectedLabels: false,
          showSelectedLabels: false,
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: AppLocalizations.of(context)!.navHome,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt),
              label: AppLocalizations.of(context)!.navArtists,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: AppLocalizations.of(context)!.navHistory,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.radio),
              label: AppLocalizations.of(context)!.navRadio,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.queue_music),
              label: AppLocalizations.of(context)!.navPlayer,
            ),
          ],
          currentIndex: index,
          onTap: (index) => _onNavTapped(context, index),
        );
      }),
      // if (!_showingPlayer())
      //   StreamBuilder<Duration>(
      //       stream: audioPlayerHandler.positionStream(),
      //       builder: (context, snapshot) {
      //         final position = snapshot.data?.inSeconds.toDouble() ?? 0;
      //         final mediaItem = audioPlayerHandler.currentItem;
      //         final duration = mediaItem?.duration?.inSeconds.toDouble() ?? 0;
      //         if (duration > 0 && position > 0) {
      //           return LinearProgressIndicator(value: position / duration);
      //         }
      //         return SizedBox.shrink();
      //       })
    ]);
  }

  Map<String, WidgetBuilder> _pageBuilders() {
    final builders = {
      '/home': (context) {
        // return SizedBox.shrink();
        return HomeWidget((ctx) => Navigator.push(
            ctx, MaterialPageRoute(builder: (_) => SearchWidget())));
      },
      '/artists': (_) => ArtistsWidget(),
      '/history': (_) => HistoryListWidget(),
      '/radio': (_) => RadioWidget(),
      '/player': (_) => PlayerWidget()
    };
    return builders;
  }
}
