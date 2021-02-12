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
import 'package:recase/recase.dart';
import 'package:connectivity/connectivity.dart';
import 'package:url_launcher/url_launcher.dart';

import 'client.dart';
import 'cover.dart';
import 'music.dart';
import 'playlist.dart';
import 'release.dart';
import 'style.dart';
import 'radio.dart';
import 'spiff.dart';
import 'downloads.dart';
import 'main.dart';
import 'menu.dart';

class ArtistsWidget extends StatefulWidget {
  final ArtistsView _view;
  final String genre;
  final String area;

  ArtistsWidget(this._view, {this.genre, this.area});

  ArtistsView get view => _view;

  @override
  State<StatefulWidget> createState() =>
      _ArtistsState(_view, genre: genre, area: area);
}

class _ArtistsState extends State<ArtistsWidget> {
  ArtistsView _view;
  String genre;
  String area;

  _ArtistsState(this._view, {this.genre, this.area});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: genre != null
                ? header('Artists \u2013 $genre')
                : area != null
                    ? header('Artists \u2013 $area')
                    : header('Artists'),
            actions: [
              popupMenu(context, [
                PopupItem.refresh((_) => _onRefresh()),
              ])
            ]),
        body: RefreshIndicator(
            onRefresh: () => _onRefresh(),
            child: ArtistListWidget(genre != null
                ? _view.artists.where((a) => a.genre == genre).toList()
                : area != null
                    ? _view.artists.where((a) => a.area == area).toList()
                    : _view.artists)));
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

String _subtitle(Artist artist) {
  final genre = ReCase(artist.genre).titleCase;

  if (isNullOrEmpty(artist.date)) {
    // no date, return genre
    return genre;
  }

  final y = year(artist.date);
  if (y.isEmpty) {
    // parsed date empty, return genre
    return genre;
  }

  // no genre, return year
  if (isNullOrEmpty(artist.genre)) {
    return y;
  }

  // have both
  return '$genre \u2022 $y';
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
                final artist = _artists[index];
                return ListTile(
                    onTap: () => _onArtist(context, artist),
                    leading: Icon(Icons.people_alt),
                    title: Text(artist.name),
                    subtitle: Text(_subtitle(artist)));
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

  _ArtistState(this._artist);

  @override
  void initState() {
    super.initState();
    final client = Client();
    client.artist(_artist.id).then((v) => _onArtistUpdated(v));
  }

  void _onArtistUpdated(ArtistView view) {
    setState(() {
      _view = view;
    });
  }

  void _onRadio() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RefreshSpiffWidget(
                () => Client().artistRadio(_artist.id, ttl: Duration.zero))));
  }

  void _onShuffle() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RefreshSpiffWidget(() =>
                Client().artistPlaylist(_artist.id, ttl: Duration.zero))));
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

  Future<void> _onRefresh() async {
    final client = Client();
    await client
        .artist(_artist.id, ttl: Duration.zero)
        .then((v) => _onArtistUpdated(v));
  }

  void _onGenre(BuildContext context, String genre) async {
    try {
      final client = Client();
      final result = await client.artists();
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ArtistsWidget(result, genre: genre)));
    } catch (error) {
      print('refresh err $error');
    }
  }

  void _onArea(BuildContext context, String area) async {
    try {
      final client = Client();
      final result = await client.artists();
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ArtistsWidget(result, area: area)));
    } catch (error) {
      print('refresh err $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityResult>(
        stream: TakeoutState.connectivityStream.distinct(),
        builder: (context, snapshot) {
          final connectivity = snapshot.data;
          final artistUrl = 'https://musicbrainz.org/artist/${_artist.arid}';
          // TODO check if already cached and allow
          bool allowArtwork = _view != null &&
              isNotNullOrEmpty(_view.image) &&
              TakeoutState.allowArtwork(connectivity);
          return FutureBuilder(
              future: allowArtwork
                  ? getImageBackgroundColor(url: _view.image)
                  : Future.value(),
              builder: (context, snapshot) => Scaffold(
                  appBar: AppBar(
                    title: header(_artist.name),
                    backgroundColor: snapshot?.data,
                    actions: [
                      popupMenu(context, [
                        PopupItem.refresh((_) => _onRefresh()),
                        PopupItem.link(
                            'MusicBrainz Artist', (_) => launch(artistUrl))
                      ])
                    ],
                  ),
                  backgroundColor: snapshot?.data,
                  body: RefreshIndicator(
                      onRefresh: () => _onRefresh(),
                      child: _view == null
                          ? Center(child: CircularProgressIndicator())
                          : Builder(
                              builder: (context) => SingleChildScrollView(
                                      child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (allowArtwork)
                                        Container(
                                            padding: EdgeInsets.fromLTRB(
                                                0, 11, 0, 0),
                                            child: GestureDetector(
                                                onTap: () => {},
                                                child: artwork(_view.image,
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .height *
                                                            0.4))),
                                      Container(
                                          child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (isNotNullOrEmpty(_artist.genre))
                                            FlatButton(
                                              child: Text(
                                                  '${ReCase(_artist.genre).titleCase}'),
                                              onPressed: () => _onGenre(
                                                  context, _artist.genre),
                                            ),
                                          if (isNotNullOrEmpty(_artist.area))
                                            FlatButton(
                                              child: Text('${_artist.area}'),
                                              onPressed: () => _onArea(
                                                  context, _artist.area),
                                            ),
                                        ],
                                      )),
                                      Container(
                                          padding:
                                              EdgeInsets.fromLTRB(0, 0, 0, 0),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              OutlinedButton.icon(
                                                  label: Text('Shuffle'),
                                                  icon:
                                                      Icon(Icons.shuffle_sharp),
                                                  onPressed: () =>
                                                      _onShuffle()),
                                              OutlinedButton.icon(
                                                  label: Text('Radio'),
                                                  icon: Icon(Icons.radio),
                                                  onPressed: () => _onRadio()),
                                            ],
                                          )),
                                      Divider(),
                                      heading('Releases'),
                                      ReleaseListWidget(_view.releases),
                                      if (_view.singles != null &&
                                          _view.singles.isNotEmpty)
                                        Container(
                                            child: Column(children: [
                                          Divider(),
                                          headingButton('Singles',
                                              () => _onSingles(context)),
                                          TrackListWidget(_view.singles),
                                        ])),
                                      if (_view.popular != null &&
                                          _view.popular.isNotEmpty)
                                        Container(
                                            child: Column(children: [
                                          Divider(),
                                          headingButton('Popular',
                                              () => _onPopular(context)),
                                          TrackListWidget(_view.popular),
                                        ])),
                                      if (_view.similar != null &&
                                          _view.similar.isNotEmpty)
                                        Container(
                                            child: Column(children: [
                                          Divider(),
                                          heading('Similar Artists'),
                                          SimilarArtistListWidget(_view)
                                        ])),
                                      FlatButton.icon(
                                        label: Text('MusicBrainz Artist'),
                                        icon: Icon(Icons.link),
                                        onPressed: () => launch(artistUrl),
                                      )
                                    ],
                                  ))))));
        });
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
          title: Text(a.name),
          subtitle: Text(_subtitle(a))))
    ]);
  }

  void _onArtist(BuildContext context, Artist artist) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => ArtistWidget(artist)));
  }
}

