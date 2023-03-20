// Copyright (C) 2023 The Takeout Authors.
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:takeout_app/api/model.dart';
import 'package:takeout_app/app/context.dart';
import 'package:takeout_app/art/artwork.dart';
import 'package:takeout_app/art/builder.dart';
import 'package:takeout_app/art/cover.dart';
import 'package:takeout_app/cache/track.dart';
import 'package:takeout_app/client/resolver.dart';
import 'package:takeout_app/page/page.dart';
import 'package:takeout_app/settings/repository.dart';
import 'package:takeout_app/tokens/repository.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock/wakelock.dart';

import 'buttons.dart';
import 'model.dart';
import 'nav.dart';
import 'style.dart';
import 'util.dart';

class MovieWidget extends ClientPage<MovieView> {
  final Movie _movie;

  MovieWidget(this._movie);

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.movie(_movie.id, ttl: ttl);
  }

  @override
  Widget page(BuildContext context, MovieView view) {
    return FutureBuilder<Color?>(
        future: getImageBackgroundColor(context, _movie.image),
        builder: (context, snapshot) {
          final backgroundColor = snapshot.data;
          final screen = MediaQuery.of(context).size;
          final expandedHeight = screen.height / 2;
          return Scaffold(
              backgroundColor: backgroundColor,
              body: RefreshIndicator(
                  onRefresh: () => reloadPage(context),
                  child: BlocBuilder<TrackCacheCubit, TrackCacheState>(
                      builder: (context, state) {
                    final isCached = state.contains(_movie);
                    return CustomScrollView(slivers: [
                      SliverAppBar(
                        // actions: [ ],
                        foregroundColor: overlayIconColor(context),
                        backgroundColor: Colors.black,
                        expandedHeight: expandedHeight,
                        flexibleSpace: FlexibleSpaceBar(
                            // centerTitle: true,
                            // title: Text(release.name, style: TextStyle(fontSize: 15)),
                            stretchModes: [
                              StretchMode.zoomBackground,
                              StretchMode.fadeTitle
                            ],
                            background: Stack(fit: StackFit.expand, children: [
                              releaseSmallCover(context, _movie.image),
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
                                  child: _playButton(context, view, isCached)),
                              Align(
                                  alignment: Alignment.bottomCenter,
                                  child: _progress(context)),
                              Align(
                                  alignment: Alignment.bottomRight,
                                  child: _downloadButton(context, isCached)),
                            ])),
                      ),
                      SliverToBoxAdapter(
                          child: Container(
                              padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
                              child: Column(children: [
                                _title(context),
                                _tagline(context),
                                _details(context),
                                if (view.hasGenres()) _genres(context, view),
                                // GestureDetector(
                                //     onTap: () => _onArtist(), child: _title()),
                                // GestureDetector(
                                //     onTap: () => _onArtist(), child: _artist()),
                              ]))),
                      if (view.hasCast())
                        SliverToBoxAdapter(
                            child: heading(
                                context.strings.castLabel)),
                      if (view.hasCast())
                        SliverToBoxAdapter(child: _CastListWidget(view)),
                      if (view.hasCrew())
                        SliverToBoxAdapter(
                            child: heading(
                                context.strings.crewLabel)),
                      if (view.hasCrew())
                        SliverToBoxAdapter(child: _CrewListWidget(view)),
                      if (view.hasRelated())
                        SliverToBoxAdapter(
                          child: heading(
                              context.strings.relatedLabel),
                        ),
                      if (view.hasRelated()) MovieGridWidget(view.other!),
                    ]);
                  })));
        });
  }

  Widget _progress(BuildContext context) {
    final value = context.offsets.state.value(_movie);
    return value != null
        ? LinearProgressIndicator(value: value)
        : SizedBox.shrink();
  }

  Widget _title(BuildContext context) {
    return Container(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: Text(_movie.title,
            style: Theme.of(context).textTheme.headlineSmall));
  }

  Widget _rating(BuildContext context) {
    final boxColor = Theme.of(context).textTheme.bodyLarge?.color ??
        Theme.of(context).colorScheme.outline;
    return Container(
      margin: const EdgeInsets.all(15.0),
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(border: Border.all(color: boxColor)),
      child: Text(_movie.rating),
    );
  }

  Widget _details(BuildContext context) {
    var list = <Widget>[];
    if (_movie.rating.isNotEmpty) {
      list.add(_rating(context));
    }

    final fields = <String>[];

    // runtime
    if (_movie.runtime > 0) {
      var hours = (_movie.runtime / 60).floor();
      var min = (_movie.runtime % 60).floor();
      fields.add('${hours}h ${min}m');
    }

    // year
    if (_movie.year > 1) {
      fields.add(_movie.year.toString());
    }

    // vote%
    int vote = (10 * (_movie.voteAverage ?? 0)).round();
    if (vote > 0) {
      fields.add('${vote}%');
    }

    // storage
    fields.add(storage(_movie.size));

    list.add(
        Text(merge(fields), style: Theme.of(context).textTheme.titleSmall));

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: list);
  }

  Widget _tagline(BuildContext context) {
    return Container(
        padding: EdgeInsets.fromLTRB(5, 5, 5, 5),
        child: Text(_movie.tagline,
            style: Theme.of(context).textTheme.titleMedium!));
  }

  Widget _genres(BuildContext context, MovieView view) {
    return Center(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      ...view.genres!.map((g) =>
          OutlinedButton(onPressed: () => _onGenre(context, g), child: Text(g)))
    ]));
  }

  Widget _playButton(BuildContext context, MovieView view, bool isCached) {
    final offsetCache = context.offsets;
    final pos = offsetCache.state.position(_movie) ?? Duration.zero;
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(Icons.play_arrow, size: 32),
            onPressed: () => _onPlay(context, view, pos))
        : StreamingButton(onPressed: () => _onPlay(context, view, pos));
  }

  Widget _downloadButton(BuildContext context, bool isCached) {
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(IconsDownloadDone),
            onPressed: () => {})
        : DownloadButton(onPressed: () => _onDownload(context));
  }

  void _onPlay(BuildContext context, MovieView view, Duration startOffset) {
    showMovie(context, view, startOffset: startOffset);
  }

  void _onDownload(BuildContext context) {
    // Downloads.downloadMovie(context, _movie);
  }

  void _onGenre(BuildContext context, String genre) {
    push(context, builder: (_) => GenreWidget(genre));
  }
}

