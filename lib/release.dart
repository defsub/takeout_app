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
import 'package:flutter/rendering.dart';
import 'package:connectivity/connectivity.dart';
import 'package:takeout_app/menu.dart';
import 'package:url_launcher/url_launcher.dart';

import 'artists.dart';
import 'cache.dart';
import 'client.dart';
import 'cover.dart';
import 'downloads.dart';
import 'music.dart';
import 'playlist.dart';
import 'style.dart';
import 'main.dart';
import 'model.dart';
import 'util.dart';

class ReleaseWidget extends StatefulWidget {
  final Release _release;

  ReleaseWidget(this._release);

  @override
  State<StatefulWidget> createState() => _ReleaseState(_release);
}

String _name(Release release) {
  if (isNotNullOrEmpty(release.disambiguation)) {
    return '${release.name} (${release.disambiguation})';
  }
  return release.name;
}

class _ReleaseState extends State<ReleaseWidget> {
  final Release release;
  ReleaseView _view;

  _ReleaseState(this.release);

  @override
  void initState() {
    super.initState();
    final client = Client();
    client.release(release.id).then((v) => _onReleaseUpdated(v));
  }

  void _onReleaseUpdated(ReleaseView view) {
    setState(() {
      _view = view;
    });
  }

  void _onArtist() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => ArtistWidget(_view.artist)));
  }

  void _onPlay() {
    MediaQueue.play(release: release);
  }

  void _onAdd() {
    MediaQueue.append(release: release);
  }

  void _onDownload() {
    Downloads.downloadRelease(release);
  }

  Future<void> _onRefresh() async {
    final client = Client();
    await client
        .release(release.id, ttl: Duration.zero)
        .then((v) => _onReleaseUpdated(v));
  }

  @override
  Widget build(BuildContext context) {
    final releaseUrl = 'https://musicbrainz.org/release/${release.reid}';
    final releaseGroupUrl =
        'https://musicbrainz.org/release-group/${release.rgid}';
    return FutureBuilder(
        future: getImageBackgroundColor(release.image),
        builder: (context, snapshot) => Scaffold(
            backgroundColor: snapshot?.data,
            body: RefreshIndicator(
                onRefresh: () => _onRefresh(),
                child: StreamBuilder(
                    stream: TrackCache.keysSubject,
                    builder: (context, snapshot) {
                      final keys = snapshot.data ?? Set<String>();
                      final isCached = _view != null
                          ? TrackCache.checkAll(keys, _view.tracks)
                          : false;
                      return CustomScrollView(slivers: [
                        SliverAppBar(
                          // floating: true,
                          // snap: false,
                          expandedHeight: 300.0,
                          actions: [
                            popupMenu(context, [
                              PopupItem.link('MusicBrainz Release',
                                  (_) => launch(releaseUrl)),
                              PopupItem.link('MusicBrainz Release Group',
                                  (_) => launch(releaseGroupUrl)),
                              PopupItem.refresh((_) => _onRefresh()),
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
                                releaseSmallCover(release.image),
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
                                    child: _playButton(isCached)),
                                Align(
                                    alignment: Alignment.bottomCenter,
                                    child: TextButton.icon(
                                        icon: Icon(Icons.people),
                                        label: Text(release.artist),
                                        onPressed: _onArtist)),
                                Align(
                                    alignment: Alignment.bottomRight,
                                    child: _downloadButton(isCached)),
                              ])),
                        ),
                        SliverToBoxAdapter(
                            child: Column(children: [
                          _title(),
                          // _subtitle(),
                        ])),
                        if (_view != null)
                          SliverToBoxAdapter(
                              child: _ReleaseTracksWidget(_view)),
                        if (_view != null)
                          SliverToBoxAdapter(
                            child: heading('Similar Releases'),
                          ),
                        if (_view != null && _view.similar.isNotEmpty)
                          AlbumGridWidget(_view.similar),
                      ]);
                    }))));
  }

  Widget _title() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      Expanded(child: heading(release.name)),
      if (isNotNullOrEmpty(release.date))
        Padding(child: Text(year(release.date)), padding: EdgeInsets.all(11))
      // child: Padding(
      //     padding: EdgeInsets.fromLTRB(5, 8, 5, 0),
      //     child: Text(release.name,
      //         overflow: TextOverflow.ellipsis,
      //         textAlign: TextAlign.center,
      //         style: Theme.of(context).textTheme.headline6)))
    ]);
  }

  Widget _subtitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
            icon: Icon(Icons.people),
            label: Text(release.artist),
            onPressed: _onArtist),
      ],
    );
  }

  Widget _playButton(bool isCached) {
    return StreamBuilder<ConnectivityResult>(
        stream: TakeoutState.connectivityStream.distinct(),
        builder: (context, snapshot) {
          final result = snapshot.data;
          return IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: TakeoutState.allowStreaming(result) || isCached == true
                  ? () => _onPlay()
                  : null);
        });
  }

  Widget _downloadButton(bool isCached) {
    return StreamBuilder<ConnectivityResult>(
        stream: TakeoutState.connectivityStream.distinct(),
        builder: (context, snapshot) {
          final result = snapshot.data;
          return IconButton(
              icon: Icon(isCached
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_download_outlined),
              onPressed: TakeoutState.allowDownload(result)
                  ? () => _onDownload()
                  : null);
        });
  }
}

