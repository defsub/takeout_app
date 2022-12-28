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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recase/recase.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logging/logging.dart';

import 'client.dart';
import 'cover.dart';
import 'downloads.dart';
import 'main.dart';
import 'schema.dart';
import 'playlist.dart';
import 'release.dart';
import 'style.dart';
import 'spiff.dart';
import 'widget.dart';
import 'menu.dart';
import 'util.dart';
import 'global.dart';
import 'cache.dart';

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
  static final log = Logger('ArtistsState');

  ArtistsView _view;
  String? genre;
  String? area;

  _ArtistsState(this._view, {this.genre, this.area});


  @override
  void dispose() {
    super.dispose();
    print('dispose artists');
  }

  @override
  Widget build(BuildContext context) {
    print('build artists');
    final artistsText = AppLocalizations.of(context)!.artistsLabel;
    final builder = (BuildContext) => Scaffold(
        appBar: AppBar(
            title: genre != null
                ? header('$artistsText \u2013 $genre')
                : area != null
                    ? header('$artistsText \u2013 $area')
                    : header(artistsText),
            actions: [
              popupMenu(context, [
                PopupItem.refresh(context, (_) => _onRefresh()),
              ])
            ]),
        body: RefreshIndicator(
            onRefresh: () => _onRefresh(),
            child: ArtistListWidget(genre != null
                ? _view.artists.where((a) => a.genre == genre).toList()
                : area != null
                    ? _view.artists.where((a) => a.area == area).toList()
                    : _view.artists)));
    return Navigator(
        key: artistsKey,
        initialRoute: '/',
        observers: [heroController()],
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute(builder: builder, settings: settings);
        });
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
      log.warning(error);
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
  return merge([genre, y]);
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
  static final log = Logger('ArtistState');

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
            builder: (context) => SpiffWidget(
                fetch: () =>
                    Client().artistRadio(_artist.id, ttl: Duration.zero))));
  }

  void _onShuffle() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => SpiffWidget(
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
      log.warning(error);
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
      log.warning(error);
    }
  }

  ArtistView? get view => _view;

  Future<void> onRefresh() => _onRefresh();

  List<Widget> actions() {
    final artistUrl = 'https://musicbrainz.org/artist/${_artist.arid}';
    final genre = ReCase(_artist.genre ?? '').titleCase;
    return <Widget>[
      popupMenu(context, [
        PopupItem.shuffle(context, (_) => _onShuffle()),
        PopupItem.radio(context, (_) => _onRadio()),
        PopupItem.divider(),
        PopupItem.singles(context, (_) => _onSingles(context)),
        PopupItem.popular(context, (_) => _onPopular(context)),
        PopupItem.divider(),
        if (_artist.genre != null)
          PopupItem.genre(
              context, genre, (_) => _onGenre(context, _artist.genre!)),
        if (_artist.area != null)
          PopupItem.area(
              context, _artist.area!, (_) => _onArea(context, _artist.area!)),
        PopupItem.divider(),
        PopupItem.link(context, 'MusicBrainz Artist',
            (_) => launchUrl(Uri.parse(artistUrl))),
        PopupItem.divider(),
        PopupItem.refresh(context, (_) => _onRefresh()),
      ])
    ];
  }

  Widget leftButton(BuildContext context) {
    return IconButton(
        color: overlayIconColor(context),
        icon: Icon(Icons.shuffle_sharp),
        onPressed: _onShuffle);
  }

  Widget rightButton(BuildContext context) {
    return IconButton(
        color: overlayIconColor(context),
        icon: Icon(Icons.radio),
        onPressed: _onRadio);
  }

  List<Widget> slivers(CacheSnapshot snapshot) {
    if (_view == null) {
      return [];
    }
    return [
      SliverToBoxAdapter(
          child: heading(AppLocalizations.of(context)!.releasesLabel)),
      AlbumGridWidget(
        _view!.releases,
        subtitle: false,
      ),
      if (_view!.similar.isNotEmpty)
        SliverToBoxAdapter(
            child: heading(AppLocalizations.of(context)!.similarArtists)),
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
  final List<MediaLocatable> _tracks;

  TrackListWidget(this._tracks);

  void _onPlay(int index) {
    MediaQueue.playTracks(_tracks, index: index);
    showPlayer();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._tracks.asMap().keys.toList().map((index) =>
          CoverTrackListTile.mediaTrack(_tracks[index],
              onTap: () => _onPlay(index), trailing: Icon(Icons.play_arrow)))
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

  void _onDownload(BuildContext context) async {
    Future<Spiff> result = _playlist();
    result.then((spiff) => Downloads.downloadSpiff(context, spiff));
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
            PopupItem.popular(
                context, (_) => _onChangeType(ArtistTrackType.popular)),
          if (_type == ArtistTrackType.popular)
            PopupItem.singles(
                context, (_) => _onChangeType(ArtistTrackType.singles)),
          PopupItem.refresh(context, (_) => _onRefresh()),
        ])
      ];

  Widget leftButton(BuildContext context) {
    return IconButton(
        color: overlayIconColor(context),
        icon: Icon(Icons.play_arrow, size: 32),
        onPressed: _onPlay);
  }

  Widget rightButton(BuildContext context) {
    return IconButton(
        color: overlayIconColor(context),
        icon: Icon(IconsDownload),
        onPressed: () => _onDownload(context));
  }

  List<Widget> slivers(CacheSnapshot snapshot) {
    return [
      SliverToBoxAdapter(
          child: heading(_type == ArtistTrackType.singles
              ? AppLocalizations.of(context)!.singlesLabel
              : AppLocalizations.of(context)!.popularLabel)),
      SliverToBoxAdapter(child: Column(children: _trackList(snapshot))),
    ];
  }

  List<CoverTrackListTile> _trackList(CacheSnapshot snapshot) {
    final list = <CoverTrackListTile>[];
    int index = 0;
    _tracks.forEach((t) {
      list.add(CoverTrackListTile.mediaTrack(t,
          onTap: () => _onTrack(index), trailing: _trailing(snapshot, t)));
      index++;
    });
    return list;
  }

  Widget _trailing(CacheSnapshot snapshot, Locatable locatable) {
    final downloading = snapshot.downloadSnapshot(locatable);
    if (downloading != null) {
      final value = downloading.value;
      return value > 1.0
          ? CircularProgressIndicator()
          : CircularProgressIndicator(value: value);
    }
    return Icon(snapshot.contains(locatable) ? IconsCached : null);
  }
}

