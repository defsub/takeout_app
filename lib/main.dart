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

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:connectivity/connectivity.dart';

import 'artists.dart';
import 'client.dart';
import 'home.dart';
import 'login.dart';
import 'music.dart';
import 'player.dart';
import 'playlist.dart';
import 'radio.dart';
import 'search.dart';
import 'global.dart';

void main() => runApp(new MyApp());

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Takeout',
      home: AudioServiceWidget(child: _TakeoutWidget()),
      darkTheme: _darkTheme(),
    );
  }

  ThemeData _darkTheme() {
    final ThemeData base = ThemeData.dark();
    return base.copyWith(
      disabledColor: Colors.white24,
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.orangeAccent,
        inactiveTrackColor: Colors.grey,
        thumbColor: Colors.orangeAccent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: Colors.black26.withOpacity(.85)),
      accentColor: Colors.orangeAccent,
      bottomNavigationBarTheme:
          BottomNavigationBarThemeData(selectedItemColor: Colors.orangeAccent),
      floatingActionButtonTheme:
          FloatingActionButtonThemeData(backgroundColor: Colors.orangeAccent),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(primary: Colors.orangeAccent)),
    );
  }
}

class _TakeoutWidget extends StatefulWidget {
  _TakeoutWidget({Key key}) : super(key: key);

  @override
  TakeoutState createState() => TakeoutState();
}

class TakeoutState extends State<_TakeoutWidget> {
  static final _connectivityStream = BehaviorSubject<ConnectivityResult>();

  static Stream<ConnectivityResult> get connectivityStream =>
      _connectivityStream.stream;

  static ConnectivityResult get connectivityState => _connectivityStream.value;

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult> _connectivitySubscription;

  bool _loggedIn;
  PlaybackState _playbackState;
  int _selectedIndex = 0;
  HomeView _homeView;
  ArtistsView _artistsView;
  RadioView _radioView;
  PlayerWidget _playerWidget;

  @override
  void initState() {
    super.initState();

    _initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);

    Client().loggedIn().then((v) {
      if (v) {
        _onLoginSuccess();
      } else {
        _onLogout();
      }
    });
  }

  @override
  void dispose() {
    snackBarStateSubject.close();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  static bool allowStreaming(ConnectivityResult result) {
    return result == ConnectivityResult.wifi;
  }

  static bool allowDownload(ConnectivityResult result) {
    // print('allow download ${result == ConnectivityResult.wifi}');
    return result == ConnectivityResult.wifi;
  }

  Future<void> _initConnectivity() async {
    ConnectivityResult result;
    try {
      result = await _connectivity.checkConnectivity();
    } catch (e) {
      print(e.toString());
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

  void _onLoginSuccess() {
    setState(() {
      _loggedIn = true;
      _load();
    });
  }

  void _onLogout() {
    setState(() {
      _loggedIn = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onHomeUpdated(HomeView view) {
    setState(() {
      _homeView = view;
    });
  }

  void _onArtistsUpdated(ArtistsView view) {
    setState(() {
      loadArtistMap(view.artists);
      _artistsView = view;
    });
  }

  void _onRadioUpdated(RadioView view) {
    setState(() {
      _radioView = view;
    });
  }

  void _onPlaybackState(PlaybackState playbackState) {
    setState(() {
      _playbackState = playbackState;
    });
  }

  void _load() async {
    if (_loggedIn != true) {
      return;
    }
    await MediaQueue.sync();
    MediaQueue.restore();
    final client = Client();
    client.home().then((view) {
      _onHomeUpdated(view);
    }).catchError((e) {
      _onLogout();
    });
    client.artists().then((view) {
      _onArtistsUpdated(view);
    }).catchError((e) {
      _onLogout();
    });
    client.radio().then((view) {
      _onRadioUpdated(view);
    }).catchError((e) {
      _onLogout();
    });

    AudioService.playbackStateStream.distinct().listen((state) {
      if (state == null) {
        return;
      }
      _onPlaybackState(state);
    });
  }

  Widget _widget(int index) {
    switch (index) {
      case 0:
        return _homeView == null ? Text('loading') : HomeWidget(_homeView);
      case 1:
        return _artistsView == null
            ? Text('loading')
            : ArtistsWidget(_artistsView);
      case 2:
        return SearchWidget();
      case 3:
        return _radioView == null ? Text('loading') : RadioWidget(_radioView);
      case 4:
        if (_playerWidget == null) {
          print('loading player widget');
          _playerWidget = PlayerWidget();
          final params = Map<String, dynamic>();
          // TODO need params still?
          PlayerWidget.doStart(params);
        }
        return _playerWidget;
      default:
        return Text('widget $index');
    }
  }

  Widget _drawer(BuildContext context) {
    return Drawer(
        child: ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          child: Text('Takeout'),
          decoration: BoxDecoration(
            color: Colors.blue,
          ),
        ),
        ListTile(
          title: Text('Item 1'),
          onTap: () {
            // Update the state of the app
            // ...
            // Then close the drawer
            showSnackBar('testing');
            Navigator.pop(context);
          },
        ),
      ],
    ));
  }

  StreamSubscription<SnackBarState> snackBarSubscription;

  @override
  Widget build(BuildContext context) {
    if (snackBarSubscription != null) {
      snackBarSubscription.cancel();
    }
    snackBarSubscription = snackBarStateSubject.listen((e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: e.content));
    });

    return WillPopScope(
        onWillPop: () async {
          final isFirstRouteInCurrentTab =
              !await navigatorKeys[_selectedIndex].currentState.maybePop();

          print('isFirstRouteInCurrentTab: ' +
              isFirstRouteInCurrentTab.toString());

          // let system handle back button if we're on the first route
          return isFirstRouteInCurrentTab;
        },
        child: _loggedIn == null
            ? Container(child: Center(child: Text('loading')))
            : _loggedIn == false
                ? LoginWidget(() => _onLoginSuccess())
                : Scaffold(
                    key: _scaffoldMessengerKey,
                    floatingActionButton: (_playbackState != null &&
                            _playbackState.processingState ==
                                AudioProcessingState.ready &&
                            _selectedIndex != 4)
                        ? FloatingActionButton(
                            onPressed: () {
                              if (_playbackState.playing) {
                                AudioService.pause();
                              } else {
                                AudioService.play();
                              }
                            },
                            child: (_playbackState.playing)
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
                      items: const <BottomNavigationBarItem>[
                        BottomNavigationBarItem(
                          icon: Icon(Icons.home),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.people_alt),
                          label: 'Artists',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.search),
                          label: 'Search',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.radio),
                          label: 'Radio',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.queue_music),
                          label: 'Player',
                        ),
                      ],
                      currentIndex: _selectedIndex,
                      onTap: _onItemTapped,
                    )));
  }

  Map<String, WidgetBuilder> _routeBuilders(BuildContext context, int index) {
    return {
      '/': (context) {
        return [
          _widget(0),
          _widget(1),
          _widget(2),
          _widget(3),
          _widget(4),
        ].elementAt(index);
      },
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
        onGenerateRoute: (routeSettings) {
          return MaterialPageRoute(
            builder: (context) => routeBuilders[routeSettings.name](context),
          );
        },
      ),
    );
  }

  RectTween _createRectTween(Rect begin, Rect end) {
    return MaterialRectArcTween(begin: begin, end: end);
  }
}