class _ReleaseTracksWidget extends StatelessWidget {
  final ReleaseView _view;

  _ReleaseTracksWidget(this._view);

  void _onTap(int index) {
    MediaQueue.play(index: index, release: _view.release);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: TrackCache.keysSubject,
        builder: (context, snapshot) {
          final keys = snapshot.data ?? Set<String>();
          int discs = _view.discs;
          int d = 0;
          List<Widget> children = [];
          for (var i = 0; i < _view.tracks.length; i++) {
            final e = _view.tracks[i];
            if (discs > 1 && e.discNum != d) {
              if (e.discNum > 1) {
                children.add(Divider());
              }
              children.add(smallHeading('Disc ${e.discNum} of $discs'));
              d = e.discNum;
            }
            children.add(ListTile(
                onTap: () => _onTap(i),
                leading: Container(
                    padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                    child: Text('${e.trackNum}',
                        style: TextStyle(fontWeight: FontWeight.w200))),
                trailing: Icon(
                    keys.contains(e.key) ? Icons.download_done_sharp : null),
                subtitle: Text(e.artist),
                title: Text(e.title)));
          }
          return Column(children: children);
        });
  }
}

class AlbumGridWidget extends StatelessWidget {
  final List<MusicAlbum> _albums;
  final bool subtitle;

  AlbumGridWidget(this._albums, {this.subtitle = true});

  @override
  Widget build(BuildContext context) {
    return SliverGrid.count(
        crossAxisCount: 3,
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

  void _onTap(BuildContext context, MusicAlbum album) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) {
          if (album is Release) {
            return ReleaseWidget(album);
          }
          else if (album is DownloadEntry) {
            return DownloadWidget(album.spiff);
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

  ReleaseListWidget(this._releases);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._releases.map((e) => Container(
          child: ListTile(
              leading: tileCover(e.image),
              onTap: () => _onTapped(context, e),
              // trailing: IconButton(
              //     icon: Icon(Icons.playlist_add),
              //     onPressed: () => _onAppend(e)),
              trailing: IconButton(
                  icon: Icon(Icons.playlist_play), onPressed: () => _onPlay(e)),
              title: Text('${_name(e)}'),
              subtitle: Text(year(e.date)))))
    ]);
  }

  void _onTapped(BuildContext context, Release release) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => ReleaseWidget(release)));
  }

  void _onAppend(Release release) {
    MediaQueue.append(release: release);
  }

  void _onPlay(Release release) {
    MediaQueue.play(release: release);
  }
}
