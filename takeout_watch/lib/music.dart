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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:takeout_lib/api/model.dart';
import 'package:takeout_lib/page/page.dart';
import 'package:takeout_lib/settings/model.dart';
import 'package:takeout_watch/app/context.dart';
import 'package:takeout_watch/dialog.dart';
import 'package:takeout_watch/list.dart';
import 'package:takeout_watch/media.dart';
import 'package:takeout_watch/player.dart';
import 'package:takeout_watch/settings.dart';

class MusicPage extends StatelessWidget {
  final HomeView state;

  const MusicPage(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    List<Release> releases;
    switch (context.settings.state.settings.homeGridType) {
      case HomeGridType.mix:
      case HomeGridType.added:
        releases = state.added;
        break;
      default:
        releases = state.released;
        break;
    }
    return MediaPage(releases,
        title: context.strings.musicLabel,
        onLongPress: (context, entry) => _onDownload(context, entry as Release),
        onTap: (context, entry) => _onRelease(context, entry as Release));
  }
}

class ArtistsPage extends ClientPage<ArtistsView> {
  ArtistsPage({super.key});

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.artists(ttl: ttl);
  }

  @override
  Widget page(BuildContext context, ArtistsView state) {
    return Scaffold(
        body: RefreshIndicator(
      onRefresh: () => reloadPage(context),
      child: RotaryList<Artist>(state.artists,
          tileBuilder: artistTile, title: context.strings.artistsLabel),
    ));
  }

  Widget artistTile(BuildContext context, Artist artist) {
    return ListTile(
        title: Text(artist.name), onTap: () => onArtist(context, artist));
  }

  void onArtist(BuildContext context, Artist artist) {
    Navigator.push(
        context, CupertinoPageRoute<void>(builder: (_) => ArtistPage(artist)));
  }
}

class ArtistPage extends ClientPage<ArtistView> {
  final Artist artist;

  ArtistPage(this.artist, {super.key});

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.artist(artist.id, ttl: ttl);
  }

  @override
  Widget page(BuildContext context, ArtistView state) {
    final releases = state.releases;
    return MediaPage(releases,
        title: state.artist.name,
        onLongPress: (context, entry) => _onDownload(context, entry as Release),
        onTap: (context, entry) => _onRelease(context, entry as Release));
  }
}

class ReleasePage extends ClientPage<ReleaseView> {
  final Release release;

  ReleasePage(this.release, {super.key});

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.release(release.id, ttl: ttl);
  }

  @override
  Widget page(BuildContext context, ReleaseView state) {
    final tracks = state.tracks;
    return Scaffold(
        body: RefreshIndicator(
            onRefresh: () => reloadPage(context),
            child: RotaryList<Track>(tracks,
                title: state.release.name,
                subtitle: state.release.artist,
                tileBuilder: trackTile)));
  }

  Widget trackTile(BuildContext context, Track t) {
    Text? subtitle;
    if (t.trackArtist != release.artist) {
      subtitle = Text(t.trackArtist);
    }
    final enableStreaming = allowStreaming(context);
    return ListTile(
        enabled: enableStreaming,
        // leading: Text('${t.trackNum}.',
        //     style: Theme.of(context).textTheme.bodySmall),
        title: Text(t.title),
        subtitle: subtitle,
        onTap: () => onTrack(context, t));
  }

  void onTrack(BuildContext context, Track t) {
    context.playlist.replace(
      release.reference,
      index: t.trackIndex,
      creator: release.creator,
      title: release.name,
    );
    showPlayer(context);
  }
}

void _onRelease(BuildContext context, Release release) {
  Navigator.push(
      context, CupertinoPageRoute<void>(builder: (_) => ReleasePage(release)));
}

void _onDownload(BuildContext context, Release release) {
  if (allowDownload(context)) {
    confirmDialog(context,
            title: context.strings.confirmDownload, body: release.name)
        .then((confirmed) {
      if (confirmed != null && confirmed) {
        context.downloadRelease(release);
      }
    });
  }
}
