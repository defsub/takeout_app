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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:recase/recase.dart';
import 'package:connectivity/connectivity.dart';
import 'package:url_launcher/url_launcher.dart';

import 'client.dart';
import 'cover.dart';
import 'downloads.dart';
import 'main.dart';
import 'schema.dart';
import 'playlist.dart';
import 'release.dart';
import 'style.dart';
import 'spiff.dart';
import 'menu.dart';
import 'util.dart';
import 'global.dart';

class ArtistsWidget extends StatefulWidget {
  final ArtistsView _view;
  final String? genre;
  final String? area;

  ArtistsWidget(this._view, {this.genre, this.area});

  ArtistsView get view => _view;

  @override
  State<StatefulWidget> createState() =>
      _ArtistsState(_view, genre: genre, area: area);
}

class _ArtistsState extends State<ArtistsWidget> {
  ArtistsView _view;
  String? genre;
  String? area;

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
      if (mounted) {
        setState(() {
          loadArtistMap(_view.artists);
          _view = result;
        });
      }
    } catch (error) {
      print('refresh err $error');
    }
  }
}

String _subtitle(Artist artist) {
  final genre = ReCase(artist.genre ?? '').titleCase;

  if (isNullOrEmpty(artist.date)) {
    // no date, return genre
    return genre;
  }

  final y = year(artist.date ?? '');
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

class _ArtistState extends State<ArtistWidget> with ArtistBuilder {
  final Artist _artist;
  ArtistView? _view;

  _ArtistState(this._artist);

  @override
  void initState() {
    super.initState();
    final client = Client();
    client.artist(_artist.id).then((v) => _onArtistUpdated(v));
  }

  void _onArtistUpdated(ArtistView view) {
    if (mounted) {
      setState(() {
        _view = view;
      });
    }
  }

  void _onRadio() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => DownloadWidget(
                fetch: () =>
                    Client().artistRadio(_artist.id, ttl: Duration.zero))));
  }

  void _onShuffle() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => DownloadWidget(
                fetch: () =>
                    Client().artistPlaylist(_artist.id, ttl: Duration.zero))));
  }

  void _onSingles(BuildContext context) {
    if (_view == null) {
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ArtistTrackListWidget(
                _view!, _artist, ArtistTrackType.singles)));
  }

  void _onPopular(BuildContext context) {
    if (_view == null) {
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ArtistTrackListWidget(
                _view!, _artist, ArtistTrackType.popular)));
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

  ArtistView? get view => _view;

  Future<void> onRefresh() => _onRefresh();

  List<Widget> actions() {
    final artistUrl = 'https://musicbrainz.org/artist/${_artist.arid}';
    final genre = ReCase(_artist.genre ?? '').titleCase;
    return <Widget>[
      popupMenu(context, [
        PopupItem.shuffle((_) => _onShuffle()),
        PopupItem.radio((_) => _onRadio()),
        PopupItem.divider(),
        PopupItem.singles((_) => _onSingles(context)),
        PopupItem.popular((_) => _onPopular(context)),
        PopupItem.divider(),
        if (_artist.genre != null)
          PopupItem.genre(genre, (_) => _onGenre(context, _artist.genre!)),
        if (_artist.area != null)
          PopupItem.area(_artist.area!, (_) => _onArea(context, _artist.area!)),
        PopupItem.divider(),
        PopupItem.link('MusicBrainz Artist', (_) => launch(artistUrl)),
        PopupItem.divider(),
        PopupItem.refresh((_) => _onRefresh()),
      ])
    ];
  }

  Widget leftButton() {
    return IconButton(icon: Icon(Icons.shuffle_sharp), onPressed: _onShuffle);
  }

  Widget rightButton() {
    return IconButton(icon: Icon(Icons.radio), onPressed: _onRadio);
  }

  List<Widget> slivers() {
    if (_view == null) {
      return [];
    }
    return [
      SliverToBoxAdapter(child: heading('Releases')),
      AlbumGridWidget(
        _view!.releases,
        subtitle: false,
      ),
      if (_view!.similar.isNotEmpty)
        SliverToBoxAdapter(child: heading('Similar Artists')),
      if (_view!.similar.isNotEmpty)
        SliverToBoxAdapter(child: SimilarArtistListWidget(_view!))
    ];
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
    showPlayer();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._tracks.asMap().keys.toList().map((index) => ListTile(
          onTap: () => _onPlay(index),
          leading: tileCover(_tracks[index].image),
          subtitle:
              Text('${_tracks[index].artist} \u2022 ${_tracks[index].release} \u2022 ${_tracks[index].date}'),
          title: Text(_tracks[index].title)))
    ]);
  }
}

enum ArtistTrackType { singles, popular }

class ArtistTrackListWidget extends StatefulWidget {
  final ArtistView _view;
  final Artist _artist;
  final ArtistTrackType _type;

  ArtistTrackListWidget(this._view, this._artist, this._type);

  @override
  State<StatefulWidget> createState() =>
      _ArtistTrackListState(_view, _artist, _type);
}

