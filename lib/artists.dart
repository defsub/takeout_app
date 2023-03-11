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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:recase/recase.dart';
import 'package:takeout_app/cache/track.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:takeout_app/api/model.dart';
import 'package:takeout_app/app/context.dart';
import 'package:takeout_app/art/builder.dart';
import 'package:takeout_app/client/download.dart';
import 'package:takeout_app/page/page.dart';
import 'package:takeout_app/connectivity/connectivity.dart';

import 'release.dart';
import 'style.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/spiff/widget.dart';
import 'menu.dart';
import 'util.dart';
import 'global.dart';
import 'tiles.dart';
import 'model.dart';

class ArtistsWidget extends NavigatorClientPage<ArtistsView> {
  final String? genre;
  final String? area;

  ArtistsWidget({this.genre, this.area}) : super(artistsKey);

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.artists(ttl: ttl);
  }

  @override
  Widget page(BuildContext context, ArtistsView view) {
    return Scaffold(
        appBar: AppBar(title: _title(context), actions: [
          popupMenu(context, [
            PopupItem.refresh(context, (_) => refreshPage(context)),
          ])
        ]),
        body: RefreshIndicator(
            onRefresh: () => refreshPage(context),
            child: ArtistListWidget(_artists(view))));
  }

  Widget _title(BuildContext context) {
    final artistsText = AppLocalizations.of(context)!.artistsLabel;
    return genre != null
        ? header('$artistsText \u2013 ${genre}')
        : area != null
            ? header('$artistsText \u2013 ${area}')
            : header(artistsText);
  }

  List<Artist> _artists(ArtistsView view) {
    return genre != null
        ? view.artists.where((a) => a.genre == genre).toList()
        : area != null
            ? view.artists.where((a) => a.area == area).toList()
            : view.artists;
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

  const ArtistListWidget(this._artists);

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
        context, MaterialPageRoute(builder: (_) => ArtistWidget(artist)));
  }
}

class ArtistWidget extends ClientPage<ArtistView> with ArtistPage {
  final Artist _artist;

  ArtistWidget(this._artist);

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.artist(_artist.id, ttl: ttl);
  }

  @override
  Widget page(BuildContext context, ArtistView view) {
    return artistPage(context, view);
  }

  void _onRadio(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SpiffWidget(
                fetch: (client, {Duration? ttl}) =>
                    client.artistRadio(_artist.id, ttl: Duration.zero))));
  }

  void _onShuffle(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SpiffWidget(
                fetch: (client, {Duration? ttl}) =>
                    client.artistPlaylist(_artist.id, ttl: Duration.zero))));
  }

  void _onSingles(BuildContext context, ArtistView view) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                ArtistTrackListWidget(view, _artist, ArtistTrackType.singles)));
  }

  void _onPopular(BuildContext context, ArtistView view) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                ArtistTrackListWidget(view, _artist, ArtistTrackType.popular)));
  }

  void _onGenre(BuildContext context, String genre) async {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ArtistsWidget(genre: genre)));
  }

  void _onArea(BuildContext context, String area) async {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => ArtistsWidget(area: area)));
  }

  List<Widget> actions(BuildContext context, ArtistView view) {
    final artistUrl = 'https://musicbrainz.org/artist/${_artist.arid}';
    final genre = ReCase(_artist.genre ?? '').titleCase;
    return <Widget>[
      popupMenu(context, [
        PopupItem.shuffle(context, (_) => _onShuffle(context)),
        PopupItem.radio(context, (_) => _onRadio(context)),
        PopupItem.divider(),
        PopupItem.singles(context, (_) => _onSingles(context, view)),
        PopupItem.popular(context, (_) => _onPopular(context, view)),
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
        PopupItem.refresh(context, (_) => refreshPage(context)),
      ])
    ];
  }

  Widget leftButton(BuildContext context) {
    return IconButton(
        color: overlayIconColor(context),
        icon: Icon(Icons.shuffle_sharp),
        onPressed: () => _onShuffle(context));
  }

  Widget rightButton(BuildContext context) {
    return IconButton(
        color: overlayIconColor(context),
        icon: Icon(Icons.radio),
        onPressed: () => _onRadio(context));
  }

  List<Widget> slivers(BuildContext context, ArtistView view) {
    return [
      SliverToBoxAdapter(
          child: heading(AppLocalizations.of(context)!.releasesLabel)),
      AlbumGridWidget(
        view.releases,
        subtitle: false,
      ),
      if (view.similar.isNotEmpty)
        SliverToBoxAdapter(
            child: heading(AppLocalizations.of(context)!.similarArtists)),
      if (view.similar.isNotEmpty)
        SliverToBoxAdapter(child: SimilarArtistListWidget(view))
    ];
  }
}

