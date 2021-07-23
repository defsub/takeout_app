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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:rxdart/rxdart.dart';
import 'package:connectivity/connectivity.dart';

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

void main() {
  Settings.init().then((_) async {
    audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.ryanheise.myapp.channel.audio',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationOngoing: true,
      ),
    );
    runApp(MyApp());
  });
}

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
      darkTheme: _darkTheme(),
    );
  }

  ThemeData _darkTheme() {
    final ThemeData base = ThemeData.dark();
    return base.copyWith(
      colorScheme: ColorScheme.dark().copyWith(
          primary: Colors.orangeAccent,
          primaryVariant: Colors.orangeAccent,
          secondary: Colors.orangeAccent,
          secondaryVariant: Colors.orangeAccent),
      indicatorColor: Colors.orangeAccent,
      accentColor: Colors.orangeAccent,
    );
  }
}

class _TakeoutWidget extends StatefulWidget {
  _TakeoutWidget({Key? key}) : super(key: key);

  @override
  TakeoutState createState() => TakeoutState();
}

class TakeoutState extends State<_TakeoutWidget> {
  static final _loginStream = BehaviorSubject<bool>();

  static Stream<bool> get loginStream => _loginStream.stream;

  static bool get isLoggedIn =>
      _loginStream.hasValue ? _loginStream.value : false;

  static void logout() async {
    await Client().logout();
    _loginStream.add(false);
  }

  static void login() => _loginStream.add(true);

  StreamSubscription<bool>? _loginSubscription;
  bool? _loggedIn;

  static final _connectivityStream = BehaviorSubject<ConnectivityResult>();

  static Stream<ConnectivityResult> get connectivityStream =>
      _connectivityStream.stream;

  // static ConnectivityResult get connectivityState => _connectivityStream.value;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  PlaybackState? _playbackState;
  int _selectedIndex = 0;
  HomeView? _homeView;
  ArtistsView? _artistsView;
  RadioView? _radioView;
  PlayerWidget? _playerWidget;

  @override
  void initState() {
    super.initState();

    _loginSubscription = _loginStream.listen(_onLogin);

    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .distinct()
        .listen(_updateConnectionStatus);

    Client().loggedIn().then((success) => success ? login() : logout());
  }

  @override
  void dispose() {
    super.dispose();
    snackBarStateSubject.close();
    _connectivitySubscription?.cancel();
    _loginSubscription?.cancel();
  }

  static bool _allowOrWifi(String key, ConnectivityResult? result) {
    final allow = Settings.getValue(key, false);
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
      print(e.toString());
      return Future.value(null);
    }

    if (!mounted) {
      return Future.value(null);
    }

    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.mobile:
      case ConnectivityResult.none:
        _connectivityStream.add(result);
        print('connectivity state $result');
        break;
      default:
        print('connectivity state failed');
        break;
    }
  }

  void _onLogin(bool loggedIn) {
    setState(() {
      _loggedIn = loggedIn;
      if (loggedIn) {
        _load();
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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

  void _load() async {
    TrackCache.init();
    Downloads.load();
    try {
      final client = Client();
      client.home().then((view) {
        _onHomeUpdated(view);
      });
      client.artists().then((view) {
        _onArtistsUpdated(view);
      });
      client.radio().then((view) {
        _onRadioUpdated(view);
      });
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

    audioHandler.playbackState.distinct().listen((state) {
      _onPlaybackState(state);
    });
  }

  Widget _item(int index) {
    switch (index) {
      case 0:
        return _homeView == null
            ? Center(child: CircularProgressIndicator())
            : HomeWidget(_homeView!);
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

          print('isFirstRouteInCurrentTab: ' +
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
                    floatingActionButton: (_playbackState != null &&
                            _playbackState!.processingState ==
                                AudioProcessingState.ready &&
                            _selectedIndex != 4)
                        ? FloatingActionButton(
                            onPressed: () {
                              if (_playbackState!.playing) {
                                audioHandler.pause();
                              } else {
                                audioHandler.play();
                              }
                            },
                            child: (_playbackState!.playing)
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
                    bottomNavigationBar: BottomNavigationBar(
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
                    )));
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

    HeroController _heroController;
    _heroController = HeroController(createRectTween: _createRectTween);

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

Widget allowStreamingIconButton(Icon icon, void Function() onPressed) {
  return StreamBuilder<ConnectivityResult>(
      stream: TakeoutState.connectivityStream.distinct(),
      builder: (context, snapshot) {
        final result = snapshot.data;
        return IconButton(
            icon: icon,
            onPressed:
                TakeoutState.allowStreaming(result) ? () => onPressed() : null);
      });
}

Widget allowDownloadIconButton(Icon icon, void Function() onPressed) {
  return StreamBuilder<ConnectivityResult>(
      stream: TakeoutState.connectivityStream.distinct(),
      builder: (context, snapshot) {
        final result = snapshot.data;
        return IconButton(
            icon: icon,
            onPressed:
                TakeoutState.allowDownload(result) ? () => onPressed() : null);
      });
}
