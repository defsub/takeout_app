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
import 'package:takeout_lib/api/model.dart';
import 'package:takeout_lib/cache/track.dart';
import 'package:takeout_lib/empty.dart';
import 'package:takeout_lib/index/index.dart';
import 'package:takeout_lib/page/page.dart';
import 'package:takeout_lib/player/player.dart';
import 'package:takeout_lib/util.dart';
import 'package:takeout_watch/app/context.dart';
import 'package:takeout_watch/music.dart';
import 'package:takeout_watch/platform.dart';
import 'package:takeout_watch/podcasts.dart';
import 'package:takeout_watch/radio.dart';
import 'package:takeout_watch/settings.dart';

import 'about.dart';
import 'downloads.dart';
import 'history.dart';
import 'list.dart';
import 'player.dart';

class HomeEntry {
  final Widget title;
  final Widget? subtitle;
  final Widget? icon;
  final void Function(BuildContext, HomeView)? onSelected;

  HomeEntry(this.title, {this.icon, this.subtitle, this.onSelected});
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
    return Builder(builder: (context) {
      final index = context.watch<IndexCubit>().state;
      final trackCache = context.watch<TrackCacheCubit>().state;
      final entries = [
        // TODO hide if not playing
        HomeEntry(const PlayerTitle(),
            // icon: playerButton(),
            subtitle: const PlayerArtist(),
            onSelected: (context, state) => onPlayer(context, state)),
        if (index.music)
          HomeEntry(Text(context.strings.musicLabel),
              // icon: const Icon(Icons.music_note),
              onSelected: (context, state) => onMusic(context, state)),
        if (index.podcasts)
          HomeEntry(Text(context.strings.podcastsLabel),
              // icon: const Icon(Icons.podcasts),
              onSelected: (context, state) => onPodcasts(context, state)),
        HomeEntry(Text(context.strings.historyLabel),
            // icon: const Icon(Icons.history),
            onSelected: (context, state) => onHistory(context, state)),
        if (index.music)
          HomeEntry(Text(context.strings.radioLabel),
              // icon: const Icon(Icons.radio),
              onSelected: (context, state) => onRadio(context, state)),
        if (trackCache.isNotEmpty)
          HomeEntry(Text(context.strings.downloadsLabel),
              // icon: const Icon(Icons.cloud_download_outlined),
              onSelected: (context, state) => onDownloads(context, state)),
        HomeEntry(Text(context.strings.aboutLabel),
            // icon: const Icon(Icons.info_outline),
            onSelected: (context, state) => onAbout(context, state)),
        HomeEntry(homeControls(context, state)),
      ];
      return Scaffold(
          body: RefreshIndicator(
              onRefresh: () => reloadPage(context),
              child: RotaryList<HomeEntry>(entries,
                  tileBuilder: (context, entry) =>
                      homeTile(context, entry, state))));
    });
  }

  Widget homeTile(BuildContext context, HomeEntry entry, HomeView state) {
    return ListTile(
        leading: entry.icon,
        title: Center(child: entry.title),
        subtitle: entry.subtitle != null ? Center(child: entry.subtitle) : null,
        onTap: () => entry.onSelected?.call(context, state));
  }

  Widget homeControls(BuildContext context, HomeView state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () => platformSoundSettings()),
        IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => onSettings(context, state)),
        IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: () => platformBluetoothSettings()),
      ],
    );
  }

  Widget playerButton() {
    return BlocBuilder<Player, PlayerState>(
        buildWhen: (_, state) => state is PlayerProcessingState,
        builder: (context, state) {
          if (state is PlayerProcessingState) {
            if (state.buffering) {
              return const SizedBox.square(
                  dimension: 24, child: CircularProgressIndicator());
            } else if (state.playing) {
              return IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.pause),
                  onPressed: () => context.player.pause());
            } else {
              return IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => context.player.play());
            }
          }
          return const EmptyWidget();
        });
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

  void onHistory(BuildContext context, HomeView _) {
    Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => const HistoryPage()));
  }

  void onDownloads(BuildContext context, HomeView _) {
    Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => const DownloadsPage()));
  }

  void onSettings(BuildContext context, HomeView _) {
    Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  void onAbout(BuildContext context, HomeView _) {
    Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => const AboutPage()));
  }

  void onPlayer(BuildContext context, HomeView _) {
    Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => const PlayerPage()));
  }
}
