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

import 'package:audio_service/audio_service.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:rxdart/rxdart.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'artists.dart';
import 'client.dart';
import 'home.dart';
import 'login.dart';
import 'schema.dart';
import 'player.dart';
import 'player_handler.dart';
import 'playlist.dart';
import 'radio.dart';
import 'search.dart';
import 'global.dart';
import 'downloads.dart';
import 'cache.dart';
import 'settings.dart';
import 'progress.dart';
import 'live.dart';

late AudioPlayerHandler audioPlayerHandler;

void main() {
  // setup the logger
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName}: ${record.message}');
  });

  Settings.init().then((_) async {
    audioPlayerHandler = AudioPlayerHandler();
    audioHandler = await AudioService.init(
      builder: () => audioPlayerHandler,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.defsub.takeout.channel.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
        fastForwardInterval: Duration(seconds: 30),
        rewindInterval: Duration(seconds: 10),
      ),
    );
    WidgetsFlutterBinding.ensureInitialized();
    runApp(MyApp());
  });
}

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
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
    });
  }

  // ThemeData _darkTheme() {
  //   final ThemeData base = ThemeData.dark();
  //   return base.copyWith(
  //     colorScheme: ColorScheme.dark().copyWith(
  //         primary: Colors.orangeAccent,
  //         primaryContainer: Colors.orangeAccent,
  //         secondary: Colors.orangeAccent,
  //         secondaryContainer: Colors.orangeAccent),
  //     indicatorColor: Colors.orangeAccent,
  //   );
  // }
}

class _TakeoutWidget extends StatefulWidget {
  _TakeoutWidget({Key? key}) : super(key: key);

  @override
  TakeoutState createState() => TakeoutState();
}

class TakeoutState extends State<_TakeoutWidget> with WidgetsBindingObserver {
  static final log = Logger('TakeoutState');
  static final _loginStream = BehaviorSubject<bool>();

  static Stream<bool> get loginStream => _loginStream.stream;

  static bool get isLoggedIn =>
      _loginStream.hasValue ? _loginStream.value : false;

  static Future<void> logout() async {
    await Client().logout();
    _loginStream.add(false);
  }

  static void login() => _loginStream.add(true);

  StreamSubscription<bool>? _loginSubscription;
  bool? _loggedIn;

  static final _connectivityStream = BehaviorSubject<ConnectivityResult>();

  static ValueStream<ConnectivityResult> get connectivityStream =>
      _connectivityStream.stream;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  PlaybackState? _playbackState;
  int _selectedIndex = 0;
  IndexView? _indexView;
  HomeView? _homeView;
  ArtistsView? _artistsView;
  RadioView? _radioView;
  PlayerWidget? _playerWidget;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loginSubscription = _loginStream.listen(_onLogin);

    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .distinct()
        .listen(_updateConnectionStatus);

    Client().loggedIn().then((success) => success ? login() : logout());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    snackBarStateSubject.close();
    _connectivitySubscription?.cancel();
    _loginSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // check connectivity after being away
        _connectivity
            .checkConnectivity()
            .then((value) => _updateConnectionStatus(value));
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  static bool _allowOrWifi(String key, ConnectivityResult? result) {
    final allow = Settings.getValue<bool>(key, defaultValue: false) ?? false;
    return allow || result == ConnectivityResult.wifi;
  }

  static bool allowStreaming(ConnectivityResult? result) {
    return _allowOrWifi(settingAllowStreaming, result);
  }

  static bool allowDownload(ConnectivityResult? result) {
    return _allowOrWifi(settingAllowDownload, result);
  }

  static bool allowArtistArtwork(ConnectivityResult? result) {
    return _allowOrWifi(settingAllowArtistArtwork, result);
  }

