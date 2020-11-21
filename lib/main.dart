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

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import 'artists.dart';
import 'client.dart';
import 'home.dart';
import 'login.dart';
import 'music.dart';
import 'player.dart';
import 'playlist.dart';
import 'radio.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Takeout',
      home: AudioServiceWidget(child: _MyStatefulWidget()),
      darkTheme: _darkTheme(),
    );
  }

  ThemeData _darkTheme() {
    final ThemeData base = ThemeData.dark();
    return base.copyWith(
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.orangeAccent,
        inactiveTrackColor: Colors.grey,
        thumbColor: Colors.orangeAccent,
      ),
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

class SnackBarState {
  final Widget content;

  SnackBarState(this.content);
}

final snackBarStateSubject = PublishSubject<SnackBarState>();

class _MyStatefulWidget extends StatefulWidget {
  _MyStatefulWidget({Key key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<_MyStatefulWidget> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _loggedIn;
  PlaybackState _playbackState;
  int _selectedIndex = 0;
  HomeView _homeView;
  ArtistsView _artistsView;
  RadioView _radioView;
  PlayerWidget _playerWidget;

  List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>()
  ];

  @override
  void initState() {
    super.initState();
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
    super.dispose();
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
    final playlist = PlaylistFacade();
    playlist.sync().whenComplete(() => {
          playlist.load().then((spiff) {
            playlist.stage(spiff);
          })
        });
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

    snackBarStateSubject.listen((e) {
      _scaffoldKey.currentState.showSnackBar(SnackBar(content: e.content));
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
        return _radioView == null ? Text('loading') : RadioWidget(_radioView);
      case 3:
        if (_playerWidget == null) {
          print('loading player widget');
          _playerWidget = PlayerWidget();
          _playerWidget.doStart();
        }
        return _playerWidget;
      default:
        return Text('widget $index');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          final isFirstRouteInCurrentTab =
              !await _navigatorKeys[_selectedIndex].currentState.maybePop();

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
                    key: _scaffoldKey,
                    floatingActionButton: (_playbackState != null &&
                            _playbackState.processingState ==
                                AudioProcessingState.ready &&
                            _selectedIndex != 3)
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
                      ],
                    ),
                    bottomNavigationBar: BottomNavigationBar(
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
                          icon: Icon(Icons.radio),
                          label: 'Radio',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.queue_music),
                          label: 'Player',
                        ),
                      ],
                      currentIndex: _selectedIndex,
                      showSelectedLabels: true,
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
        key: _navigatorKeys[index],
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