class SimilarArtistListWidget extends StatelessWidget {
  final ArtistView _view;

  const SimilarArtistListWidget(this._view);

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
        context, MaterialPageRoute(builder: (_) => ArtistWidget(artist)));
  }
}

class TrackListWidget extends StatelessWidget {
  final List<MediaTrack> _tracks;

  const TrackListWidget(this._tracks);

  void _onPlay(BuildContext context, int index) {
    // MediaQueue.playTracks(context, _tracks, index: index);
    // showPlayer();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._tracks.asMap().keys.toList().map((index) =>
          CoverTrackListTile.mediaTrack(context, _tracks[index],
              onTap: () => _onPlay(context, index),
              trailing: Icon(Icons.play_arrow)))
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
  State<StatefulWidget> createState() => _ArtistTrackListState(_type);
}

class _ArtistTrackListState extends State<ArtistTrackListWidget>
    with ClientPageBuilder<ArtistTracksView>, ArtistPage {
  ArtistTrackType _type;

  _ArtistTrackListState(this._type);

  @override
  Widget page(BuildContext context, ArtistTracksView view) {
    return artistPage(context, widget._view);
  }

  @override
  void load(BuildContext context, {Duration? ttl}) {
    if (_type == ArtistTrackType.popular) {
      context.client.artistPopular(widget._artist.id, ttl: ttl);
    } else if (_type == ArtistTrackType.singles) {
      context.client.artistSingles(widget._artist.id, ttl: ttl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return builder(context)(context);
  }

  void _onChangeType(ArtistTrackType type) {
    _type = type;
    load(context);
  }

  Future<Spiff> _playlist() {
    final client = context.clientRepository;
    Future<Spiff> result = _type == ArtistTrackType.popular
        ? client.artistPopularPlaylist(widget._artist.id, ttl: Duration.zero)
        : _type == ArtistTrackType.singles
            ? client.artistSinglesPlaylist(widget._artist.id,
                ttl: Duration.zero)
            : client.artistSinglesPlaylist(widget._artist.id,
                ttl: Duration.zero);
    return result;
  }

  void _onPlay(BuildContext context) async {
    // Future<Spiff> result = _playlist();
    // result.then((spiff) => MediaQueue.playSpiff(context, spiff));
  }

  void _onDownload(BuildContext context) async {
    Future<Spiff> result = _playlist();
    context.download(await result);
    // result.then((spiff) => Downloads.downloadSpiff(context, spiff));
  }

  void _onTrack(BuildContext context, int index) async {
    Future<Spiff> result = _playlist();
    final spiff = await result;
    context.play(spiff.copyWith(index: index));
  }

  List<Widget> actions(BuildContext context, ArtistView view) => [
        popupMenu(context, [
          if (_type == ArtistTrackType.singles)
            PopupItem.popular(
                context, (_) => _onChangeType(ArtistTrackType.popular)),
          if (_type == ArtistTrackType.popular)
            PopupItem.singles(
                context, (_) => _onChangeType(ArtistTrackType.singles)),
          PopupItem.refresh(context, (_) => refreshPage(context)),
        ])
      ];

  Widget leftButton(BuildContext context) {
    return IconButton(
        color: overlayIconColor(context),
        icon: Icon(Icons.play_arrow, size: 32),
        onPressed: () => _onPlay(context));
  }

  Widget rightButton(BuildContext context) {
    return IconButton(
        color: overlayIconColor(context),
        icon: Icon(IconsDownload),
        onPressed: () => _onDownload(context));
  }

  List<Widget> slivers(BuildContext context, ArtistView view) {
    return [
      SliverToBoxAdapter(
          child: heading(_type == ArtistTrackType.singles
              ? AppLocalizations.of(context)!.singlesLabel
              : AppLocalizations.of(context)!.popularLabel)),
      SliverToBoxAdapter(child: Column(children: _trackList(context))),
    ];
  }

  List<CoverTrackListTile> _trackList(BuildContext context) {
    final view = context.client.state as ArtistTracksView;
    final list = <CoverTrackListTile>[];
    int index = 0;
    view.tracks.forEach((t) {
      list.add(CoverTrackListTile.mediaTrack(context, t,
          onTap: () => _onTrack(context, index), trailing: _trailing(t)));
      index++;
    });
    return list;
  }

  Widget _trailing(Track track) {
    return Builder(builder: (context) {
      final download = context.watch<DownloadCubit>();
      final trackCache = context.watch<TrackCacheCubit>();
      final cached = trackCache.state.contains(track);
      if (download.state.contains(track)) {
        final value = download.state.progress(track)?.value ?? 0.0;
        return value > 1.0
            ? CircularProgressIndicator()
            : CircularProgressIndicator(value: value);
      }
      return Icon(cached ? IconsCached : null);
    });
  }
}

mixin ArtistPage {
  List<Widget> actions(BuildContext context, ArtistView view);

  Widget leftButton(BuildContext context);

  Widget rightButton(BuildContext context);

  List<Widget> slivers(BuildContext context, ArtistView view);

  static Random _random = Random();

  String? _randomCover(ArtistView view) {
    for (var i = 0; i < 3; i++) {
      final pick = _random.nextInt(view.releases.length);
      if (isNotNullOrEmpty(view.releases[pick].image)) {
        return view.releases[pick].image;
      }
    }
    try {
      return view.releases.firstWhere((r) => isNotNullOrEmpty(r.image)).image;
    } on StateError {
      return null;
    }
  }

  Widget artistPage(BuildContext context, ArtistView view) {
    // artist backgrounds are 1920x1080, expand keeping aspect ratio
    // artist images are 1000x1000
    // artist banners are 1000x185
    // final screen = MediaQuery.of(context).size;
    // final expandedHeight = useBackground
    //     ? 1080.0 / 1920.0 * screen.width
    //     : screen.height / 2;
    final screen = MediaQuery.of(context).size;
    final expandedHeight = screen.height / 2;

    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
        builder: (context, state) {
          final settings = context.settings.state;
          final allow = settings.allowMobileArtistArtwork;
          String? image;
          if (state.mobile ? allow : true) {
            image = view.image;
          }
          final artwork = ArtworkBuilder.artist(image, _randomCover(view));
          final artistImage = artwork.build(context);
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
                        body: CustomScrollView(slivers: [
                          SliverAppBar(
                              foregroundColor: overlayIconColor(context),
                              expandedHeight: expandedHeight,
                              actions: actions(context, view),
                              flexibleSpace: FlexibleSpaceBar(
                                  stretchModes: [
                                    StretchMode.zoomBackground,
                                    StretchMode.fadeTitle
                                  ],
                                  background:
                                      Stack(fit: StackFit.expand, children: [
                                    artistImage,
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
                                        child: leftButton(context)),
                                    Align(
                                        alignment: Alignment.bottomRight,
                                        child: rightButton(context)),
                                  ]))),
                          SliverToBoxAdapter(
                              child: Container(
                                  padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
                                  child: Column(children: [
                                    Text(view.artist.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall)
                                  ]))),
                          ...slivers(context, view)
                        ])));
              });
        });
  }
}
