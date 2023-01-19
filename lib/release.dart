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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:takeout_app/global.dart';
import 'package:takeout_app/menu.dart';
import 'package:url_launcher/url_launcher.dart';

import 'artists.dart';
import 'cache.dart';
import 'client.dart';
import 'cover.dart';
import 'downloads.dart';
import 'schema.dart';
import 'playlist.dart';
import 'style.dart';
import 'main.dart';
import 'model.dart';
import 'util.dart';
import 'widget.dart';

class ReleaseWidget extends StatefulWidget {
  final Release _release;

  ReleaseWidget(this._release);

  @override
  State<StatefulWidget> createState() => _ReleaseState();
}

class _ReleaseState extends State<ReleaseWidget> {
  ReleaseView? _view;

  @override
  void initState() {
    super.initState();
    final client = Client();
    client.release(widget._release.id).then((v) => _onReleaseUpdated(v));
  }

  void _onReleaseUpdated(ReleaseView view) {
    if (mounted) {
      setState(() {
        _view = view;
      });
    }
  }

  void _onArtist() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ArtistWidget(_view!.artist)));
  }

  void _onPlay() {
    MediaQueue.play(release: widget._release);
    showPlayer();
  }

  void _onDownload(BuildContext context) {
    Downloads.downloadRelease(context, widget._release);
  }

  Future<void> _onRefresh() async {
    final client = Client();
    await client
        .release(widget._release.id, ttl: Duration.zero)
        .then((v) => _onReleaseUpdated(v));
  }

  @override
  Widget build(BuildContext context) {
    final releaseUrl = 'https://musicbrainz.org/release/${widget._release.reid}';
    final releaseGroupUrl =
        'https://musicbrainz.org/release-group/${widget._release.rgid}';
    return FutureBuilder<Color?>(
        future: getImageBackgroundColor(context, widget._release.image),
        builder: (context, snapshot) {
          final backgroundColor = snapshot.data;
          return Scaffold(
              backgroundColor: backgroundColor,
              body: RefreshIndicator(
                  onRefresh: () => _onRefresh(),
                  child: StreamBuilder<CacheSnapshot>(
                      stream: MediaCache.stream(),
                      builder: (context, snapshot) {
                        // cover images are 250x250 (or 500x500)
                        // distort a bit to only take half the screen
                        final screen = MediaQuery.of(context).size;
                        final expandedHeight = screen.height / 2;
                        final cacheSnapshot =
                            snapshot.data ?? CacheSnapshot.empty();
                        final isCached = _view != null
                            ? cacheSnapshot.containsAll(_view!.tracks)
                            : false;
                        return CustomScrollView(slivers: [
                          SliverAppBar(
                            // floating: true,
                            // snap: false,
                            // backgroundColor: backgroundColor,
                            foregroundColor: overlayIconColor(context),
                            expandedHeight: expandedHeight,
                            actions: [
                              popupMenu(context, [
                                PopupItem.play(context, (_) => _onPlay()),
                                PopupItem.download(
                                    context, (_) => _onDownload(context)),
                                PopupItem.divider(),
                                PopupItem.link(context, 'MusicBrainz Release',
                                    (_) => launchUrl(Uri.parse(releaseUrl))),
                                PopupItem.link(
                                    context,
                                    'MusicBrainz Release Group',
                                    (_) =>
                                        launchUrl(Uri.parse(releaseGroupUrl))),
                                PopupItem.divider(),
                                PopupItem.refresh(context, (_) => _onRefresh()),
                              ]),
                            ],
                            flexibleSpace: FlexibleSpaceBar(
                                // centerTitle: true,
                                // title: Text(release.name, style: TextStyle(fontSize: 15)),
                                stretchModes: [
                                  StretchMode.zoomBackground,
                                  StretchMode.fadeTitle
                                ],
                                background:
                                    Stack(fit: StackFit.expand, children: [
                                  releaseSmallCover(widget._release.image),
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
                                      child: _playButton(context, isCached)),
                                  Align(
                                      alignment: Alignment.bottomRight,
                                      child:
                                          _downloadButton(context, isCached)),
                                ])),
                          ),
                          SliverToBoxAdapter(
                              child: Container(
                                  padding: EdgeInsets.fromLTRB(0, 16, 0, 4),
                                  child: Column(children: [
                                    GestureDetector(
                                        onTap: () => _onArtist(),
                                        child: _title()),
                                    GestureDetector(
                                        onTap: () => _onArtist(),
                                        child: _artist()),
                                  ]))),
                          if (_view != null)
                            SliverToBoxAdapter(
                                child: _ReleaseTracksWidget(_view!)),
                          if (_view != null && _view!.similar.isNotEmpty)
                            SliverToBoxAdapter(
                              child: heading(AppLocalizations.of(context)!
                                  .similarReleasesLabel),
                            ),
                          if (_view != null && _view!.similar.isNotEmpty)
                            AlbumGridWidget(_view!.similar),
                        ]);
                      })));
        });
  }

  Widget _title() {
    return Text(widget._release.name, style: Theme.of(context).textTheme.headline5);
  }

  Widget _artist() {
    var artist = widget._release.artist;
    if (isNotNullOrEmpty(widget._release.date)) {
      artist = merge([artist, year(widget._release.date ?? '')]);
    }
    return Text(artist, style: Theme.of(context).textTheme.subtitle1!);
  }

  Widget _playButton(BuildContext context, bool isCached) {
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(Icons.play_arrow, size: 32),
            onPressed: () => _onPlay())
        : allowStreamingIconButton(
            context, Icon(Icons.play_arrow, size: 32), _onPlay);
  }

  Widget _downloadButton(BuildContext context, bool isCached) {
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(IconsDownloadDone),
            onPressed: () => {})
        : allowDownloadIconButton(
            context, Icon(IconsDownload), () => _onDownload(context));
  }
}

