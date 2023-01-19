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

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:audio_service/audio_service.dart';
import 'package:timeago_flutter/timeago_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

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
import 'progress.dart';
import 'schema.dart';

class SpiffWidget extends StatefulWidget {
  final Spiff? spiff;
  final Future<Spiff> Function()? fetch;

  SpiffWidget({this.spiff, this.fetch});

  @override
  SpiffState createState() => SpiffState(spiff: spiff);
}

class SpiffState extends State<SpiffWidget> with SpiffWidgetBuilder {
  static final log = Logger('SpiffState');

  final Future<Spiff> Function()? fetch;
  Spiff? spiff;
  String? coverUrl;

  SpiffState({this.spiff, this.fetch});

  @override
  void initState() {
    super.initState();
    if (spiff != null) {
      coverUrl = spiff!.cover;
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
        if (mounted) {
          setState(() {
            spiff = result;
            coverUrl = spiff!.cover;
          });
        }
      } catch (error) {
        log.warning(error);
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
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(IconsDownloadDone),
            onPressed: () => {})
        : downloadButton(context, isCached);
  }

  Widget subtitle(BuildContext context) {
    final text = spiff!.playlist.creator;
    return text == null
        ? SizedBox.shrink()
        : Text(text, style: Theme.of(context).textTheme.subtitle1!);
  }

  Widget downloadButton(BuildContext context, bool isCached) {
    return isCached
        ? IconButton(
            color: Theme.of(context).primaryColorLight,
            icon: Icon(IconsDownload),
            onPressed: () => {})
        : allowDownloadIconButton(context, Icon(IconsDownload),
            () => Downloads.downloadSpiff(context, spiff!));
  }
}

