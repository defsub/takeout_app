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
import 'package:takeout_lib/api/model.dart';
import 'package:takeout_lib/page/page.dart';
import 'package:takeout_watch/app/context.dart';
import 'package:takeout_watch/list.dart';
import 'package:takeout_watch/media.dart';
import 'package:takeout_watch/player.dart';

class MusicPage extends StatelessWidget {
  final HomeView state;

  const MusicPage(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    final releases = state.added; // TODO assuming added
    return PageView(children: [
      MediaPage(releases,
          onMediaEntry: (context, entry) =>
              _onRelease(context, entry as Release)),
      ArtistsPage(),
    ]);
  }
}

class ArtistsPage extends ClientPage<ArtistsView> {
  ArtistsPage({super.key});

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.artists();
  }

  @override
  Widget page(BuildContext context, ArtistsView state) {
    final artists = state.artists;
    return Scaffold(
        body: RefreshIndicator(
            onRefresh: () => reloadPage(context),
            child: CustomScrollView(slivers: [
              const SliverAppBar(
                  automaticallyImplyLeading: false,
                  floating: true,
                  title: Center(
                      child: Text('Artists', overflow: TextOverflow.ellipsis))),
              SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                return artistTile(context, artists[index]);
              }, childCount: artists.length)),
            ])));
  }

  Widget artistTile(BuildContext context, Artist artist) {
    return ListTile(
        title: Center(child: Text(artist.name)),
        onTap: () => onArtist(context, artist));
  }

  void onArtist(BuildContext context, Artist artist) {
    Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => ArtistPage(artist)));
  }
}

class ArtistPage extends ClientPage<ArtistView> {
  final Artist artist;

  ArtistPage(this.artist, {super.key});

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.artist(artist.id);
  }

  @override
  Widget page(BuildContext context, ArtistView state) {
    final releases = state.releases;
    return Scaffold(
        body: RefreshIndicator(
            onRefresh: () => reloadPage(context),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                    automaticallyImplyLeading: false,
                    floating: true,
                    title: Center(
                        child: Text(artist.name,
                            overflow: TextOverflow.ellipsis))),
                SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return MediaGridTile(
                        releases[index],
                        onMediaEntry: (context, entry) =>
                            _onRelease(context, entry as Release),
                      );
                    }, childCount: releases.length))
              ],
            )));
  }
}

class ReleasePage extends ClientPage<ReleaseView> {
  final Release release;

  ReleasePage(this.release, {super.key});

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.release(release.id);
  }

  @override
  Widget page(BuildContext context, ReleaseView state) {
    final tracks = state.tracks;
    return Scaffold(
        body: RefreshIndicator(
            onRefresh: () => reloadPage(context),
            child: RotaryList<Track>(tracks, tileBuilder: trackTile)));
  }

  Widget trackTile(BuildContext context, Track t) {
    Widget? subtitle;
    if (t.trackArtist != release.artist) {
      subtitle =
          Center(child: Text(t.trackArtist, overflow: TextOverflow.ellipsis));
    }
    return ListTile(
        title: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${t.trackNum}. ',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis),
          Text(t.title, overflow: TextOverflow.ellipsis),
        ]),
        subtitle: subtitle,
        onTap: () => onTrack(context, t));
  }

  void onPlay(BuildContext context) {
    context.playlist.replace(release.reference);
    showPlayer(context);
  }

  void onTrack(BuildContext context, Track t) {
    context.playlist.replace(release.reference, index: t.trackIndex);
    showPlayer(context);
  }
}

void _onRelease(BuildContext context, Release release) {
  Navigator.push(
      context, MaterialPageRoute<void>(builder: (_) => ReleasePage(release)));
}