class _ReleaseTracksWidget extends StatelessWidget {
  final ReleaseView _view;

  const _ReleaseTracksWidget(this._view);

  void _onTap(int index) {
    MediaQueue.play(index: index, release: _view.release);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CacheSnapshot>(
        stream: MediaCache.stream(),
        builder: (context, snapshot) {
          final cacheSnapshot = snapshot.data ?? CacheSnapshot.empty();
          int discs = _view.discs;
          int d = 0;
          List<Widget> children = [];
          for (var i = 0; i < _view.tracks.length; i++) {
            final e = _view.tracks[i];
            if (discs > 1 && e.discNum != d) {
              if (e.discNum > 1) {
                children.add(Divider());
              }
              children.add(smallHeading(context,
                  AppLocalizations.of(context)!.discLabel(e.discNum, discs)));
              d = e.discNum;
            }
            children.add(NumberedTrackListTile(e,
                onTap: () => _onTap(i),
                trailing: _trailing(context, cacheSnapshot, e)));
          }
          return Column(children: children);
        });
  }

  Widget _trailing(BuildContext context, CacheSnapshot snapshot, Track t) {
    final downloading = snapshot.downloadSnapshot(t);
    return (downloading != null)
        ? CircularProgressIndicator(value: downloading.value)
        : Icon(snapshot.contains(t) ? IconsCached : null);
  }
}

class AlbumGridWidget extends StatelessWidget {
  final List<MediaAlbum> _albums;
  final bool subtitle;

  const AlbumGridWidget(this._albums, {this.subtitle = true});

  @override
  Widget build(BuildContext context) {
    return SliverGrid.extent(
        maxCrossAxisExtent: 250,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
        children: [
          ..._albums.map((a) => Container(
              child: GestureDetector(
                  onTap: () => _onTap(context, a),
                  child: GridTile(
                    footer: Material(
                        color: Colors.transparent,
                        // shape: RoundedRectangleBorder(
                        //     borderRadius: BorderRadius.vertical(
                        //         bottom: Radius.circular(4))),
                        clipBehavior: Clip.antiAlias,
                        child: GridTileBar(
                          backgroundColor: Colors.black26,
                          title: Text(a.album),
                          subtitle: subtitle ? Text(a.creator) : null,
                        )),
                    child: gridCover(a.image),
                  ))))
        ]);
  }

  void _onTap(BuildContext context, MediaAlbum album) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      if (album is Release) {
        return ReleaseWidget(album);
        // } else if (album is SpiffDownloadEntry) {
        //   TODO is this used?
        // return DownloadWidget(spiff: album.spiff);
      }
      return Text('');
    }));
  }
}

//
// class ReleaseGridWidget extends StatelessWidget {
//   final List<Release> _releases;
//   final bool subtitle;
//
//   ReleaseGridWidget(this._releases, {this.subtitle = true});
//
//   @override
//   Widget build(BuildContext context) {
//     return SliverGrid.count(
//         crossAxisCount: 3,
//         crossAxisSpacing: 5,
//         mainAxisSpacing: 5,
//         children: [
//           ..._releases.map((r) => Container(
//               child: GestureDetector(
//                   onTap: () => _onTap(context, r),
//                   child: GridTile(
//                     footer: Material(
//                         color: Colors.transparent,
//                         // shape: RoundedRectangleBorder(
//                         //     borderRadius: BorderRadius.vertical(
//                         //         bottom: Radius.circular(4))),
//                         clipBehavior: Clip.antiAlias,
//                         child: GridTileBar(
//                           backgroundColor: Colors.black26,
//                           title: Text(r.name),
//                           subtitle: subtitle ? Text(r.artist) : null,
//                         )),
//                     child: releaseCover(r),
//                   ))))
//         ]);
//   }
//
//   void _onTap(BuildContext context, Release release) {
//     Navigator.push(context,
//         MaterialPageRoute(builder: (context) => ReleaseWidget(release)));
//   }
// }

class ReleaseListWidget extends StatelessWidget {
  final List<Release> _releases;

  const ReleaseListWidget(this._releases);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._releases.map((e) => Container(
          child: ListTile(
              leading: tileCover(e.image),
              onTap: () => _onTap(context, e),
              // trailing: IconButton(
              //     icon: Icon(Icons.playlist_add),
              //     onPressed: () => _onAppend(e)),
              trailing: IconButton(
                  icon: Icon(Icons.play_arrow), onPressed: () => _onPlay(e)),
              title: Text(e.nameWithDisambiguation),
              subtitle: Text(year(e.date ?? '')))))
    ]);
  }

  void _onTap(BuildContext context, Release release) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ReleaseWidget(release)));
  }

  void _onPlay(Release release) {
    MediaQueue.play(release: release);
  }
}