class _CastListWidget extends StatelessWidget {
  final MovieView _view;

  const _CastListWidget(this._view);

  @override
  Widget build(BuildContext context) {
    final cast = _view.cast ?? [];
    return Column(children: [
      ...cast.map((c) => ListTile(
          onTap: () => _onCast(context, c),
          title: Text(c.person.name),
          subtitle: Text(c.character)))
    ]);
  }

  void _onCast(BuildContext context, Cast cast) {
    push(context, builder: (_) => ProfileWidget(cast.person));
  }
}

class _CrewListWidget extends StatelessWidget {
  final MovieView _view;

  const _CrewListWidget(this._view);

  @override
  Widget build(BuildContext context) {
    final crew = _view.crew ?? [];
    return Column(children: [
      ...crew.map((c) => ListTile(
          onTap: () => _onCrew(context, c),
          title: Text(c.person.name),
          subtitle: Text(c.job)))
    ]);
  }

  void _onCrew(BuildContext context, Crew crew) {
    push(context, builder: (_) => ProfileWidget(crew.person));
  }
}

class ProfileWidget extends ClientPage<ProfileView> {
  final Person _person;

  ProfileWidget(this._person);

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.profile(_person.id, ttl: ttl);
  }

  @override
  Widget page(BuildContext context, ProfileView view) {
    return FutureBuilder<Color?>(
        future: getImageBackgroundColor(context, _person.image),
        builder: (context, snapshot) {
          final backgroundColor = snapshot.data;
          final screen = MediaQuery.of(context).size;
          final expandedHeight = screen.height / 2;
          return Scaffold(
              backgroundColor: backgroundColor,
              body: RefreshIndicator(
                  onRefresh: () => reloadPage(context),
                  child: CustomScrollView(slivers: [
                    SliverAppBar(
                      // actions: [ ],
                      foregroundColor: overlayIconColor(context),
                      expandedHeight: expandedHeight,
                      flexibleSpace: FlexibleSpaceBar(
                          // centerTitle: true,
                          // title: Text(release.name, style: TextStyle(fontSize: 15)),
                          stretchModes: [
                            StretchMode.zoomBackground,
                            StretchMode.fadeTitle
                          ],
                          background: Stack(fit: StackFit.expand, children: [
                            releaseSmallCover(context, _person.image),
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
                          ])),
                    ),
                    SliverToBoxAdapter(
                        child: Container(
                            padding: EdgeInsets.fromLTRB(0, 16, 0, 4),
                            child: Column(children: [
                              _title(context),
                            ]))),
                    if (view.hasStarring())
                      SliverToBoxAdapter(
                          child: heading(
                              context.strings.starringLabel)),
                    if (view.hasStarring())
                      MovieGridWidget(view.starringMovies()),
                    if (view.hasDirecting())
                      SliverToBoxAdapter(
                          child: heading(
                              context.strings.directingLabel)),
                    if (view.hasDirecting())
                      MovieGridWidget(view.directingMovies()),
                    if (view.hasWriting())
                      SliverToBoxAdapter(
                        child:
                            heading(context.strings.writingLabel),
                      ),
                    if (view.hasWriting())
                      MovieGridWidget(view.writingMovies()),
                  ])));
        });
  }

  Widget _title(BuildContext context) {
    return Text(_person.name, style: Theme.of(context).textTheme.headlineSmall);
  }
}

