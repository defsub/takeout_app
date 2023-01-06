import 'dart:async';

import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:wakelock/wakelock.dart';

import 'client.dart';
import 'schema.dart';
import 'cover.dart';
import 'style.dart';
import 'main.dart';
import 'downloads.dart';
import 'cache.dart';
import 'progress.dart';
import 'util.dart';

class MovieWidget extends StatefulWidget {
  final Movie _movie;

  MovieWidget(this._movie);

  @override
  _MovieWidgetState createState() => _MovieWidgetState(_movie);
}

class _MovieWidgetState extends State<MovieWidget> {
  final Movie _movie;
  MovieView? _view;

  _MovieWidgetState(this._movie);

  @override
  void initState() {
    super.initState();
    final client = Client();
    client.movie(_movie.id).then((v) => _onMovieUpdated(v));
  }

  void _onMovieUpdated(MovieView view) {
    if (mounted) {
      setState(() {
        _view = view;
      });
    }
  }

  Future<void> _onRefresh() async {
    final client = Client();
    await client
        .movie(_movie.id, ttl: Duration.zero)
        .then((v) => _onMovieUpdated(v));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Color?>(
        future: getImageBackgroundColor(context, _movie.image),
        builder: (context, snapshot) {
          final backgroundColor = snapshot.data;
          final screen = MediaQuery.of(context).size;
          final expandedHeight = screen.height / 2;
          return Scaffold(
              backgroundColor: backgroundColor,
              body: RefreshIndicator(
                  onRefresh: () => _onRefresh(),
                  child: _view == null
                      ? Center(child: CircularProgressIndicator())
                      : StreamBuilder<CacheSnapshot>(
                          stream: MediaCache.stream(),
                          builder: (context, snapshot) {
                            final cacheSnapshot =
                                snapshot.data ?? CacheSnapshot.empty();
                            final isCached =
                                cacheSnapshot.containsAll([_view!]);
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
                                    background:
                                        Stack(fit: StackFit.expand, children: [
                                      releaseSmallCover(_movie.image),
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
                                          child: _playButton(context,
                                              cacheSnapshot, isCached)),
                                      Align(
                                          alignment: Alignment.bottomCenter,
                                          child: _progress(cacheSnapshot)),
                                      Align(
                                          alignment: Alignment.bottomRight,
                                          child: _downloadButton(
                                              context, isCached)),
                                    ])),
                              ),
                              SliverToBoxAdapter(
                                  child: Container(
                                      padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
                                      child: Column(children: [
                                        _title(),
                                        _tagline(),
                                        _details(context, cacheSnapshot),
                                        if (_view != null && _view!.hasGenres())
                                          _genres(),
                                        // GestureDetector(
                                        //     onTap: () => _onArtist(), child: _title()),
                                        // GestureDetector(
                                        //     onTap: () => _onArtist(), child: _artist()),
                                      ]))),
                              if (_view != null && _view!.hasCast())
                                SliverToBoxAdapter(
                                    child: heading(AppLocalizations.of(context)!
                                        .castLabel)),
                              if (_view != null && _view!.hasCast())
                                SliverToBoxAdapter(
                                    child: _CastListWidget(_view!)),
                              if (_view != null && _view!.hasCrew())
                                SliverToBoxAdapter(
                                    child: heading(AppLocalizations.of(context)!
                                        .crewLabel)),
                              if (_view != null && _view!.hasCrew())
                                SliverToBoxAdapter(
                                    child: _CrewListWidget(_view!)),
                              if (_view != null && _view!.hasRelated())
                                SliverToBoxAdapter(
                                  child: heading(AppLocalizations.of(context)!
                                      .relatedLabel),
                                ),
                              if (_view != null && _view!.hasRelated())
                                MovieGridWidget(_view!.other!),
                            ]);
                          })));
        });
  }

  Widget _progress(CacheSnapshot snapshot) {
    final value = snapshot.value(_view!);
    return value != null ? LinearProgressIndicator(value: value) : Container();
  }

  Widget _title() {
    return Container(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
        child:
            Text(_movie.title, style: Theme.of(context).textTheme.headline5));
  }

  Widget _rating(BuildContext context) {
    final boxColor = Theme.of(context).textTheme.bodyText1?.color ??
        Theme.of(context).colorScheme.outline;
    return Container(
      margin: const EdgeInsets.all(15.0),
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(border: Border.all(color: boxColor)),
      child: Text(_movie.rating),
    );
  }

  Widget _details(BuildContext context, CacheSnapshot snapshot) {
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

    list.add(Text(merge(fields), style: Theme.of(context).textTheme.subtitle2));

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: list);
  }

  Widget _tagline() {
    return Container(
        padding: EdgeInsets.fromLTRB(5, 5, 5, 5),
        child: Text(_movie.tagline,
            style: Theme.of(context).textTheme.subtitle1!));
  }

  Widget _genres() {
    return Center(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      ..._view!.genres!.map((g) =>
          OutlinedButton(onPressed: () => _onGenre(context, g), child: Text(g)))
    ]));
  }

  Widget _playButton(
      BuildContext context, CacheSnapshot snapshot, bool isCached) {
    final pos = snapshot.position(_view!) ?? Duration.zero;
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(Icons.play_arrow, size: 32),
            onPressed: () => _onPlay(pos))
        : allowStreamingIconButton(
            context, Icon(Icons.play_arrow, size: 32), () => _onPlay(pos));
  }

  Widget _downloadButton(BuildContext context, bool isCached) {
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(IconsDownloadDone),
            onPressed: () => {})
        : allowDownloadIconButton(
            context, Icon(IconsDownload), () => _onDownload(context));
  }

  void _onPlay(Duration startOffset) {
    showMovie(context, _view!, startOffset: startOffset);
  }

  void _onDownload(BuildContext context) {
    Downloads.downloadMovie(context, _movie);
  }

  void _onGenre(BuildContext context, String genre) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => GenreWidget(genre)));
  }
}

