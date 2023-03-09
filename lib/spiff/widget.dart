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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:takeout_app/app/context.dart';
import 'package:takeout_app/art/scaffold.dart';
import 'package:takeout_app/cache/offset.dart';
import 'package:takeout_app/cache/track.dart';
import 'package:takeout_app/menu.dart';
import 'package:takeout_app/buttons.dart';
import 'package:takeout_app/util.dart';
import 'package:takeout_app/style.dart';
import 'package:takeout_app/art/cover.dart';
import 'package:takeout_app/client/client.dart';
import 'package:takeout_app/client/download.dart';
import 'package:takeout_app/page/page.dart';
import 'package:takeout_app/tiles.dart';
import 'model.dart';

typedef FetchSpiff = void Function(ClientCubit, {Duration? ttl});

class SpiffWidget extends ClientPage<Spiff> {
  final FetchSpiff? fetch;

  SpiffWidget({super.value, this.fetch});

  @override
  void load(BuildContext context, {Duration? ttl}) {
    fetch?.call(context.client, ttl: ttl);
  }

  List<Widget>? actions(BuildContext context) {
    return [
      popupMenu(context, [
        if (fetch != null)
          PopupItem.refresh(context, (_) => refreshPage(context)),
      ]),
    ];
  }

  Widget bottomRight(BuildContext context, Spiff spiff, bool isCached) {
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(IconsDownloadDone),
            onPressed: () => {})
        : downloadButton(context, spiff, isCached);
  }

  Widget subtitle(BuildContext context, Spiff spiff) {
    final text = spiff.playlist.creator;
    return text == null
        ? SizedBox.shrink()
        : Text(text, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget downloadButton(BuildContext context, Spiff spiff, bool isCached) {
    return isCached
        ? IconButton(
            color: Theme.of(context).primaryColorLight,
            icon: Icon(IconsDownload),
            onPressed: () => {})
        : DownloadButton(
            onPressed: () => context.download.addSpiff(spiff));
  }

  @override
  Widget page(BuildContext context, Spiff spiff) {
    return scaffold(context, image: spiff.cover, body: body(context, spiff));
  }

  Widget body(BuildContext context, Spiff spiff) {
    final trackCache = context.watch<TrackCacheCubit>();
    final isCached = trackCache.state.containsAll(spiff.playlist.tracks);

    // cover images are 250x250 (or 500x500)
    // distort a bit to only take half the screen
    final screen = MediaQuery.of(context).size;
    final expandedHeight = screen.height / 2;

    return CustomScrollView(slivers: [
      SliverAppBar(
        foregroundColor: overlayIconColor(context),
        expandedHeight: expandedHeight,
        actions: actions(context),
        flexibleSpace: FlexibleSpaceBar(
            // centerTitle: true,
            // title: Text(release.name, style: TextStyle(fontSize: 15)),
            stretchModes: [StretchMode.zoomBackground, StretchMode.fadeTitle],
            background: Stack(fit: StackFit.expand, children: [
              spiffCover(context, spiff.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0.0, 0.75),
                    end: Alignment(0.0, 0.0),
                    colors: <Color>[
                      Color(0x60000000),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
              Align(
                  alignment: Alignment.bottomLeft,
                  child: playButton(context, spiff, isCached)),
              Align(
                  alignment: Alignment.bottomRight,
                  child: bottomRight(context, spiff, isCached))
            ])),
      ),
      SliverToBoxAdapter(
          child: Container(
              padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
              child: Column(children: [
                title(context, spiff),
                subtitle(context, spiff),
              ]))),
      SliverToBoxAdapter(child: SpiffTrackListView(spiff)),
    ]);
  }

  // List<Widget>? actions(BuildContext context);
  //
  // Widget bottomRight(BuildContext context, bool isCached);
  //
  // Widget subtitle(BuildContext context);

  Widget title(BuildContext context, Spiff spiff) {
    return Text(spiff.playlist.title,
        style: Theme.of(context).textTheme.headlineSmall);
  }

  Widget playButton(BuildContext context, Spiff spiff, bool isCached) {
    return isCached
        ? PlayButton(onPressed: () => onPlay(context, spiff))
        : StreamingButton(onPressed: () => onPlay(context, spiff));
  }

  void onPlay(BuildContext context, Spiff spiff) {
    // final offsets = context.read<OffsetCacheCubit>();
    if (spiff.isVideo()) {
      final entry = spiff.playlist.tracks.first;
      // final pos = offsets.state.position(entry);
      context.showMovie(entry);
    } else {
      context.play(spiff);
    }
  }
}

class SpiffTrackListView extends StatelessWidget {
  final Spiff _spiff;

  const SpiffTrackListView(this._spiff);

  void _onTrack(BuildContext context, OffsetCacheState offsets, int index) {
    if (_spiff.isMusic() || _spiff.isPodcast()) {
      context.play(_spiff.copyWith(index: index));
    } else if (_spiff.isVideo()) {
      final video = _spiff.playlist.tracks[index];
      // final pos = offsets.position(video) ?? Duration.zero;
      context.showMovie(video);
    }
  }

  void _onArtist(BuildContext context, String? artist) {
    context.showArtist(artist ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadCubit>();
    final trackCache = context.watch<TrackCacheCubit>();
    final offsets = context.watch<OffsetCacheCubit>();
    final children = <Widget>[];
    final tracks = _spiff.playlist.tracks;
    final sameArtwork = tracks.every((e) => e.image == tracks.first.image);
    for (var i = 0; i < tracks.length; i++) {
      final e = tracks[i];
      final subChildren = _subtitle(trackCache.state, offsets.state, e);
      final subtitle = Column(
          children: subChildren, crossAxisAlignment: CrossAxisAlignment.start);
      final isThreeLine = subChildren.length > 1 || _spiff.isPodcast();
      children.add(ListTile(
          isThreeLine: isThreeLine,
          onTap: () => _onTrack(context, offsets.state, i),
          onLongPress: () => _onArtist(context, _spiff.creator),
          leading: _leading(context, e, sameArtwork),
          trailing: _trailing(downloads.state, trackCache.state, e),
          subtitle: subtitle,
          title: Text(e.title)));
    }
    return Column(children: children);
  }

  Widget? _leading(BuildContext context, Entry entry, bool sameArtwork) {
    // final pos = snapshot.position(entry);
    // final end = snapshot.duration(entry);
    // if (pos != null && end != null) {
    //   final value = pos.inSeconds.toDouble() / end.inSeconds.toDouble();
    //   return CircularProgressIndicator(value: value);
    // } else {
    return sameArtwork ? null : tileCover(context, entry.image);
  }

  Widget _trailing(DownloadState downloads, TrackCacheState cache, Entry entry) {
    final download = downloads.get(entry);
    if (download?.downloading == true) {
      final value = download?.progress?.value ?? 0.0;
      return value > 1.0
          ? CircularProgressIndicator()
          : CircularProgressIndicator(value: value);
    }
    return Icon(cache.contains(entry) ? IconsCached : null);
  }

  List<Widget> _subtitle(
      TrackCacheState state, OffsetCacheState offsets, Entry entry) {
    final children = <Widget>[];
    if (_spiff.isMusic()) {
      if (entry.creator != _spiff.playlist.creator) {
        children.add(Text(entry.creator, overflow: TextOverflow.ellipsis));
      }
      children.add(Text(
          merge([
            entry.album,
            if (state.contains(entry)) storage(entry.size)
          ]),
          overflow: TextOverflow.ellipsis));
    } else {
      final duration = offsets.remaining(entry);
      if (duration != null) {
        if (_spiff.isPodcast() || _spiff.isVideo()) {
          final value = offsets.value(entry);
          if (value != null) {
            children.add(LinearProgressIndicator(value: value));
          }
        }
      }
      children.add(
        RelativeDateWidget.from(spiffDate(_spiff, entry: entry),
            prefix: entry.creator,
            suffix: state.contains(entry) ? storage(entry.size) : ''),
      );
    }
    return children;
  }
}
