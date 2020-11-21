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

import 'artists.dart';
import 'cache.dart';
import 'client.dart';
import 'cover.dart';
import 'music.dart';
import 'playlist.dart';
import 'style.dart';

class ReleaseWidget extends StatefulWidget {
  final Release release;

  ReleaseWidget(this.release);

  @override
  State<StatefulWidget> createState() => _ReleaseState(release);
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
    PlaylistFacade().play(track: track, release: release);
  }

  void _onTrackAdd(Track track) {
    PlaylistFacade().append(track: track);
  }

  void _onArtist() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => ArtistWidget(_view.artist)));
  }

  void _onPlay() {
    PlaylistFacade().play(release: release);
  }

  void _onAdd() {
    PlaylistFacade().append(release: release);
  }

  void _onDownload() {
    if (_isCached) {
      return;
    }
    snackBarDownload(release: release, complete: false);
    Client().downloadTracks(_view.tracks).then((value) {
      if (!_disposed) {
        _checkCache();
        return;
      }
      snackBarDownload(release: release, complete: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar:
            AppBar(title: header(release.name), actions: [Icon(Icons.cast)]),
        body: Builder(
            builder: (context) => SingleChildScrollView(
                    child: Column(
                  children: [
                    if (_view != null) ...[
                      Container(
                          child: GestureDetector(
                              onTap: () => _onArtist(),
                              child: heading(
                                '${release.artist} \u2022 ${year(release)}',
                              )),
                          padding: EdgeInsets.fromLTRB(0, 11, 0, 0)),
                      Container(
                          padding: EdgeInsets.fromLTRB(0, 11, 0, 0),
                          child: GestureDetector(
                              onTap: () => _onPlay(),
                              child: releaseCover(release))),
                      Container(
                          padding: EdgeInsets.fromLTRB(0, 11, 0, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                  icon: Icon(Icons.playlist_play),
                                  onPressed: () => _onPlay()),
                              IconButton(
                                  icon: Icon(Icons.playlist_add),
                                  onPressed: () => _onAdd()),
                              IconButton(
                                  icon: Icon(Icons.people_alt),
                                  onPressed: () => _onArtist()),
                              IconButton(
                                  icon: Icon(_isCached == null
                                      ? Icons.hourglass_bottom_sharp
                                      : _isCached
                                          ? Icons.download_done_sharp
                                          : Icons.download_sharp),
                                  onPressed: () => _onDownload()),
                            ],
                          )),
                      Divider(),
                      heading('Tracks'),
                      Container(
                          child: ReleaseTracksWidget(
                              view: _view,
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
                ))));
  }
}

class ReleaseTracksWidget extends StatelessWidget {
  final ReleaseView view;
  final ValueChanged<Track> onTrackTapped;
  final ValueChanged<Track> onAppendTapped;

  ReleaseTracksWidget({this.view, this.onTrackTapped, this.onAppendTapped});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ...view.tracks.map((e) => ListTile(
          onTap: () => onTrackTapped(e),
          leading: Container(
              padding: EdgeInsets.fromLTRB(0, 12, 0, 0),
              child: Text('${e.trackNum}',
                  style: TextStyle(fontWeight: FontWeight.w200))),
          trailing: GestureDetector(
              child: Icon(Icons.playlist_add), onTap: () => onAppendTapped(e)),
          subtitle: Text(e.artist),
          title: Text(e.title)))
    ]);
  }
}

class ReleaseListWidget extends StatelessWidget {
  final List<Release> releases;

  ReleaseListWidget(this.releases);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ...releases.map((e) => Container(
          child: ListTile(
              leading: releaseCover(e),
              onTap: () => _onTapped(context, e),
              trailing: GestureDetector(
                child: Icon(Icons.playlist_add),
                onTap: () => _onAppend(e),
              ),
              title: Text(e.name),
              subtitle: Text(year(e)))))
    ]);
  }

  void _onTapped(BuildContext context, Release release) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => ReleaseWidget(release)));
  }

  void _onAppend(Release release) {
    var playlist = PlaylistFacade();
    playlist.append(release: release);
  }
}
