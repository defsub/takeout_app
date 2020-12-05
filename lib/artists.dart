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
import 'package:takeout_app/global.dart';
import 'package:takeout_app/main.dart';

import 'client.dart';
import 'cover.dart';
import 'music.dart';
import 'playlist.dart';
import 'release.dart';
import 'downloads.dart';
import 'style.dart';
import 'cache.dart';

class ArtistsWidget extends StatefulWidget {
  final ArtistsView _view;

  ArtistsWidget(this._view);

  ArtistsView get view => _view;

  @override
  State<StatefulWidget> createState() => _ArtistsState(_view);
}

class _ArtistsState extends State<ArtistsWidget> {
  ArtistsView _view;

  _ArtistsState(this._view);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: header('Artists')),
        body: RefreshIndicator(
            onRefresh: () => _onRefresh(),
            child: ArtistListWidget(_view.artists)));
  }

  Future<void> _onRefresh() async {
    try {
      final client = Client();
      final result = await client.artists(ttl: Duration.zero);
      setState(() {
        _view = result;
      });
    } catch (error) {
      print('refresh err $error');
    }
  }
}

class ArtistListWidget extends StatelessWidget {
  final List<Artist> _artists;

  ArtistListWidget(this._artists);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
          child: ListView.builder(
              itemCount: _artists.length,
              itemBuilder: (buildContext, index) {
                return ListTile(
                    onTap: () => _onArtist(context, _artists[index]),
                    leading: Icon(Icons.people_alt),
                    title: Text(_artists[index].name));
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
  final Artist _artist;
  ArtistView _view;
  bool _isCached;
  bool _disposed = false;

  _ArtistState(this._artist);

  @override
  void initState() {
    super.initState();
    final client = Client();
    client.loggedIn().then((v) {
      client.artist(_artist.id).then((v) => _onArtistUpdated(v));
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
    MediaQueue.play(track: track);
  }

  void _onTrackAdd(Track track) {
    MediaQueue.append(track: track);
  }

  void _onPlay() {}

  void _onDownload(BuildContext context) async {
    // final client = Client();
    // for (var r in _view.releases) {
    //   showDownloadSnackBar(release: r, isComplete: false);
    //   await client.downloadRelease(r);
    //   showDownloadSnackBar(release: r, isComplete: true);
    // }
    // if (!_disposed) {
    //   _checkCache();
    // }
    Downloads.downloadArtist(_artist);
  }

  void _onSingles(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                ArtistTrackListWidget(_artist, ArtistTrackType.singles)));
  }

  void _onPopular(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                ArtistTrackListWidget(_artist, ArtistTrackType.popular)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: header(_artist.name)),
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
                          headingButton('Singles', () {
                            _onSingles(context);
                          }),
                          TrackListWidget(_view.singles,
                              onAdd: _onTrackAdd, onPlay: _onTrackPlay),
                        ])),
                      if (_view.popular.isNotEmpty)
                        Container(
                            child: Column(children: [
                          Divider(),
                          headingButton('Popular', () {
                            _onPopular(context);
                          }),
                          TrackListWidget(_view.popular,
                              onAdd: _onTrackAdd, onPlay: _onTrackPlay),
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
          subtitle: Text('${t.release} \u2022 ${t.date}'),
          title: Text(t.title)))
    ]);
  }
}

enum ArtistTrackType { singles, popular }

class ArtistTrackListWidget extends StatefulWidget {
  final Artist _artist;
  final ArtistTrackType _type;

  ArtistTrackListWidget(this._artist, this._type);

  @override
  State<StatefulWidget> createState() => _ArtistTrackListState(_artist, _type);
}

class _ArtistTrackListState extends State<ArtistTrackListWidget> {
  final Artist _artist;
  final ArtistTrackType _type;
  List<Track> _tracks;

  _ArtistTrackListState(this._artist, this._type);

  @override
  void initState() {
    super.initState();
    var client = Client();
    if (_type == ArtistTrackType.popular) {
      client.artistPopular(_artist.id).then((v) => _onPopularUpdated(v));
    } else if (_type == ArtistTrackType.singles) {
      client.artistSingles(_artist.id).then((v) => _onSinglesUpdated(v));
    }
  }

  void _onPopularUpdated(PopularView v) {
    setState(() {
      _tracks = v.popular;
    });
  }

  void _onSinglesUpdated(SinglesView v) {
    setState(() {
      _tracks = v.singles;
    });
  }

  void _onPlay(Track t) {}

  void _onAdd(Track t) {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: header(
                _type == ArtistTrackType.popular ? 'Popular' : 'Singles')),
        body: _tracks == null
            ? Text('loading')
            : SingleChildScrollView(
                child: Column(children: [
                ..._tracks.map((t) => ListTile(
                    onTap: () => _onPlay(t),
                    leading: trackCover(t),
                    trailing: GestureDetector(
                        child: Icon(Icons.playlist_add),
                        onTap: () => _onAdd(t)),
                    subtitle: Text('${t.release} \u2022 ${t.date}'),
                    title: Text(t.title)))
              ])));
  }
}