mixin SpiffWidgetBuilder {
  Spiff? get spiff;

  String? get coverUrl;

  Future<Spiff> Function()? get fetch;

  Future<void> onRefresh();

  Widget build(BuildContext context) {
    return FutureBuilder<Color?>(
        future: getImageBackgroundColor(context, coverUrl ?? ''),
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
    return StreamBuilder<CacheSnapshot>(
        stream: MediaCache.stream(),
        builder: (context, snapshot) {
          // cover images are 250x250 (or 500x500)
          // distort a bit to only take half the screen
          final screen = MediaQuery.of(context).size;
          final expandedHeight = screen.height / 2;
          final cacheSnapshot = snapshot.data ?? CacheSnapshot.empty();
          final isCached = cacheSnapshot.containsAll(spiff!.playlist.tracks);
          return CustomScrollView(slivers: [
            SliverAppBar(
              foregroundColor: overlayIconColor(context),
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
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(Icons.play_arrow, size: 32),
            onPressed: () => onPlay(context))
        : allowStreamingIconButton(
            context, Icon(Icons.play_arrow, size: 32), () => onPlay(context));
  }

  // void _onArtist(BuildContext context) {
  //   showArtist(spiff!.playlist.creator!);
  // }

  void onPlay(BuildContext context) async {
    if (spiff!.isVideo()) {
      final entry = spiff!.playlist.tracks.first;
      final pos = await Progress.position(entry.key);
      showMovie(context, entry, startOffset: pos);
    } else {
      MediaQueue.playSpiff(spiff!);
      showPlayer();
    }
  }
}

class SpiffTrackListView extends StatelessWidget {
  final Spiff _spiff;

  const SpiffTrackListView(this._spiff);

  void _onTrack(BuildContext context, CacheSnapshot snapshot, int index) {
    if (_spiff.isMusic() || _spiff.isPodcast()) {
      MediaQueue.playSpiff(_spiff, index: index);
      showPlayer();
    } else if (_spiff.isVideo()) {
      final video = _spiff.playlist.tracks[index];
      final pos = snapshot.position(video) ?? Duration.zero;
      showMovie(context, video, startOffset: pos);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CacheSnapshot>(
        stream: MediaCache.stream(),
        builder: (context, snapshot) {
          final cacheSnapshot = snapshot.data ?? CacheSnapshot.empty();
          final children = <Widget>[];
          final tracks = _spiff.playlist.tracks;
          final sameArtwork =
              tracks.every((e) => e.image == tracks.first.image);
          for (var i = 0; i < tracks.length; i++) {
            final e = tracks[i];
            final subChildren = _subtitle(context, cacheSnapshot, e);
            final subtitle = Column(
                children: subChildren,
                crossAxisAlignment: CrossAxisAlignment.start);
            final isThreeLine = subChildren.length > 1 || _spiff.isPodcast();
            children.add(ListTile(
                isThreeLine: isThreeLine,
                onTap: () => _onTrack(context, cacheSnapshot, i),
                onLongPress: () => showArtist(e.creator),
                leading: _leading(context, cacheSnapshot, e, sameArtwork),
                trailing: _trailing(cacheSnapshot, e),
                subtitle: subtitle,
                title: Text(e.title)));
          }
          return Column(children: children);
        });
  }

  Widget? _leading(BuildContext context, CacheSnapshot snapshot, Entry entry,
      bool sameArtwork) {
    // final pos = snapshot.position(entry);
    // final end = snapshot.duration(entry);
    // if (pos != null && end != null) {
    //   final value = pos.inSeconds.toDouble() / end.inSeconds.toDouble();
    //   return CircularProgressIndicator(value: value);
    // } else {
    return sameArtwork ? null : tileCover(entry.image);
  }

  Widget _trailing(CacheSnapshot snapshot, Entry entry) {
    final downloading = snapshot.downloadSnapshot(entry);
    if (downloading != null) {
      final value = downloading.value;
      return value > 1.0
          ? CircularProgressIndicator()
          : CircularProgressIndicator(value: value);
    }
    return Icon(snapshot.contains(entry) ? IconsCached : null);
  }

  List<Widget> _subtitle(
      BuildContext context, CacheSnapshot snapshot, Entry entry) {
    final children = <Widget>[];
    if (_spiff.isMusic()) {
      if (entry.creator != _spiff.playlist.creator) {
        children.add(Text(entry.creator, overflow: TextOverflow.ellipsis));
      }
      children.add(Text(
          merge(
              [entry.album, if (snapshot.contains(entry)) storage(entry.size)]),
          overflow: TextOverflow.ellipsis));
    } else {
      final duration = snapshot.remaining(entry);
      if (duration != null) {
        if (_spiff.isPodcast() || _spiff.isVideo()) {
          final value = snapshot.value(entry);
          if (value != null) {
            children.add(LinearProgressIndicator(value: value));
          }
        }
      }
      children.add(
        RelativeDateWidget.from(spiffDate(_spiff, entry: entry),
            prefix: entry.creator,
            suffix: snapshot.contains(entry) ? storage(entry.size) : ''),
      );
    }
    return children;
  }
}

class TrackListTile extends StatelessWidget {
  final String artist;
  final String album;
  final String title;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;

  const TrackListTile(this.artist, this.album, this.title,
      {this.leading,
      this.onTap,
      this.onLongPress,
      this.trailing,
      this.selected = false});

  @override
  Widget build(BuildContext context) {
    final subtitle =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      if (artist.isNotEmpty) Text(artist, overflow: TextOverflow.ellipsis),
      Text(album, overflow: TextOverflow.ellipsis)
    ]);

    return ListTile(
        selected: selected,
        isThreeLine: artist.isNotEmpty,
        onTap: onTap,
        onLongPress: onLongPress,
        leading: leading,
        trailing: trailing,
        subtitle: subtitle,
        title: Text(title));
  }
}

class NumberedTrackListTile extends StatelessWidget {
  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool selected;

  const NumberedTrackListTile(this.track,
      {this.onTap, this.onLongPress, this.trailing, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final trackNumStyle = Theme.of(context).textTheme.caption;
    final leading = Container(
        padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
        child: Text('${track.trackNum}', style: trackNumStyle));
    // only show artist if different from album artist
    final artist = track.trackArtist != track.artist ? track.trackArtist : '';
    return TrackListTile(artist, track.releaseTitle, track.title,
        leading: leading,
        trailing: trailing,
        onTap: onTap,
        onLongPress: onLongPress,
        selected: selected);
  }
}

class CoverTrackListTile extends TrackListTile {
  CoverTrackListTile(super.artist, super.album, super.title, String? cover,
      {super.onTap, super.onLongPress, super.trailing, super.selected})
      : super(leading: cover != null ? tileCover(cover) : null);

  factory CoverTrackListTile.mediaTrack(MediaLocatable track,
      {bool showCover = true,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
      Widget? trailing,
      bool selected = false}) {
    return CoverTrackListTile(
      track.creator,
      track.album,
      track.title,
      showCover ? track.image : null,
      onTap: onTap,
      onLongPress: onLongPress,
      trailing: trailing,
      selected: selected,
    );
  }

  factory CoverTrackListTile.mediaItem(MediaItem item,
      {bool showCover = true,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
      Widget? trailing,
      bool selected = false}) {
    return CoverTrackListTile(
      item.artist ?? '',
      item.album ?? '',
      item.title,
      showCover ? item.artUri.toString() : null,
      onTap: onTap,
      onLongPress: onLongPress,
      trailing: trailing,
      selected: selected,
    );
  }
}

class RelativeDateWidget extends StatelessWidget {
  final DateTime dateTime;
  final String prefix;
  final String suffix;
  final String separator;

  const RelativeDateWidget(this.dateTime,
      {String this.prefix = '',
      String this.suffix = '',
      String this.separator = textSeparator});

  factory RelativeDateWidget.from(String date,
      {String prefix = '',
      String suffix = '',
      String separator = textSeparator}) {
    final t = DateTime.parse(date);
    return RelativeDateWidget(t,
        prefix: prefix, suffix: suffix, separator: separator);
  }

  @override
  Widget build(BuildContext context) {
    if (dateTime.year == 1 && dateTime.month == 1 && dateTime.day == 1) {
      // don't bother zero dates from the server
      return Text('');
    }
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays == 0) {
      // less than 1 day, refresh faster if less than 1 hour
      final refreshRate =
          diff.inHours > 0 ? Duration(hours: 1) : Duration(minutes: 1);
      return Timeago(
          refreshRate: refreshRate,
          date: dateTime,
          builder: (_, v) {
            return Text(merge([prefix, v, suffix], separator: separator),
                overflow: TextOverflow.ellipsis);
          });
    } else {
      // more than 1 day so don't bother refreshing
      return Text(merge([prefix, timeago.format(dateTime), suffix]));
    }
  }
}
