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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:takeout_app/app/context.dart';
import 'package:takeout_app/api/model.dart';
import 'package:takeout_app/art/builder.dart';
import 'package:takeout_app/art/cover.dart';
import 'package:takeout_app/client/download.dart';
import 'package:takeout_app/cache/track.dart';
import 'package:takeout_app/page/page.dart';
import 'package:takeout_app/menu.dart';

import 'artists.dart';
import 'style.dart';
import 'model.dart';
import 'util.dart';
import 'buttons.dart';
import 'tiles.dart';

class ReleaseWidget extends ClientPage<ReleaseView> {
  final Release _release;

  ReleaseWidget(this._release);

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.release(_release.id, ttl: ttl);
  }

  void _onArtist(BuildContext context, ReleaseView view) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => ArtistWidget(view.artist)));
  }

  void _onPlay(BuildContext context) {
    context.playlist.replace(_release.reference);
  }

  void _onDownload(BuildContext context) {
    // Downloads.downloadRelease(context, _release);
  }

  @override
  Widget page(BuildContext context, ReleaseView view) {
    final releaseUrl = 'https://musicbrainz.org/release/${_release.reid}';
    final releaseGroupUrl =
        'https://musicbrainz.org/release-group/${_release.rgid}';
    // cover images are 250x250 (or 500x500)
    // distort a bit to only take half the screen
    final screen = MediaQuery.of(context).size;
    final expandedHeight = screen.height / 2;
    return FutureBuilder<Color?>(
        future: getImageBackgroundColor(context, _release.image),
        builder: (context, snapshot) {
          final backgroundColor = snapshot.data;
          return Scaffold(
              backgroundColor: backgroundColor,
              body: RefreshIndicator(
                  onRefresh: () => refreshPage(context),
                  child: BlocBuilder<TrackCacheCubit, TrackCacheState>(
                      builder: (context, state) {
                    final isCached = state.containsAll(view.tracks);
                    return CustomScrollView(slivers: [
                      SliverAppBar(
                        // floating: true,
                        // snap: false,
                        // backgroundColor: backgroundColor,
                        foregroundColor: overlayIconColor(context),
                        expandedHeight: expandedHeight,
                        actions: [
                          popupMenu(context, [
                            PopupItem.play(context, (_) => _onPlay(context)),
                            PopupItem.download(
                                context, (_) => _onDownload(context)),
                            PopupItem.divider(),
                            PopupItem.link(context, 'MusicBrainz Release',
                                (_) => launchUrl(Uri.parse(releaseUrl))),
                            PopupItem.link(context, 'MusicBrainz Release Group',
                                (_) => launchUrl(Uri.parse(releaseGroupUrl))),
                            PopupItem.divider(),
                            PopupItem.refresh(
                                context, (_) => refreshPage(context)),
                          ]),
                        ],
                        flexibleSpace: FlexibleSpaceBar(
                            // centerTitle: true,
                            // title: Text(release.name, style: TextStyle(fontSize: 15)),
                            stretchModes: [
                              StretchMode.zoomBackground,
                              StretchMode.fadeTitle
                            ],
                            background: Stack(fit: StackFit.expand, children: [
                              releaseSmallCover(context, _release.image),
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
                                  child: _downloadButton(context, isCached)),
                            ])),
                      ),
                      SliverToBoxAdapter(
                          child: Container(
                              padding: EdgeInsets.fromLTRB(0, 16, 0, 4),
                              child: Column(children: [
                                GestureDetector(
                                    onTap: () => _onArtist(context, view),
                                    child: _title(context)),
                                GestureDetector(
                                    onTap: () => _onArtist(context, view),
                                    child: _artist(context)),
                              ]))),
                      SliverToBoxAdapter(child: _ReleaseTracksWidget(view)),
                      if (view.similar.isNotEmpty)
                        SliverToBoxAdapter(
                          child: heading(AppLocalizations.of(context)!
                              .similarReleasesLabel),
                        ),
                      if (view.similar.isNotEmpty)
                        AlbumGridWidget(view.similar),
                    ]);
                  })));
        });
  }

  Widget _title(BuildContext context) {
    return Text(_release.name,
        style: Theme.of(context).textTheme.headlineSmall);
  }

  Widget _artist(BuildContext context) {
    var artist = _release.artist;
    if (isNotNullOrEmpty(_release.date)) {
      artist = merge([artist, year(_release.date ?? '')]);
    }
    return Text(artist, style: Theme.of(context).textTheme.titleMedium!);
  }

  Widget _playButton(BuildContext context, bool isCached) {
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(Icons.play_arrow, size: 32),
            onPressed: () => _onPlay(context))
        : StreamingButton(onPressed: () => _onPlay(context));
  }

  Widget _downloadButton(BuildContext context, bool isCached) {
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(IconsDownloadDone),
            onPressed: () => {})
        : DownloadButton(onPressed: () => _onDownload(context));
  }
}

class _ReleaseTracksWidget extends StatelessWidget {
  final ReleaseView _view;

  const _ReleaseTracksWidget(this._view);

  void _onTap(BuildContext context, int index) {
    // MediaQueue.play(context, index: index, release: _view.release);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadCubit, DownloadState>(builder: (context, state) {
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
            onTap: () => _onTap(context, i),
            trailing: _trailing(context, state, e)));
      }
      return Column(children: children);
    });
  }

  Widget _trailing(BuildContext context, DownloadState state, Track t) {
    final progress = state.progress(t);
    return (progress != null)
        ? CircularProgressIndicator(value: progress.value)
        : Icon(context.trackCache.state.contains(t) ? IconsCached : null);
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
                    child: gridCover(context, a.image),
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
              leading: tileCover(context, e.image),
              onTap: () => _onTap(context, e),
              // trailing: IconButton(
              //     icon: Icon(Icons.playlist_add),
              //     onPressed: () => _onAppend(e)),
              trailing: IconButton(
                  icon: Icon(Icons.play_arrow),
                  onPressed: () => _onPlay(context, e)),
              title: Text(e.nameWithDisambiguation),
              subtitle: Text(year(e.date ?? '')))))
    ]);
  }

  void _onTap(BuildContext context, Release release) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => ReleaseWidget(release)));
  }

  void _onPlay(BuildContext context, Release release) {
    // MediaQueue.play(context, release: release);
  }
}
