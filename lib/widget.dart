// Copyright (C) 2022 The Takeout Authors.
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

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'menu.dart';
import 'cover.dart';
import 'util.dart';
import 'style.dart';
import 'main.dart';
import 'downloads.dart';
import 'cache.dart';
import 'playlist.dart';
import 'video.dart';
import 'global.dart';
import 'spiff.dart';
import 'util.dart';

Random _random = Random();

class SpiffWidget extends StatefulWidget {
  final Spiff? spiff;
  final Future<Spiff> Function()? fetch;

  SpiffWidget({this.spiff, this.fetch});

  @override
  SpiffState createState() => SpiffState(spiff: spiff, fetch: fetch);
}

class SpiffState extends State<SpiffWidget> with SpiffWidgetBuilder {
  Spiff? spiff;
  Future<Spiff> Function()? fetch;
  String? coverUrl;

  SpiffState({this.spiff, this.fetch});

  @override
  void initState() {
    super.initState();
    if (spiff != null) {
      coverUrl = pickCover(spiff!);
    }
    if (fetch != null) {
      onRefresh();
    }
  }

  Future<void> onRefresh() async {
    Future<Spiff> Function()? fetcher = fetch;
    if (fetcher != null) {
      try {
        final result = await fetcher();
        print('got $result');
        if (mounted) {
          setState(() {
            spiff = result;
            coverUrl = pickCover(spiff!);
          });
        }
      } catch (error) {
        print('refresh err $error');
      }
    }
  }

  List<Widget>? actions(BuildContext context) {
    return [
      popupMenu(context, [
        if (fetch != null) PopupItem.refresh(context, (_) => onRefresh()),
      ]),
    ];
  }

  Widget bottomRight(BuildContext context, bool isCached) {
    return isCached
        ? IconButton(icon: Icon(IconsDownloadDone), onPressed: () => {})
        : downloadButton(isCached);
  }

  Widget subtitle(BuildContext context) {
    final text = '${spiff!.playlist.creator}';
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .subtitle1!
            .copyWith(color: Colors.white60));
  }

  Widget downloadButton(bool isCached) {
    if (isCached) {
      return IconButton(icon: Icon(IconsDownload), onPressed: () => {});
    }
    return allowDownloadIconButton(
        Icon(IconsDownload), () => Downloads.downloadSpiff(spiff!));
  }
}

mixin SpiffWidgetBuilder {
  Spiff? get spiff;

  String? get coverUrl;

  Future<Spiff> Function()? get fetch;

  Future<void> onRefresh();

  Widget build(BuildContext context) {
    return FutureBuilder<Color?>(
        future: getImageBackgroundColor(coverUrl ?? ''),
        builder: (context, snapshot) => Scaffold(
            backgroundColor: snapshot.data,
            // appBar: AppBar(
            //     title: header(spiff.playlist.title),
            //     backgroundColor: snapshot?.data),
            body: spiff == null
                ? Center(child: CircularProgressIndicator())
                : fetch != null
                    ? RefreshIndicator(
                        onRefresh: () => onRefresh(), child: body())
                    : body()));
  }

  Widget body() {
    return StreamBuilder<Set<String>>(
        stream: TrackCache.keysSubject,
        builder: (context, snapshot) {
          // cover images are 250x250 (or 500x500)
          // distort a bit to only take half the screen
          final screen = MediaQuery.of(context).size;
          final expandedHeight = screen.height / 2;
          final keys = snapshot.data ?? Set<String>();
          final isCached = TrackCache.checkAll(keys, spiff!.playlist.tracks);
          bool isRadio = spiff!.playlist.creator == 'Radio';
          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: expandedHeight,
              actions: actions(context),
              flexibleSpace: FlexibleSpaceBar(
                  // centerTitle: true,
                  // title: Text(release.name, style: TextStyle(fontSize: 15)),
                  stretchModes: [
                    StretchMode.zoomBackground,
                    StretchMode.fadeTitle
                  ],
                  background: Stack(fit: StackFit.expand, children: [
                    spiffCover(coverUrl!),
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
                        child: playButton(context, isCached)),
                    Align(
                        alignment: Alignment.bottomRight,
                        child: bottomRight(context, isCached))
                  ])),
            ),
            SliverToBoxAdapter(
                child: Container(
                    padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
                    child: Column(children: [
                      title(context),
                      subtitle(context),
                    ]))),
            SliverToBoxAdapter(child: SpiffTrackListView(spiff!)),
          ]);
        });
  }

  List<Widget>? actions(BuildContext context);

  Widget bottomRight(BuildContext context, bool isCached);

  Widget subtitle(BuildContext context);

  Widget title(BuildContext context) {
    return Text(spiff!.playlist.title,
        style: Theme.of(context).textTheme.headline5);
  }

  Widget playButton(BuildContext context, bool isCached) {
    if (isCached) {
      return IconButton(
          icon: Icon(Icons.play_arrow, size: 32),
          onPressed: () => onPlay(context));
    }
    return allowStreamingIconButton(
        Icon(Icons.play_arrow, size: 32), () => onPlay(context));
  }

  // void _onArtist(BuildContext context) {
  //   showArtist(spiff!.playlist.creator!);
  // }

  void onPlay(BuildContext context) {
    print('_onPlay $spiff');
    if (spiff!.isVideo()) {
      var entry = spiff!.playlist.tracks.first;
      showMovie(context, entry);
    } else {
      MediaQueue.playSpiff(spiff!);
      showPlayer();
    }
  }
}


class SpiffTrackListView extends StatelessWidget {
  final Spiff _spiff;

  SpiffTrackListView(this._spiff);

  void _onTrack(BuildContext context, int index) {
    if (_spiff.isMusic() || _spiff.isPodcast()) {
      MediaQueue.playSpiff(_spiff, index: index);
      showPlayer();
    } else if (_spiff.isVideo()) {
      showMovie(context, _spiff.playlist.tracks[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
        stream: TrackCache.keysSubject,
        builder: (context, snapshot) {
          final keys = snapshot.data ?? Set<String>();
          final children = <Widget>[];
          final tracks = _spiff.playlist.tracks;
          final sameArtwork =
          tracks.every((e) => e.image == tracks.first.image);
          for (var i = 0; i < tracks.length; i++) {
            final e = tracks[i];
            children.add(ListTile(
                onTap: () => _onTrack(context, i),
                onLongPress: () => showArtist(e.creator),
                leading: sameArtwork ? null : tileCover(e.image),
                trailing: Icon(keys.contains(e.key) ? IconsCached : null),
                subtitle: Text('${e.creator} \u2022 ${relativeDate(e.date)} \u2022 ${storage(e.size)}'),
                title: Text(e.title)));
          }
          return Column(children: children);
        });
  }
}

String pickCover(Spiff spiff) {
  if (isNotNullOrEmpty(spiff.playlist.image)) {
    return spiff.playlist.image!;
  }
  for (var i = 0; i < spiff.playlist.tracks.length; i++) {
    final pick = _random.nextInt(spiff.playlist.tracks.length);
    if (isNotNullOrEmpty(spiff.playlist.tracks[pick].image)) {
      return spiff.playlist.tracks[pick].image;
    }
  }
  return ''; // TODO what to return?
}