class _ArtistTrackListState extends State<ArtistTrackListWidget>
    with ArtistBuilder {
  final ArtistView _view;
  final Artist _artist;
  ArtistTrackType _type;
  List<Track> _tracks = const [];

  _ArtistTrackListState(this._view, this._artist, this._type);

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  void _loadState() {
    final client = Client();
    if (_type == ArtistTrackType.popular) {
      client.artistPopular(_artist.id).then((v) => _onPopularUpdated(v));
    } else if (_type == ArtistTrackType.singles) {
      client.artistSingles(_artist.id).then((v) => _onSinglesUpdated(v));
    }
  }

  void _onChangeType(ArtistTrackType type) {
    setState(() {
      _type = type;
      _loadState();
    });
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
    if (mounted) {
      setState(() {
        _tracks = v.popular;
      });
    }
  }

  void _onSinglesUpdated(SinglesView v) {
    if (mounted) {
      setState(() {
        _tracks = v.singles;
      });
    }
  }

  Future<Spiff> _playlist() {
    final client = Client();
    Future<Spiff> result = _type == ArtistTrackType.popular
        ? client.artistPopularPlaylist(_artist.id, ttl: Duration.zero)
        : _type == ArtistTrackType.singles
            ? client.artistSinglesPlaylist(_artist.id, ttl: Duration.zero)
            : client.artistSinglesPlaylist(_artist.id, ttl: Duration.zero);
    return result;
  }

  void _onPlay() async {
    Future<Spiff> result = _playlist();
    result.then((spiff) => MediaQueue.playSpiff(spiff));
  }

  void _onDownload() async {
    Future<Spiff> result = _playlist();
    result.then((spiff) => Downloads.downloadSpiff(spiff));
  }

  void _onTrack(int index) {
    Future<Spiff> result = _playlist();
    result.then((spiff) => MediaQueue.playSpiff(spiff, index: index));
  }

  ArtistView get view => _view;

  Future<void> onRefresh() => _onRefresh();

  List<Widget> actions() => [
        popupMenu(context, [
          if (_type == ArtistTrackType.singles)
            PopupItem.popular((_) => _onChangeType(ArtistTrackType.popular)),
          if (_type == ArtistTrackType.popular)
            PopupItem.singles((_) => _onChangeType(ArtistTrackType.singles)),
          PopupItem.refresh((_) => _onRefresh()),
        ])
      ];

  Widget leftButton() {
    return IconButton(icon: Icon(Icons.play_arrow, size: 32), onPressed: _onPlay);
  }

  Widget rightButton() {
    return IconButton(
        icon: Icon(Icons.cloud_download_outlined), onPressed: _onDownload);
  }

  List<Widget> slivers() {
    return [
      SliverToBoxAdapter(
          child: heading(
              _type == ArtistTrackType.singles ? 'Singles' : 'Popular')),
      SliverToBoxAdapter(child: Column(children: _trackList())),
    ];
  }

  List<ListTile> _trackList() {
    List<ListTile> list = [];
    int index = 0;
    for (var t in _tracks) {
      list.add(ListTile(
          onTap: () => _onTrack(index),
          leading: tileCover(t.image),
          subtitle: Text('${t.release} \u2022 ${t.date}'),
          title: Text(t.title)));
      index++;
    }
    return list;
  }
}

mixin ArtistBuilder {
  ArtistView? get view;

  Future<void> onRefresh();

  List<Widget> actions();

  Widget leftButton();

  Widget rightButton();

  List<Widget> slivers();

  static Random _random = Random();

  String _randomCover() {
    final artistView = view;
    if (artistView == null) {
      return '';
    }
    for (var i = 0; i < artistView.releases.length; i++) {
      final pick = _random.nextInt(artistView.releases.length);
      if (isNotNullOrEmpty(artistView.releases[pick].image)) {
        return artistView.releases[pick].image;
      }
    }
    for (var i = 0; i < artistView.releases.length; i++) {
      if (isNotNullOrEmpty(artistView.releases[i].image)) {
        return artistView.releases[i].image;
      }
    }
    return '';
  }

  Widget _albumArtwork() {
    String url = _randomCover();
    return isNotNullOrEmpty(url) ? releaseSmallCover(url) : Icon(Icons.people);
  }

  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityResult>(
        stream: TakeoutState.connectivityStream.distinct(),
        builder: (context, snapshot) {
          final connectivity = snapshot.data;

          final useBackground = false;
          final artistView = view;
          final artistArtworkUrl = artistView != null
              ? useBackground
                  ? artistView.background
                  : artistView.image
              : null;

          bool allowArtwork = artistView != null &&
              isNotNullOrEmpty(artistArtworkUrl) &&
              TakeoutState.allowArtistArtwork(connectivity);

          final artworkImage =
              allowArtwork && useBackground && artistArtworkUrl != null
                  ? artistBackground(artistArtworkUrl)
                  : allowArtwork && artistArtworkUrl != null
                      ? artistImage(artistArtworkUrl)
                      : _albumArtwork();

          // artist backgrounds are 1920x1080, expand keeping aspect ratio
          // artist images are 1000x1000
          // artist banners are 1000x185
          final screen = MediaQuery.of(context).size;
          final expandedHeight =
              useBackground ? 1080.0 / 1920.0 * screen.width : screen.width;

          return FutureBuilder<Color?>(
              future: allowArtwork && artistArtworkUrl != null
                  ? getImageBackgroundColor(artistArtworkUrl)
                  : Future.value(),
              builder: (context, snapshot) => Scaffold(
                  backgroundColor: snapshot.data,
                  body: RefreshIndicator(
                      onRefresh: () => onRefresh(),
                      child: view == null
                          ? Center(child: CircularProgressIndicator())
                          : CustomScrollView(slivers: [
                              SliverAppBar(
                                  expandedHeight: expandedHeight,
                                  actions: actions(),
                                  flexibleSpace: FlexibleSpaceBar(
                                      stretchModes: [
                                        StretchMode.zoomBackground,
                                        StretchMode.fadeTitle
                                      ],
                                      background: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            artworkImage,
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
                                                child: leftButton()),
                                            Align(
                                                alignment:
                                                    Alignment.bottomRight,
                                                child: rightButton()),
                                          ]))),
                              SliverToBoxAdapter(
                                  child: Container(
                                      padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
                                      child: Column(children: [
                                        if (artistView != null)
                                          Text(artistView.artist.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headline5)
                                      ]))),
                              ...slivers(),
                            ]))));
        });
  }
}