class _CastListWidget extends StatelessWidget {
  final MovieView _view;

  _CastListWidget(this._view);

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
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProfileWidget(cast.person)));
  }
}

class _CrewListWidget extends StatelessWidget {
  final MovieView _view;

  _CrewListWidget(this._view);

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
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProfileWidget(crew.person)));
  }
}

class ProfileWidget extends StatefulWidget {
  final Person _person;

  ProfileWidget(this._person);

  @override
  _ProfileWidgetState createState() => _ProfileWidgetState(_person);
}

class _ProfileWidgetState extends State<ProfileWidget> {
  final Person _person;
  ProfileView? _view;

  _ProfileWidgetState(this._person);

  @override
  void initState() {
    super.initState();
    final client = Client();
    client.profile(_person.id).then((v) => _onProfileUpdated(v));
  }

  void _onProfileUpdated(ProfileView view) {
    if (mounted) {
      setState(() {
        _view = view;
      });
    }
  }

  Future<void> _onRefresh() async {
    final client = Client();
    await client
        .profile(_person.id, ttl: Duration.zero)
        .then((v) => _onProfileUpdated(v));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Color?>(
        future: getImageBackgroundColor(context, _person.image),
        builder: (context, snapshot) {
          final backgroundColor = snapshot.data;
          final screen = MediaQuery.of(context).size;
          final expandedHeight = screen.height / 2;
          return Scaffold(
              backgroundColor: backgroundColor,
              body: RefreshIndicator(
                  onRefresh: () => _onRefresh(),
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
                            releaseSmallCover(_person.image),
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
                              _title(),
                            ]))),
                    if (_view != null && _view!.hasStarring())
                      SliverToBoxAdapter(
                          child: heading(
                              AppLocalizations.of(context)!.starringLabel)),
                    if (_view != null && _view!.hasStarring())
                      MovieGridWidget(_view!.starringMovies()),
                    if (_view != null && _view!.hasDirecting())
                      SliverToBoxAdapter(
                          child: heading(
                              AppLocalizations.of(context)!.directingLabel)),
                    if (_view != null && _view!.hasDirecting())
                      MovieGridWidget(_view!.directingMovies()),
                    if (_view != null && _view!.hasWriting())
                      SliverToBoxAdapter(
                        child:
                            heading(AppLocalizations.of(context)!.writingLabel),
                      ),
                    if (_view != null && _view!.hasWriting())
                      MovieGridWidget(_view!.writingMovies()),
                  ])));
        });
  }

  Widget _title() {
    return Text(_person.name, style: Theme.of(context).textTheme.headline5);
  }
}