class GenreWidget extends ClientPage<GenreView> {
  final String _genre;

  GenreWidget(this._genre);

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.moviesGenre(_genre, ttl: ttl);
  }

  @override
  Widget page(BuildContext context, GenreView view) {
    return Scaffold(
        body: RefreshIndicator(
            onRefresh: () => reloadPage(context),
            child: CustomScrollView(slivers: [
              SliverAppBar(title: Text(_genre)),
              if (view.movies.isNotEmpty)
                MovieGridWidget(_sortByTitle(view.movies)),
            ])));
  }
}

class MovieGridWidget extends StatelessWidget {
  final List<Movie> _movies;
  final bool subtitle;

  const MovieGridWidget(this._movies, {this.subtitle = true});

  @override
  Widget build(BuildContext context) {
    return SliverGrid.extent(
        maxCrossAxisExtent: posterGridWidth,
        childAspectRatio: posterAspectRatio,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
        children: [
          ..._movies.map((m) => Container(
              child: GestureDetector(
                  onTap: () => _onTap(context, m),
                  child: GridTile(
                    footer: Material(
                        color: Colors.transparent,
                        // shape: RoundedRectangleBorder(
                        //     borderRadius: BorderRadius.vertical(
                        //         bottom: Radius.circular(4))),
                        clipBehavior: Clip.antiAlias,
                        child: GridTileBar(
                          backgroundColor: Colors.black26,
                          // title: Text('${m.rating}'),
                          // trailing: Text('${m.year}'),
                        )),
                    child: gridPoster(context, m.image),
                  ))))
        ]);
  }

  void _onTap(BuildContext context, Movie movie) {
    push(context, builder: (_) => MovieWidget(movie));
  }
}

enum MovieState { buffering, playing, paused, none }

class MoviePlayer extends StatefulWidget {
  final MovieView _view;
  final Duration? startOffset;
  final MediaTrackResolver mediaTrackResolver;
  final SettingsRepository settingsRepository;
  final TokenRepository tokenRepository;

  MoviePlayer(this._view,
      {required this.mediaTrackResolver,
      required this.settingsRepository,
      required this.tokenRepository,
      this.startOffset = Duration.zero});

  @override
  _MoviePlayerState createState() => _MoviePlayerState();
}

// TODO add location back to movie to avoid this hassle?
class _MovieMediaTrack implements MediaTrack {
  MovieView view;

  _MovieMediaTrack(this.view);

  String get creator => '';

  String get album => '';

  String get image => view.movie.image;

  int get year => 0;

  String get title => view.movie.title;

  String get etag => view.movie.etag;

  int get size => view.movie.size;

  int get number => 0;

  int get disc => 0;

  String get date => view.movie.date;

  String get location => view.location;
}