  Future<void> _initConnectivity() async {
    ConnectivityResult result;
    try {
      result = await _connectivity.checkConnectivity();
    } catch (e) {
      log.warning(e);
      return Future.value();
    }

    if (!mounted) {
      return Future.value();
    }

    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
      case ConnectivityResult.none:
        _connectivityStream.add(result);
        log.finer('connectivity state $result');
        break;
      default:
        log.warning('connectivity state failed');
        break;
    }
  }

  void _onLogin(bool loggedIn) {
    setState(() {
      _loggedIn = loggedIn;
      if (loggedIn) {
        _load();
        _live();
      }
    });
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      navigatorKeys[_selectedIndex]
          .currentState!
          .popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _onIndexUpdated(IndexView view) {
    if (mounted) {
      setState(() {
        _indexView = view;
      });
    }
  }

  void _onHomeUpdated(HomeView view) {
    if (mounted) {
      setState(() {
        _homeView = view;
      });
    }
  }

  void _onArtistsUpdated(ArtistsView view) {
    if (mounted) {
      setState(() {
        loadArtistMap(view.artists);
        _artistsView = view;
      });
    }
  }

  void _onRadioUpdated(RadioView view) {
    if (mounted) {
      setState(() {
        _radioView = view;
      });
    }
  }

  void _onPlaybackState(PlaybackState playbackState) {
    if (mounted) {
      setState(() {
        _playbackState = playbackState;
      });
    }
  }

  // This will auto-pause playback for remote media when streaming is disabled.
  void _onMediaItem(MediaItem? mediaItem) {
    if (_playbackState?.playing == true) {
      final streaming = mediaItem?.isRemote() ?? false;
      if (streaming && allowStreaming(connectivityStream.value) == false) {
        log.finer('mediaItem pause due to loss of wifi');
        audioHandler.pause();
      }
    }
  }

  Future<LiveClient> _createLiveClient(Client client) async {
    final token = await client.getAccessToken();
    final url = await client.getEndpoint();
    final uri = Uri.parse(url);
    return LiveClient('${uri.host}:${uri.port}', token!);
  }

  LiveFollow? _liveFollow;
  LiveShare? _liveShare;

  void _onLiveChange(LiveType liveType) async {
    _liveFollow?.stop();
    _liveFollow = null;
    _liveShare?.stop();
    _liveShare = null;
    if (liveType == LiveType.none) {
      return;
    }
    final client = Client();
    final live = await _createLiveClient(client);
    if (liveType == LiveType.follow) {
      _liveFollow = LiveFollow(live, audioHandler);
      _liveFollow!.start();
    } else if (settingsLiveType() == LiveType.share) {
      _liveShare = LiveShare(live, audioHandler);
      _liveShare!.start();
    }
  }

  void _live() async {
    // start with the current value
    _onLiveChange(settingsLiveType());
    // listen for changes
    settingsChangeSubject.listen((setting) {
      if (setting == settingLiveMode) {
        _onLiveChange(settingsLiveType());
      }
    });
  }

  void _load() async {
    audioHandler.playbackState
        .distinct()
        .listen((state) => _onPlaybackState(state));
    audioHandler.mediaItem
        .distinct()
        .listen((mediaItem) => _onMediaItem(mediaItem));

    await TrackCache.init();
    await OffsetCache.init();
    await Downloads.prune().whenComplete(() => Downloads.load());
    try {
      final client = Client();
      client.index().then((view) => _onIndexUpdated(view));
      client.home().then((view) => _onHomeUpdated(view));
      client.artists().then((view) => _onArtistsUpdated(view));
      client.radio().then((view) => _onRadioUpdated(view));
      await Progress.sync();
      await MediaQueue.sync();
      if (audioHandler.playbackState.hasValue == false ||
          (audioHandler.playbackState.hasValue &&
              audioHandler.playbackState.value.playing == false)) {
        MediaQueue.restore();
      }
    } on ClientException catch (e) {
      if (e.authenticationFailed) {
        logout();
      }
    } on TlsException catch (e) {
      showErrorDialog(context, e.message);
    }
  }

  Widget _item(int index) {
    switch (index) {
      case 0:
        return _homeView == null || _indexView == null
            ? Center(child: CircularProgressIndicator())
            : HomeWidget(
                _indexView!, _homeView!); // FIXME _indexView was null?!
      case 1:
        return _artistsView == null
            ? Center(child: CircularProgressIndicator())
            : ArtistsWidget(_artistsView!);
      case 2:
        return SearchWidget();
      case 3:
        return _radioView == null
            ? Center(child: CircularProgressIndicator())
            : RadioWidget(_radioView!);
      case 4:
        if (_playerWidget == null) {
          _playerWidget = PlayerWidget();
        }
        return _playerWidget!;
      default:
        return Text('widget $index');
    }
  }

  StreamSubscription<SnackBarState>? snackBarSubscription;

  @override
  Widget build(final BuildContext context) {
    snackBarSubscription?.cancel();
    snackBarSubscription = snackBarStateSubject.listen((e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: e.content));
    });

    return WillPopScope(
        onWillPop: () async {
          final isFirstRouteInCurrentTab =
              !await navigatorKeys[_selectedIndex].currentState!.maybePop();

          log.fine('isFirstRouteInCurrentTab: ' +
              isFirstRouteInCurrentTab.toString());

          // let system handle back button if we're on the first route
          return isFirstRouteInCurrentTab;
        },
        child: _loggedIn == null
            ? Center(child: CircularProgressIndicator())
            : _loggedIn == false
                ? LoginWidget(() => login())
                : Scaffold(
                    key: _scaffoldMessengerKey,
                    floatingActionButton: (_playbackState?.processingState ==
                                AudioProcessingState.ready &&
                            !_showingPlayer())
                        ? FloatingActionButton(
                            onPressed: () {
                              if (_playbackState?.playing == true) {
                                audioHandler.pause();
                              } else {
                                audioHandler.play();
                              }
                            },
                            child: (_playbackState?.playing == true)
                                ? Icon(Icons.pause)
                                : Icon(Icons.play_arrow),
                          )
                        : null,
                    body: Stack(
                      children: [
                        _buildOffstageNavigator(0),
                        _buildOffstageNavigator(1),
                        _buildOffstageNavigator(2),
                        _buildOffstageNavigator(3),
                        _buildOffstageNavigator(4),
                      ],
                    ),
                    bottomNavigationBar: _bottomNavigation()));
  }

  bool _showingPlayer() {
    return _selectedIndex == 4;
  }

  Widget _bottomNavigation() {
    return Stack(children: [
      BottomNavigationBar(
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
            icon: Icon(Icons.search),
            label: AppLocalizations.of(context)!.navSearch,
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
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      if (!_showingPlayer())
        StreamBuilder<Duration>(
            stream: audioPlayerHandler.positionStream(),
            builder: (context, snapshot) {
              final position = snapshot.data?.inSeconds.toDouble() ?? 0;
              final mediaItem = audioPlayerHandler.currentItem;
              final duration = mediaItem?.duration?.inSeconds.toDouble() ?? 0;
              if (duration > 0 && position > 0) {
                return LinearProgressIndicator(value: position / duration);
              }
              return SizedBox();
            })
    ]);
  }

  Map<String, WidgetBuilder> _routeBuilders(BuildContext context, int index) {
    return {
      '/': (context) => [
            _item(0),
            _item(1),
            _item(2),
            _item(3),
            _item(4),
          ].elementAt(index)
    };
  }

  Widget _buildOffstageNavigator(int index) {
    final routeBuilders = _routeBuilders(context, index);
    final _heroController = HeroController(createRectTween: _createRectTween);

    return Offstage(
      offstage: _selectedIndex != index,
      child: Navigator(
          observers: [_heroController],
          key: navigatorKeys[index],
          onGenerateRoute: (routeSettings) => MaterialPageRoute(
                builder: (context) =>
                    routeBuilders[routeSettings.name]!(context),
              )),
    );
  }

  RectTween _createRectTween(Rect? begin, Rect? end) {
    return MaterialRectArcTween(begin: begin, end: end);
  }
}

Color overlayIconColor(BuildContext context) {
  // Theme.of(context).colorScheme.onBackground
  return Colors.white;
}

Widget allowStreamingIconButton(
    BuildContext context, Icon icon, void Function() onPressed) {
  return StreamBuilder<ConnectivityResult>(
      stream: TakeoutState.connectivityStream.distinct(),
      builder: (context, snapshot) {
        final result = snapshot.data;
        return IconButton(
            color: overlayIconColor(context),
            icon: icon,
            onPressed:
                TakeoutState.allowStreaming(result) ? () => onPressed() : null);
      });
}

Widget allowDownloadIconButton(
    BuildContext context, Icon icon, void Function() onPressed) {
  return StreamBuilder<ConnectivityResult>(
      stream: TakeoutState.connectivityStream.distinct(),
      builder: (context, snapshot) {
        final result = snapshot.data;
        return IconButton(
            color: overlayIconColor(context),
            icon: icon,
            onPressed:
                TakeoutState.allowDownload(result) ? () => onPressed() : null);
      });
}
