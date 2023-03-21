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

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:logging/logging.dart';
import 'package:takeout_app/app/app.dart';
import 'package:takeout_app/app/bloc.dart';
import 'package:takeout_app/app/context.dart';
import 'package:takeout_app/history/widget.dart';
import 'package:takeout_app/player/player.dart';
import 'package:takeout_app/player/widget.dart';

import 'artists.dart';
import 'global.dart';
import 'home.dart';
import 'login.dart';
import 'radio.dart';
import 'search.dart';

void main() async {
  // setup the logger
  Logger.root.level = Level.FINE;
  Logger.root.onRecord.listen((record) {
    print('${record.loggerName}: ${record.message}');
  });

  WidgetsFlutterBinding.ensureInitialized();

  await appMain();

  runApp(TakeoutApp());
}

// TODO what's this for now? snack bar?
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class TakeoutApp extends StatelessWidget with AppBloc {
  @override
  Widget build(BuildContext context) {
    return appInit(context, child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      return MaterialApp(
          onGenerateTitle: (context) => context.strings.takeoutTitle,
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
    }));
  }
}

class _TakeoutWidget extends StatefulWidget {
  _TakeoutWidget({Key? key}) : super(key: key);

  @override
  _TakeoutState createState() => _TakeoutState();
}

class _TakeoutState extends State<_TakeoutWidget>
    with AppBlocState, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appInitState(context);
  }

  @override
  void dispose() {
    appDispose();
    WidgetsBinding.instance.removeObserver(this);
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

  @override
  Widget build(final BuildContext context) {
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
  }

  Widget _fab(BuildContext context) {
    return BlocBuilder<Player, PlayerState>(builder: (context, state) {
      bool playing = false;
      double? progress;

      if (context.app.state.index == NavigationIndex.player) {
        return SizedBox.shrink();
      }

      if (state is PlayerInit ||
          state is PlayerReady ||
          state is PlayerLoad ||
          state is PlayerStop) {
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
              label: context.strings.navHome,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_alt),
              label: context.strings.navArtists,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: context.strings.navHistory,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.radio),
              label: context.strings.navRadio,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.queue_music),
              label: context.strings.navPlayer,
            ),
          ],
          currentIndex: index,
          onTap: (index) => _onNavTapped(context, index),
        );
      }),
    ]);
  }

  Map<String, WidgetBuilder> _pageBuilders() {
    final builders = {
      '/home': (_) =>
          HomeWidget((ctx) => Navigator.push(
              ctx, MaterialPageRoute(builder: (_) => SearchWidget()))),
      '/artists': (_) => ArtistsWidget(),
      '/history': (_) => HistoryListWidget(),
      '/radio': (_) => RadioWidget(),
      '/player': (_) => PlayerWidget()
    };
    return builders;
  }
}