class _MoviePlayerState extends State<MoviePlayer> {
  late final _stateStream = BehaviorSubject<MovieState>();
  late final _positionStream = BehaviorSubject<Duration>();
  VideoPlayerController? _controller;
  VideoProgressIndicator? _progress;
  StreamSubscription<MovieState>? _stateSubscription;
  var _showControls = false;
  var _videoInitialized = false;
  Timer? _controlsTimer = null;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    prepareController();
  }

  Future<void> prepareController() async {
    // controller
    final uri =
        await widget.mediaTrackResolver.resolve(_MovieMediaTrack(widget._view));
    String url = uri.toString();
    if (url.startsWith('/api/')) {
      url = '${widget.settingsRepository.settings?.endpoint}$url';
    }
    final headers = widget.tokenRepository.addMediaToken();
    final controller = VideoPlayerController.network(url, httpHeaders: headers)
      ..initialize().then((_) {
        setState(() {}); // see example
      });
    // progress
    _progress = VideoProgressIndicator(controller,
        colors: VideoProgressColors(
            playedColor: Colors.orangeAccent, bufferedColor: Colors.green),
        allowScrubbing: true,
        padding: EdgeInsets.all(32));
    // events
    controller.addListener(() {
      final value = controller.value;
      if (_videoInitialized == false && value.isInitialized) {
        _videoInitialized = true;
        if (widget.startOffset != null) {
          controller.seekTo(widget.startOffset!);
        }
        controller.play(); // autoplay
      }
      if (value.isPlaying) {
        _stateStream.add(MovieState.playing);
      } else if (value.isBuffering) {
        _stateStream.add(MovieState.buffering);
      } else if (value.isPlaying == false) {
        _stateStream.add(MovieState.paused);
      }
      _positionStream.add(value.position);
    });
    _stateSubscription = _stateStream.distinct().listen((state) {
      switch (state) {
        case MovieState.playing:
          Wakelock.enable();
          _controlsTimer?.cancel();
          _controlsTimer = Timer(Duration(seconds: 2), () {
            showControls(false);
          });
          break;
        default:
          Wakelock.disable();
          _controlsTimer?.cancel();
          showControls(true);
          break;
      }
    });

    setState(() {
      _controller = controller;
    });
  }

  void toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  void showControls(bool show) {
    setState(() {
      _showControls = show;
    });
  }

  String _pos(Duration pos) {
    return '${pos.hhmmss} ~ ${(_controller?.value.duration ?? Duration.zero).hhmmss}';
  }

  void _saveState(BuildContext context) {

    // Progress.update(_movie.key, _controller?.value.position ?? Duration.zero,
    //     _controller?.value.duration ?? Duration.zero);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
          onTap: () {
            if (_stateStream.value == MovieState.playing) {
              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
              toggleControls();
            }
          },
          child: _controller == null
              ? SizedBox.shrink()
              : Center(
                  child: _controller!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              VideoPlayer(_controller!),
                              if (_showControls) _progress!,
                              if (_showControls)
                                StreamBuilder<Duration>(
                                    stream: _positionStream,
                                    builder: (context, snapshot) {
                                      final duration = snapshot.data;
                                      return Align(
                                          alignment: Alignment.bottomLeft,
                                          child: Container(
                                              padding: EdgeInsets.all(3),
                                              child: Text(duration != null
                                                  ? _pos(duration)
                                                  : '')));
                                    }),
                              if (_showControls)
                                StreamBuilder<MovieState>(
                                    stream: _stateStream.distinct(),
                                    builder: (context, snapshot) {
                                      final state =
                                          snapshot.data ?? MovieState.none;
                                      return state == MovieState.none
                                          ? SizedBox.shrink()
                                          : Center(
                                              child: IconButton(
                                                  padding: EdgeInsets.all(0),
                                                  onPressed: () {
                                                    if (state ==
                                                        MovieState.playing) {
                                                      _controller!.pause();
                                                      _saveState(context);
                                                    } else {
                                                      _controller!.play();
                                                    }
                                                  },
                                                  icon: Icon(
                                                      state ==
                                                              MovieState.playing
                                                          ? Icons.pause
                                                          : Icons.play_arrow,
                                                      size: 64)));
                                    })
                            ],
                          ))
                      : SizedBox.shrink(),
                )),
    );
  }

  @override
  void dispose() {
    Wakelock.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    super.dispose();
    _controller?.dispose();
    _stateSubscription?.cancel();
  }
}

class MovieListWidget extends StatelessWidget {
  final List<Movie> _movies;

  const MovieListWidget(this._movies);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._movies.asMap().keys.toList().map((index) => ListTile(
          onTap: () => _onTapped(context, _movies[index]),
          leading: tilePoster(context, _movies[index].image),
          subtitle: Text(
              merge([_movies[index].year.toString(), _movies[index].rating])),
          title: Text(_movies[index].title)))
    ]);
  }

  void _onTapped(BuildContext context, Movie movie) {
    push(context, builder: (_) => MovieWidget(movie));
  }
}

void showMovie(BuildContext context, MovieView view, {Duration? startOffset}) {
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => MoviePlayer(view,
          settingsRepository: context.read<SettingsRepository>(),
          tokenRepository: context.read<TokenRepository>(),
          mediaTrackResolver: context.read<MediaTrackResolver>(),
          startOffset: startOffset)));
}

// Note this modifies the original list.
List<Movie> _sortByTitle(List<Movie> movies) {
  movies.sort((a, b) => a.sortTitle.compareTo(b.sortTitle));
  return movies;
}
