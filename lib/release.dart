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
import 'package:url_launcher/url_launcher.dart';

import 'artists.dart';
import 'cache.dart';
import 'client.dart';
import 'cover.dart';
import 'music.dart';
import 'playlist.dart';
import 'style.dart';
import 'main.dart';
import 'downloads.dart';

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

  void _onTrackPlay(Track track) {
    MediaQueue.play(track: track, release: release);
  }

  void _onTrackAdd(Track track) {
    MediaQueue.append(track: track);
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
    return FutureBuilder(
        future: getImageBackgroundColor(release: release),
        builder: (context, snapshot) => Scaffold(
            backgroundColor: snapshot?.data,
            appBar: AppBar(
                backgroundColor: snapshot?.data,
                title: header('${_name(release)}')),
            body: RefreshIndicator(
                onRefresh: () => _onRefresh(),
                child: _view == null
                    ? Center(child: CircularProgressIndicator())
                    : Builder(
                        builder: (context) => SingleChildScrollView(
                            child: StreamBuilder(
                                stream: TrackCache.keysSubject,
                                builder: (context, snapshot) {
                                  final keys = snapshot.data ?? Set<String>();
                                  final isCached = _view != null
                                      ? TrackCache.checkAll(keys, _view.tracks)
                                      : false;
                                  final releaseUrl =
                                      'https://musicbrainz.org/release/${release.reid}';
                                  return Column(
                                    children: [
                                      if (_view != null) ...[
                                        Container(
                                            padding: EdgeInsets.fromLTRB(
                                                0, 11, 0, 0),
                                            child: GestureDetector(
                                                onTap: () => _onPlay(),
                                                child: releaseCover(release))),
                                        Container(
                                            child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            FlatButton(
                                                child: Text(release.artist),
                                                onPressed: () => _onArtist()),
                                            if (isNotNullOrEmpty(release.date))
                                              Text(year(release.date))
                                          ],
                                        )),
                                        Container(
                                            padding:
                                                EdgeInsets.fromLTRB(0, 0, 0, 0),
                                            child: StreamBuilder<
                                                    ConnectivityResult>(
                                                stream: TakeoutState
                                                    .connectivityStream
                                                    .distinct(),
                                                builder: (context, snapshot) {
                                                  final result = snapshot.data;
                                                  return Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: [
                                                      OutlinedButton.icon(
                                                          label: Text('Play'),
                                                          icon: Icon(Icons
                                                              .playlist_play),
                                                          onPressed: TakeoutState
                                                                      .allowStreaming(
                                                                          result) ||
                                                                  isCached ==
                                                                      true
                                                              ? () => _onPlay()
                                                              : null),
                                                      // IconButton(
                                                      //     icon: Icon(Icons.playlist_add),
                                                      //     onPressed: () => _onAdd()),
                                                      OutlinedButton.icon(
                                                          label: Text(isCached
                                                              ? 'Complete'
                                                              : 'Download'),
                                                          icon: Icon(isCached
                                                              ? Icons
                                                                  .cloud_done_outlined
                                                              : Icons
                                                                  .cloud_download_outlined),
                                                          onPressed: TakeoutState
                                                                  .allowDownload(
                                                                      result)
                                                              ? () =>
                                                                  _onDownload()
                                                              : null),
                                                    ],
                                                  );
                                                })),
                                        Divider(),
                                        // heading('Tracks'),
                                        Container(
                                            child: _ReleaseTracksWidget(_view,
                                                onTrackTapped: _onTrackPlay,
                                                onAppendTapped: _onTrackAdd)),
                                        if (_view.similar.isNotEmpty)
                                          Container(
                                              child: Column(children: [
                                            Divider(),
                                            heading('Similar Releases'),
                                            ReleaseListWidget(_view.similar)
                                          ]))
                                      ],
                                      FlatButton.icon(
                                        label: Text('MusicBrainz'),
                                        icon: Icon(Icons.link),
                                        onPressed: () => launch(releaseUrl),
                                      )
                                    ],
                                  );
                                }))))));
  }
}

class _ReleaseTracksWidget extends StatelessWidget {
  final ReleaseView _view;
  final ValueChanged<Track> onTrackTapped;
  final ValueChanged<Track> onAppendTapped;

  _ReleaseTracksWidget(this._view, {this.onTrackTapped, this.onAppendTapped});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: TrackCache.keysSubject,
        builder: (context, snapshot) {
          final keys = snapshot.data ?? Set<String>();
          int discs = _view.discs;
          int d = 0;
          var children = List<Widget>();
          _view.tracks.forEach((e) {
            if (discs > 1 && e.discNum != d) {
              if (e.discNum > 1) {
                children.add(Divider());
              }
              children.add(smallHeading('Disc ${e.discNum} of $discs'));
              d = e.discNum;
            }
            children.add(ListTile(
                onTap: () => onTrackTapped(e),
                leading: Container(
                    padding: EdgeInsets.fromLTRB(12, 12, 0, 0),
                    child: Text('${e.trackNum}',
                        style: TextStyle(fontWeight: FontWeight.w200))),
                trailing: Icon(
                    keys.contains(e.key) ? Icons.download_done_sharp : null),
                subtitle: Text(e.artist),
                title: Text(e.title)));
          });
          return Column(children: children);
        });
  }
}

class ReleaseListWidget extends StatelessWidget {
  final List<Release> _releases;

  ReleaseListWidget(this._releases);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._releases.map((e) => Container(
          child: ListTile(
              leading: releaseCover(e),
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
