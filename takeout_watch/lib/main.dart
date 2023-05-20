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
import 'package:takeout_lib/api/client.dart';
import 'package:takeout_lib/api/model.dart';
import 'package:takeout_lib/context/bloc.dart';
import 'package:takeout_lib/empty.dart';
import 'package:takeout_lib/page/page.dart';
import 'package:takeout_watch/app/app.dart';
import 'package:takeout_watch/app/bloc.dart';
import 'package:takeout_watch/app/context.dart';
import 'package:takeout_watch/music.dart';
import 'package:takeout_watch/podcasts.dart';
import 'package:takeout_watch/radio.dart';
import 'package:wear/wear.dart';

import 'button.dart';
import 'player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TakeoutBloc.initStorage();

  runApp(const WatchApp());
}

class WatchApp extends StatelessWidget {
  const WatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBloc().init(context,
        child: WatchShape(builder: (context, shape, child) {
      print('ambient shape is $shape');
      return AmbientMode(
        builder: (context, mode, child) {
          print('ambient mode is $mode');
          return mode == WearMode.active
              ? MaterialApp(
                  theme: ThemeData.dark(useMaterial3: true).copyWith(
                    visualDensity: VisualDensity.compact,
                  ),
                  home: const MainPage(),
                )
              : const EmptyWidget();
        },
        onUpdate: () {
          print('ambient onUpdate');
        },
      );
    }));
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with AppBlocState, WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    appInitState(context);

    final settings = context.settings.state.settings;
    if (settings.host == 'https://example.com') {
      // TODO need UI to enter host
      context.settings.host = 'https://takeout.fm';
    }
  }

  @override
  void dispose() {
    appDispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.connectivity.check();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppCubit>().state;
    return state.authenticated ? HomePage() : const ConnectPage();
  }
}

class HomeEntry {
  final String title;
  final void Function(BuildContext, HomeView) onSelected;

  HomeEntry(this.title, this.onSelected);
}

class HomePage extends ClientPage<HomeView> {
  HomePage({super.key});

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.home(ttl: ttl);
  }

  @override
  void reload(BuildContext context) {
    super.reload(context);
    context.reload();
  }

  @override
  Widget page(BuildContext context, HomeView state) {
    return Scaffold(
        body: Builder(
            builder: (context) => RefreshIndicator(
                onRefresh: () => reloadPage(context),
                // TODO refresh not working
                child: Stack(
                  children: [
                    Align(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            CircleButton(
                                icon: const Icon(Icons.podcasts),
                                onPressed: () => onPodcasts(context, state)),
                            CircleButton(
                              icon: const Icon(Icons.radio),
                              onPressed: () => onRadio(context, state),
                            ),
                          ],
                        )),
                    Align(
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            CircleButton(
                              icon: const Icon(Icons.music_note),
                              onPressed: () => onMusic(context, state),
                            ),
                            CircleButton(
                              icon: const Icon(Icons.queue_music),
                              onPressed: () => onPlayer(context, state),
                            ),
                          ],
                        ))
                  ],
                ))));
  }

  void onMusic(BuildContext context, HomeView state) {
    Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => MusicPage(state)));
  }

  void onPodcasts(BuildContext context, HomeView state) {
    Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => PodcastsPage(state)));
  }

  void onRadio(BuildContext context, HomeView _) {
    Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => RadioPage()));
  }

  void onPlayer(BuildContext context, HomeView _) {
    Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => const PlayerPage()));
  }
}

class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextButton(
                child: const Text('Connect'),
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute<void>(builder: (_) => CodePage()));
                }),
          ],
        ),
      ),
    );
  }
}

class CodePage extends ClientPage<AccessCode> {
  CodePage({super.key});

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.code();
  }

  void check(BuildContext context, AccessCode state) {
    context.clientRepository.checkCode(state).then((success) {
      if (success) {
        Navigator.pop(context);
      } else {
        print('not linked yet');
      }
    }).onError((error, stackTrace) {
      if (error is InvalidCodeError) {
        print('bummer, try again');
        reload(context);
      }
    });
  }

  @override
  Widget page(BuildContext context, AccessCode state) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(context.settings.state.settings.host),
            const SizedBox(height: 16),
            Text(state.code),
            TextButton(
                child: const Text('Next >'),
                onPressed: () => check(context, state)),
          ],
        ),
      ),
    );
  }
}