class GenreWidget extends StatefulWidget {
  final String _genre;

  GenreWidget(this._genre);

  @override
  _GenreWidgetState createState() => _GenreWidgetState(_genre);
}

class _GenreWidgetState extends State<GenreWidget> {
  final String _genre;
  GenreView? _view;

  _GenreWidgetState(this._genre);

  @override
  void initState() {
    super.initState();
    final client = Client();
    client.moviesGenre(_genre).then((v) => _onViewUpdated(v));
  }

  void _onViewUpdated(GenreView view) {
    if (mounted) {
      setState(() {
        _view = view;
      });
    }
  }

  Future<void> _onRefresh() async {
    final client = Client();
    await client
        .moviesGenre(_genre, ttl: Duration.zero)
        .then((v) => _onViewUpdated(v));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: RefreshIndicator(
            onRefresh: () => _onRefresh(),
            child: CustomScrollView(slivers: [
              SliverAppBar(title: Text(_genre)),
              if (_view != null && _view!.movies.isNotEmpty)
                MovieGridWidget(_sortByTitle(_view!.movies)),
            ])));
  }
}

class MovieGridWidget extends StatelessWidget {
  final List<Movie> _movies;
  final bool subtitle;

  MovieGridWidget(this._movies, {this.subtitle = true});

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
                    child: gridPoster(m.image),
                  ))))
        ]);
  }

  void _onTap(BuildContext context, Movie movie) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return MovieWidget(movie);
    }));
  }
}

enum MovieState { buffering, playing, paused, none }

class MoviePlayer extends StatefulWidget {
  final Locatable _movie;
  final Duration? startOffset;

  MoviePlayer(this._movie, {this.startOffset = Duration.zero});

  @override
  _MoviePlayerState createState() =>
      _MoviePlayerState(_movie, startOffset ?? Duration.zero);
}

class _MoviePlayerState extends State<MoviePlayer> {
  late final _stateStream = BehaviorSubject<MovieState>();
  late final _positionStream = BehaviorSubject<Duration>();
  late final VideoPlayerController? _controller;
  late final VideoProgressIndicator? _progress;
  late final StreamSubscription<MovieState> _stateSubscription;
  final Locatable _movie;
  final Duration _startOffset;
  var _showControls = false;
  var _videoInitialized = false;
  Timer? _controlsTimer = null;

  _MoviePlayerState(this._movie, this._startOffset);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    prepareController();
  }

  void prepareController() async {
    // controller
    final client = Client();
    final uri = await client.locate(_movie);
    final headers = await client.headersWithMediaToken();
    final controller =
        VideoPlayerController.network(uri.toString(), httpHeaders: headers)
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
        controller.seekTo(_startOffset);
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

  void _saveState() {
    Progress.update(_movie.key, _controller?.value.position ?? Duration.zero,
        _controller?.value.duration ?? Duration.zero);
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
              ? Container()
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
                                          ? Container()
                                          : Center(
                                              child: IconButton(
                                                  padding: EdgeInsets.all(0),
                                                  onPressed: () {
                                                    if (state ==
                                                        MovieState.playing) {
                                                      _controller!.pause();
                                                      _saveState();
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
                      : Container(),
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
    _stateSubscription.cancel();
  }
}

class MovieListWidget extends StatelessWidget {
  final List<Movie> _movies;

  MovieListWidget(this._movies);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._movies.asMap().keys.toList().map((index) => ListTile(
          onTap: () => _onTapped(context, _movies[index]),
          leading: tilePoster(_movies[index].image),
          subtitle: Text(
              merge([_movies[index].year.toString(), _movies[index].rating])),
          title: Text(_movies[index].title)))
    ]);
  }

  void _onTapped(BuildContext context, Movie movie) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => MovieWidget(movie)));
  }
}

void showMovie(BuildContext context, Locatable movie, {Duration? startOffset}) {
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      builder: (_) => MoviePlayer(movie, startOffset: startOffset)));
}

// Note this modifies the original list.
List<Movie> _sortByTitle(List<Movie> movies) {
  movies.sort((a, b) => a.sortTitle.compareTo(b.sortTitle));
  return movies;
}