mixin ArtistBuilder {
  ArtistView? get view;

  Future<void> onRefresh();

  List<Widget> actions();

  Widget leftButton(BuildContext context);

  Widget rightButton(BuildContext context);

  List<Widget> slivers(CacheSnapshot snapshot);

  static Random _random = Random();

  String? _randomCover() {
    final artistView = view;
    if (artistView == null) {
      return null;
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
    return null;
  }

  Widget build(BuildContext context) {
    return StreamBuilder<ConnectivityResult>(
        stream: TakeoutState.connectivityStream.distinct(),
        builder: (context, snapshot) {
          final connectivity = snapshot.data;
          final artistView = view;
          final artwork = ArtworkBuilder.artist(
              TakeoutState.allowArtistArtwork(connectivity)
                  ? view?.image ?? null
                  : null,
              _randomCover());
          final artistImage = artwork.build();

          // artist backgrounds are 1920x1080, expand keeping aspect ratio
          // artist images are 1000x1000
          // artist banners are 1000x185
          // final screen = MediaQuery.of(context).size;
          // final expandedHeight = useBackground
          //     ? 1080.0 / 1920.0 * screen.width
          //     : screen.height / 2;

          final screen = MediaQuery.of(context).size;
          final expandedHeight = screen.height / 2;

          return StreamBuilder<String?>(
              stream: artwork.urlStream.stream.distinct(),
              builder: (context, snapshot) {
                final url = snapshot.data;
                return FutureBuilder<Color?>(
                    future: url != null
                        ? artwork.getBackgroundColor(context)
                        : Future.value(),
                    builder: (context, snapshot) => Scaffold(
                        backgroundColor: snapshot.data,
                        body: RefreshIndicator(
                            onRefresh: () => onRefresh(),
                            child: view == null
                                ? Center(child: CircularProgressIndicator())
                                : StreamBuilder<CacheSnapshot>(
                                    stream: MediaCache.stream(),
                                    builder: (context, snapshot) {
                                      final cacheSnapshot = snapshot.data ??
                                          CacheSnapshot.empty();
                                      return CustomScrollView(slivers: [
                                        SliverAppBar(
                                            foregroundColor:
                                                overlayIconColor(context),
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
                                                      artistImage,
                                                      const DecoratedBox(
                                                        decoration:
                                                            BoxDecoration(
                                                          gradient:
                                                              LinearGradient(
                                                            begin: Alignment(
                                                                0.0, 0.75),
                                                            end: Alignment(
                                                                0.0, 0.0),
                                                            colors: <Color>[
                                                              Color(0x60000000),
                                                              Color(0x00000000),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Align(
                                                          alignment: Alignment
                                                              .bottomLeft,
                                                          child: leftButton(
                                                              context)),
                                                      Align(
                                                          alignment: Alignment
                                                              .bottomRight,
                                                          child: rightButton(
                                                              context)),
                                                    ]))),
                                        SliverToBoxAdapter(
                                            child: Container(
                                                padding: EdgeInsets.fromLTRB(
                                                    0, 16, 0, 0),
                                                child: Column(children: [
                                                  if (artistView != null)
                                                    Text(artistView.artist.name,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .headline5)
                                                ]))),
                                        ...slivers(cacheSnapshot)
                                      ]);
                                    }))));
              });
        });
  }
}
