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

import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:takeout_app/main.dart';

import 'client.dart';
import 'cover.dart';
import 'music.dart';
import 'playlist.dart';
import 'release.dart';
import 'style.dart';
import 'cache.dart';

class ArtistsWidget extends StatefulWidget {
  final ArtistsView view;

  ArtistsWidget(this.view);

  @override
  State<StatefulWidget> createState() => _ArtistsState(view);
}

class _ArtistsState extends State<ArtistsWidget> {
  final ArtistsView _view;

  _ArtistsState(this._view);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Artists')),
        body: ArtistListWidget(_view));
  }
}

class ArtistListWidget extends StatelessWidget {
  final ArtistsView view;

  ArtistListWidget(this.view);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
          child: ListView.builder(
              itemCount: view.artists.length,
              itemBuilder: (context, index) {
                return ListTile(
                    onTap: () => _onArtist(context, view.artists[index]),
                    leading: Icon(Icons.people_alt),
                    title: Text(view.artists[index].name));
              }))
    ]);
  }

  void _onArtist(BuildContext context, Artist artist) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => ArtistWidget(artist)));
  }
}

class ArtistWidget extends StatefulWidget {
  final Artist _artist;

  ArtistWidget(this._artist);

  @override
  State<StatefulWidget> createState() => _ArtistState(_artist);
}

class _ArtistState extends State<ArtistWidget> {
  final Artist artist;
  ArtistView _view;
  bool _isCached;
  bool _disposed = false;

  _ArtistState(this.artist);

  @override
  void initState() {
    super.initState();
    final client = Client();
    client.loggedIn().then((v) {
      client.artist(artist.id).then((v) => _onArtistUpdated(v));
    });
  }

  @override
  void dispose() {
    super.dispose();
    _disposed = true;
  }

  void _checkCache() async {
    var result = false;
    final client = Client();
    final cache = TrackCache();
    for (var r in _view.releases) {
      final view = await client.release(r.id);
      result = await cache.contains(view.tracks);
      if (result == false) {
        break;
      }
    }
    if (!_disposed) {
      setState(() {
        _isCached = result;
      });
    }
  }

  void _onArtistUpdated(ArtistView view) {
    setState(() {
      _view = view;
      _checkCache();
    });
  }

  void _onTrackPlay(Track track) {
    PlaylistFacade().play(track: track);
  }

  void _onTrackAdd(Track track) {
    PlaylistFacade().append(track: track);
  }

  void _onPlay() {}

  void _onDownload(BuildContext context) async {
    final client = Client();
    for (var r in _view.releases) {
      snackBarDownload(release: r, complete: false);
      await client.downloadRelease(r);
      snackBarDownload(release: r, complete: true);
    }
    if (!_disposed) {
      _checkCache();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: header(artist.name)),
        body: Builder(
            builder: (context) => SingleChildScrollView(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image, size: 250),
                    Container(
                        padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
                        child: StreamBuilder<ConnectivityResult>(
                            stream: TakeoutState.connectivityStream.distinct(),
                            builder: (context, snapshot) {
                              final result = snapshot.data;
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                      icon: Icon(Icons.playlist_play),
                                      onPressed:
                                          TakeoutState.allowStreaming(result) ||
                                                  _isCached == true
                                              ? () => _onPlay()
                                              : null),
                                  // IconButton(icon: Icon(Icons.playlist_add), onPressed: () => _onAdd()),
                                  IconButton(
                                      icon: Icon(_isCached == null
                                          ? Icons.hourglass_bottom_sharp
                                          : _isCached
                                              ? Icons.download_done_sharp
                                              : Icons.download_sharp),
                                      onPressed:
                                          TakeoutState.allowDownload(result)
                                              ? () => _onDownload(context)
                                              : null),
                                ],
                              );
                            })),
                    if (_view != null) ...[
                      Divider(),
                      heading('Releases'),
                      ReleaseListWidget(_view.releases),
                      if (_view.singles.isNotEmpty)
                        Container(
                            child: Column(children: [
                          Divider(),
                          heading('Singles'),
                          TrackListWidget(_view.singles,
                              onAdd: _onTrackAdd, onPlay: _onTrackPlay)
                        ])),
                      if (_view.popular.isNotEmpty)
                        Container(
                            child: Column(children: [
                          Divider(),
                          heading('Popular'),
                          TrackListWidget(_view.popular,
                              onAdd: _onTrackAdd, onPlay: _onTrackPlay)
                        ])),
                      if (_view.similar.isNotEmpty)
                        Container(
                            child: Column(children: [
                          Divider(),
                          heading('Similar Artists'),
                          SimilarArtistListWidget(_view)
                        ])),
                    ]
                  ],
                ))));
  }
}

class SimilarArtistListWidget extends StatelessWidget {
  final ArtistView _view;

  SimilarArtistListWidget(this._view);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._view.similar.map((a) => ListTile(
          onTap: () => _onArtist(context, a),
          leading: Icon(Icons.people_alt),
          title: Text(a.name)))
    ]);
  }

  void _onArtist(BuildContext context, Artist artist) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => ArtistWidget(artist)));
  }
}

class TrackListWidget extends StatelessWidget {
  final List<Track> _tracks;
  final ValueChanged<Track> onPlay;
  final ValueChanged<Track> onAdd;

  TrackListWidget(this._tracks, {this.onPlay, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._tracks.map((t) => ListTile(
          onTap: () => onPlay(t),
          leading: trackCover(t),
          trailing: GestureDetector(
              child: Icon(Icons.playlist_add), onTap: () => onAdd(t)),
          subtitle: Text('${t.artist} \u2022 ${t.release}'),
          title: Text(t.title)))
    ]);
  }
}