class TrackListWidget extends StatelessWidget {
  final List<Track> _tracks;

  TrackListWidget(this._tracks);

  void _onPlay(int index) {
    MediaQueue.playTracks(_tracks, index: index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._tracks.asMap().keys.toList().map((index) => ListTile(
          onTap: () => _onPlay(index),
          leading: trackCover(_tracks[index]),
          // trailing: IconButton(
          //     icon: Icon(Icons.playlist_add), onPressed: () => onAdd(t)),
          subtitle:
              Text('${_tracks[index].release} \u2022 ${_tracks[index].date}'),
          title: Text(_tracks[index].title)))
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
    final client = Client();
    if (_type == ArtistTrackType.popular) {
      client.artistPopular(_artist.id).then((v) => _onPopularUpdated(v));
    } else if (_type == ArtistTrackType.singles) {
      client.artistSingles(_artist.id).then((v) => _onSinglesUpdated(v));
    }
  }

  Future<void> _onRefresh() async {
    final client = Client();
    if (_type == ArtistTrackType.popular) {
      await client
          .artistPopular(_artist.id, ttl: Duration.zero)
          .then((v) => _onPopularUpdated(v));
    } else if (_type == ArtistTrackType.singles) {
      await client
          .artistSingles(_artist.id, ttl: Duration.zero)
          .then((v) => _onSinglesUpdated(v));
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

  Future<Spiff> _playlist() {
    final client = Client();
    Future<Spiff> result = _type == ArtistTrackType.popular
        ? client.artistPopularPlaylist(_artist.id, ttl: Duration.zero)
        : _type == ArtistTrackType.singles
            ? client.artistSinglesPlaylist(_artist.id, ttl: Duration.zero)
            : null;
    return result;
  }

  void _onPlay() async {
    Future<Spiff> result = _playlist();
    result?.then((spiff) => MediaQueue.playSpiff(spiff));
  }

  void _onDownload() async {
    Future<Spiff> result = _playlist();
    result?.then((spiff) => Downloads.downloadSpiff(spiff));
  }

  void _onTrack(int index) {
    Future<Spiff> result = _playlist();
    result?.then((spiff) => MediaQueue.playSpiff(spiff, index: index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: header(_type == ArtistTrackType.popular
                ? '${_artist.name} \u2013 Popular'
                : '${_artist.name} \u2013 Singles')),
        body: RefreshIndicator(
            onRefresh: () => _onRefresh(),
            child: _tracks == null
                ? Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        OutlinedButton.icon(
                            label: Text('Play'),
                            icon: Icon(Icons.playlist_play),
                            onPressed: () => _onPlay()),
                        OutlinedButton.icon(
                            label: Text('Download'),
                            icon: Icon(Icons.radio),
                            onPressed: () => _onDownload()),
                      ],
                    ),
                    ..._tracks.asMap().keys.toList().map((index) => ListTile(
                        onTap: () => _onTrack(index),
                        leading: trackCover(_tracks[index]),
                        // trailing: IconButton(
                        //     icon: Icon(Icons.playlist_add),
                        //     onPressed: () => _onAdd(t)),
                        subtitle: Text(
                            '${_tracks[index].release} \u2022 ${_tracks[index].date}'),
                        title: Text(_tracks[index].title)))
                  ]))));
  }
}
