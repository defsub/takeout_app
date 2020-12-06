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

class _ReleaseState extends State<ReleaseWidget> {
  final Release release;
  ReleaseView _view;
  bool _isCached;
  bool _disposed = false;

  _ReleaseState(this.release);

  @override
  void initState() {
    super.initState();
    var client = Client();
    client.loggedIn().then((v) {
      client.release(release.id).then((v) => _onReleaseUpdated(v));
    });
  }

  @override
  void dispose() {
    super.dispose();
    _disposed = true;
  }

  void _checkCache() {
    TrackCache().contains(_view.tracks).then((v) => _onCachedUpdated(v));
  }

  void _onReleaseUpdated(ReleaseView view) {
    setState(() {
      _view = view;
      _checkCache();
    });
  }

  void _onCachedUpdated(bool v) {
    setState(() {
      _isCached = v;
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
    Downloads.downloadRelease(release).then((value) {
      if (!_disposed) {
        _checkCache();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: getCoverBackgroundColor(release: release),
        builder: (context, snapshot) => Scaffold(
            backgroundColor: snapshot?.data,
            appBar: AppBar(
                backgroundColor: snapshot?.data,
                title: header('${release.name} \u2022 ${year(release)}'),
                actions: [Icon(Icons.cast)]),
            body: Builder(
                builder: (context) => SingleChildScrollView(
                        child: Column(
                      children: [
                        if (_view != null) ...[
                          Container(
                              padding: EdgeInsets.fromLTRB(0, 11, 0, 0),
                              child: GestureDetector(
                                  onTap: () => _onPlay(),
                                  child: releaseCover(release))),
                          Container(
                              padding: EdgeInsets.fromLTRB(0, 11, 0, 0),
                              child: StreamBuilder<ConnectivityResult>(
                                  stream: TakeoutState.connectivityStream
                                      .distinct(),
                                  builder: (context, snapshot) {
                                    final result = snapshot.data;
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        IconButton(
                                            icon: Icon(Icons.playlist_play),
                                            onPressed:
                                                TakeoutState.allowStreaming(
                                                            result) ||
                                                        _isCached == true
                                                    ? () => _onPlay()
                                                    : null),
                                        IconButton(
                                            icon: Icon(Icons.playlist_add),
                                            onPressed: () => _onAdd()),
                                        IconButton(
                                            icon: Icon(_isCached == null
                                                ? Icons.hourglass_bottom_sharp
                                                : _isCached
                                                    ? Icons.download_done_sharp
                                                    : Icons.download_sharp),
                                            onPressed:
                                                TakeoutState.allowDownload(
                                                        result)
                                                    ? () => _onDownload()
                                                    : null),
                                      ],
                                    );
                                  })),
                          OutlinedButton(
                              onPressed: () => {_onArtist()},
                              child: Text(release.artist,
                                  style: TextStyle(fontSize: 15))),
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
                        ]
                      ],
                    )))));
  }
}

class _ReleaseTracksWidget extends StatelessWidget {
  final ReleaseView _view;
  final ValueChanged<Track> onTrackTapped;
  final ValueChanged<Track> onAppendTapped;

  _ReleaseTracksWidget(this._view, {this.onTrackTapped, this.onAppendTapped});

  @override
  Widget build(BuildContext context) {
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
          trailing: IconButton(
              icon: Icon(Icons.playlist_add),
              onPressed: () => onAppendTapped(e)),
          subtitle: Text(e.artist),
          title: Text(e.title)));
    });
    return Column(children: children);
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
              trailing: IconButton(
                  icon: Icon(Icons.playlist_add),
                  onPressed: () => _onAppend(e)),
              title: Text(e.name),
              subtitle: Text(year(e)))))
    ]);
  }

  void _onTapped(BuildContext context, Release release) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => ReleaseWidget(release)));
  }

  void _onAppend(Release release) {
    MediaQueue.append(release: release);
  }
}
