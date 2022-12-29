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

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:takeout_app/history_widget.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:rxdart/rxdart.dart';
import 'package:logging/logging.dart';

import 'client.dart';
import 'downloads.dart';
import 'main.dart';
import 'schema.dart';
import 'release.dart';
import 'settings.dart';
import 'style.dart';
import 'cover.dart';
import 'cache.dart';
import 'podcasts.dart';
import 'progress.dart';
import 'global.dart';
import 'menu.dart';
import 'model.dart';
import 'video.dart';
import 'widget.dart';

class HomeWidget extends StatefulWidget {
  final IndexView _index;
  final HomeView _view;
  final VoidContextCallback _onSearch;

  HomeWidget(this._index, this._view, this._onSearch);

  @override
  HomeState createState() => HomeState(_index, _view, _onSearch);
}

class _GridState {
  final String setting;
  final CacheSnapshot cacheSnapshot;

  _GridState(this.setting, this.cacheSnapshot);
}

class HomeState extends State<HomeWidget> {
  static final log = Logger('HomeState');

  IndexView _index;
  HomeView _view;
  VoidContextCallback _onSearch;

  HomeState(this._index, this._view, this._onSearch);

  _HomeGrid _grid(
      MediaType mediaType, GridType gridType, CacheSnapshot cacheSnapshot) {
    switch (mediaType) {
      case MediaType.video:
        return _MovieHomeGrid(
            gridType, cacheSnapshot, _index, _view, _onSearch);
      case MediaType.music:
      case MediaType.stream: // unused for now
        return _MusicHomeGrid(
            gridType, cacheSnapshot, _index, _view, _onSearch);
      case MediaType.podcast:
        return _SeriesHomeGrid(
            gridType, cacheSnapshot, _index, _view, _onSearch);
    }
  }

  @override
  Widget build(BuildContext context) {
    final builder = (BuildContext) => StreamBuilder<_GridState>(
        stream: Rx.combineLatest2(
            settingsChangeSubject.stream,
            MediaCache.stream(),
            (String setting, CacheSnapshot cacheSnapshot) =>
                _GridState(setting, cacheSnapshot)),
        builder: (context, snapshot) {
          final gridState = snapshot.data;
          if (gridState != null) {
            final type = settingsGridType(settingHomeGridType, GridType.mix);
            final mediaType = settingsMediaType(type: MediaType.music);
            return Scaffold(
                body: RefreshIndicator(
              onRefresh: () => _onRefresh(),
              child: _grid(mediaType, type, gridState.cacheSnapshot),
            ));
          } else {
            return Container();
          }
        });

    return Navigator(
        key: homeKey,
        initialRoute: '/',
        observers: [heroController()],
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute(builder: builder, settings: settings);
        });
  }

  Future<void> _onRefresh() async {
    try {
      final client = Client();
      // refresh index & home for new media
      final index = await client.index(ttl: Duration.zero);
      final home = await client.home(ttl: Duration.zero);
      // also refresh progress for progress made elsewhere
      Progress.sync(client: client); // async
      if (mounted) {
        setState(() {
          _index = index;
          _view = home;
        });
      }
    } catch (error) {
      log.warning(error);
    }
  }
}

abstract class _HomeItem {
  Widget Function() get onTap;

  bool get overlay;

  Widget? get title;

  Widget? get subtitle;

  String get key;

  Widget getTrailing(BuildContext context);

  Widget get image;

  @override
  int get hashCode {
    return key.hashCode;
  }

  @override
  bool operator ==(Object o) {
    return o is _HomeItem && o.key == key;
  }
}

class _MediaHomeItem extends _HomeItem {
  MediaAlbum album;
  CacheSnapshot snapshot;
  String? _key;

  _MediaHomeItem(
    this.snapshot,
    this.album,
  );

  @override
  Widget Function() get onTap {
    return () => DownloadWidget(album as SpiffDownloadEntry);
  }

  @override
  bool get overlay => album.album.isNotEmpty || album.creator.isNotEmpty;

  @override
  Widget? get title => Text(album.album);

  @override
  Widget? get subtitle => album.creator.isNotEmpty ? Text(album.creator) : null;

  Widget _downloadIcon(BuildContext context, SpiffDownloadEntry download,
      IconData completeIcon, IconData downloadingIcon) {
    final isCached = snapshot.containsAll(download.spiff.playlist.tracks);
    return Icon(isCached ? completeIcon : downloadingIcon,
        color: overlayIconColor(context));
  }

  @override
  Widget getTrailing(BuildContext context) {
    var year = album.year;
    if (album is SpiffDownloadEntry) {
      return _downloadIcon(context, album as SpiffDownloadEntry,
          IconsDownloadDone, IconsDownload);
    } else if (year > 1) {
      return Text('$year');
    }
    return Container();
  }

  @override
  String get key {
    if (_key == null) {
      _key = "${album.album}/${album.creator ?? ''}";
    }
    return _key!;
  }

  @override
  Widget get image {
    return gridCover(album.image);
  }
}

class _ReleaseHomeItem extends _MediaHomeItem {
  _ReleaseHomeItem(CacheSnapshot snapshot, Release release)
      : super(snapshot, release);

  @override
  Widget Function() get onTap {
    return () => ReleaseWidget(album as Release);
  }
}

class _MovieHomeItem extends _MediaHomeItem {
  _MovieHomeItem(CacheSnapshot snapshot, Movie movie) : super(snapshot, movie);

  @override
  Widget Function() get onTap {
    return () => MovieWidget(album as Movie);
  }

  @override
  String get key => (album as Movie).titleYear;

  @override
  Widget? get title => null; //(album as Movie).rating;

  @override
  Widget? get subtitle => null;

  @override
  Widget getTrailing(BuildContext context) => Container();

  @override
  Widget get image {
    return gridPoster(album.image);
  }
}

class _SeriesHomeItem extends _MediaHomeItem {
  _SeriesHomeItem(CacheSnapshot snapshot, Series series)
      : super(snapshot, series);

  @override
  Widget Function() get onTap {
    return () => SeriesWidget(album as Series);
  }

  @override
  String get key => album.album + "/" + album.creator; // == title/author

  @override
  Widget? get title => null;

  @override
  Widget? get subtitle => RelativeDateWidget.from((album as Series).date);

  @override
  Widget getTrailing(BuildContext context) => Container();

  @override
  Widget get image {
    return gridPoster(album.image);
  }
}

abstract class _HomeGrid extends StatelessWidget {
  final GridType _type;
  final CacheSnapshot _cacheSnapshot;
  final IndexView _index;
  final HomeView _view;
  final VoidContextCallback _onSearch;
  final _buttons =
      SplayTreeMap<MediaType, IconButton>((a, b) => a.index.compareTo(b.index));

  _HomeGrid(
      this._type, this._cacheSnapshot, this._index, this._view, this._onSearch);

  Iterable<_HomeItem> _items(List<DownloadEntry> downloads);

  double _gridAspectRatio();

  double _gridMaxCrossAxisExtent();

  void _onTap(BuildContext context, _HomeItem item) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => item.onTap()));
  }

  List<_MediaHomeItem> _downloadedItems(
      MediaType mediaType, List<DownloadEntry> downloads) {
    List<_MediaHomeItem> items = [];
    downloads.forEach((d) {
      if (d is SpiffDownloadEntry && d.spiff.mediaType == mediaType) {
        items.add(_MediaHomeItem(_cacheSnapshot, d));
      }
    });
    return items;
  }

  SliverGrid _itemGrid(BuildContext context, Iterable<_HomeItem> items) {
    int dir = 0;
    return SliverGrid.extent(
        childAspectRatio: _gridAspectRatio(),
        maxCrossAxisExtent: _gridMaxCrossAxisExtent(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: [
          ...items.map((i) => Container(
              child: GestureDetector(
                  onTap: () => _onTap(context, i),
                  onPanUpdate: (d) {
                    dir = d.delta.dx < 0 ? -1 : 1;
                  },
                  onPanEnd: (_) {
                    if (dir == -1) {
                      nextGridType();
                    } else if (dir == 1) {
                      prevGridType();
                    }
                  },
                  child: GridTile(
                    footer: i.overlay
                        ? Material(
                            color: Colors.transparent,
                            // shape: RoundedRectangleBorder(
                            //     borderRadius: BorderRadius.vertical(
                            //         bottom: Radius.circular(4))),
                            clipBehavior: Clip.antiAlias,
                            child: GridTileBar(
                              backgroundColor: Colors.black26,
                              title: i.title,
                              subtitle: i.subtitle,
                              trailing: i.getTrailing(context),
                            ))
                        : null,
                    child: i.image,
                  ))))
        ]);
  }

  void _changeGridType(int Function(int i) change) {
    final mediaType = settingsMediaType(type: MediaType.music);
    final types = _buttons.keys.toList();
    for (int i = 0; i < types.length; i++) {
      if (types[i] == mediaType) {
        changeMediaType(types[change(i)]);
      }
    }
  }

  void nextGridType() =>
      _changeGridType((i) => i + 1 >= _buttons.length ? 0 : i + 1);

  void prevGridType() =>
      _changeGridType((i) => i - 1 < 0 ? _buttons.length - 1 : i - 1);

  @override
  Widget build(BuildContext context) {
    final mediaType = settingsMediaType(type: MediaType.music);
    final iconSize = 22.0;
    final selectedColor = Theme.of(context).indicatorColor;
    _buttons.clear();
    if (_index.hasMusic) {
      _buttons[MediaType.music] = IconButton(
          iconSize: iconSize,
          color: mediaType == MediaType.music ? selectedColor : null,
          icon: Icon(Icons.audiotrack),
          onPressed: () => _onMusicSelected(context));
    }
    if (_index.hasMovies) {
      _buttons[MediaType.video] = IconButton(
          iconSize: iconSize,
          color: mediaType == MediaType.video ? selectedColor : null,
          icon: Icon(Icons.movie),
          onPressed: () => _onVideoSelected(context));
    }
    if (_index.hasPodcasts) {
      _buttons[MediaType.podcast] = IconButton(
          iconSize: iconSize,
          color: mediaType == MediaType.podcast ? selectedColor : null,
          icon: Icon(Icons.podcasts),
          onPressed: () => _onPodcastsSelected(context));
    }

    final iconBar = <Widget>[];
    // below adds circular progress indicator status bar
    // if (_cacheSnapshot.downloading.isNotEmpty) {
    //   // add icon to show download progress
    //   final downloadProgress = _cacheSnapshot.downloading.values
    //       .fold<DownloadSnapshot>(
    //           DownloadSnapshot(0, 0),
    //           (total, e) => DownloadSnapshot(
    //               total.size + e.size, total.offset + e.offset));
    //   iconBar.add(Center(
    //       child: SizedBox(
    //           width: iconSize,
    //           height: iconSize,
    //           child:
    //               CircularProgressIndicator(value: downloadProgress.value))));
    // }
    iconBar.addAll(_buttons.values);

    return CustomScrollView(slivers: [
      SliverAppBar(
        pinned: false,
        floating: true,
        snap: true,
        leading: IconButton(icon: Icon(Icons.search), onPressed: () => _onSearch(context)),
        // title: header(AppLocalizations.of(context)!.takeoutTitle),
        actions: [
          ...iconBar,
          popupMenu(context, [
            PopupItem.playlist(context, (context) => _onRecentTracks(context)),
            PopupItem.popular(context, (context) => _onPopularTracks(context)),
            PopupItem.divider(),
            PopupItem.settings(context, (context) => _onSettings(context)),
            PopupItem.downloads(context, (context) => _onDownloads(context)),
            PopupItem.logout(context, (_) => TakeoutState.logout()),
            PopupItem.divider(),
            PopupItem.about(context, (context) => _onAbout(context)),
          ]),
        ],
        bottom: _appBarBottom(),
      ),
      StreamBuilder<List<DownloadEntry>>(
          stream: Downloads.downloadsSubject,
          builder: (context, snapshot) {
            final List<DownloadEntry> downloads = snapshot.data ?? [];
            downloadsSort(DownloadSortType.newest, downloads);
            return _itemGrid(context, _items(downloads));
          }),
    ]);
  }

  // void _onSearch(BuildContext context) {
  //   Navigator.push(
  //       context, MaterialPageRoute(builder: (context) => SearchWidget()));
  // }

  PreferredSizeWidget? _appBarBottom() {
    return _cacheSnapshot.downloading.isNotEmpty
        ? PreferredSize(
            child: LinearProgressIndicator(value: _cacheSnapshot.fold().value),
            preferredSize: Size.fromHeight(4.0),
          )
        : null;
  }

  Future<void> _onVideoSelected(BuildContext context) async {
    return changeMediaType(MediaType.video);
  }

  Future<void> _onMusicSelected(BuildContext context) async {
    return changeMediaType(MediaType.music);
  }

  Future<void> _onPodcastsSelected(BuildContext context) async {
    return changeMediaType(MediaType.podcast);
  }

  void _onDownloads(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => DownloadsWidget()));
  }

  void _onSettings(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => AppSettings()));
  }

  void _onHistory(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => HistoryListWidget()));
  }

  void _onRecentTracks(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => SpiffWidget(
                fetch: () => Client().recentTracks(ttl: Duration.zero))));
  }

  void _onPopularTracks(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => SpiffWidget(
                fetch: () => Client().popularTracks(ttl: Duration.zero))));
  }

  void _onAbout(BuildContext context) {
    showAboutDialog(
        context: context,
        applicationName: AppLocalizations.of(context)!.takeoutTitle,
        applicationVersion: appVersion,
        applicationLegalese: 'Copyleft \u00a9 2020-2022 The Takeout Authors',
        children: <Widget>[
          InkWell(
              child: Text(
                appSource,
                style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: Colors.blueAccent),
              ),
              onTap: () => launchUrl(Uri.parse(appSource))),
          InkWell(
              child: Text(
                appHome,
                style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: Colors.blueAccent),
              ),
              onTap: () => launchUrl(Uri.parse(appHome))),
        ]);
  }
}

class _MusicHomeGrid extends _HomeGrid {
  _MusicHomeGrid(GridType _type, CacheSnapshot _snapshot, IndexView _index,
      HomeView _view, VoidContextCallback _onSearch)
      : super(_type, _snapshot, _index, _view, _onSearch);

  @override
  double _gridAspectRatio() => coverAspectRatio;

  @override
  double _gridMaxCrossAxisExtent() => coverGridWidth;

  @override
  Iterable<_HomeItem> _items(List<DownloadEntry> downloads) {
    switch (_type) {
      case GridType.released:
        return _view.released.map((r) => _ReleaseHomeItem(_cacheSnapshot, r));
      case GridType.added:
        return _view.added.map((r) => _ReleaseHomeItem(_cacheSnapshot, r));
      case GridType.downloads:
        return _downloadedItems(MediaType.music, downloads);
      case GridType.mix:
        final LinkedHashSet<_HomeItem> items = LinkedHashSet();
        items.addAll(_downloadedItems(MediaType.music, downloads));
        _view.added
            .forEach((r) => items.add(_ReleaseHomeItem(_cacheSnapshot, r)));
        return items;
    }
  }
}

class _MovieHomeGrid extends _HomeGrid {
  _MovieHomeGrid(GridType _type, CacheSnapshot _snapshot, IndexView _index,
      HomeView _view, VoidContextCallback _onSearch)
      : super(_type, _snapshot, _index, _view, _onSearch);

  @override
  double _gridAspectRatio() => posterAspectRatio;

  @override
  double _gridMaxCrossAxisExtent() => posterGridWidth;

  @override
  Iterable<_HomeItem> _items(List<DownloadEntry> downloads) {
    switch (_type) {
      case GridType.released:
        return _view.newMovies.map((v) => _MovieHomeItem(_cacheSnapshot, v));
      case GridType.added:
        return _view.addedMovies.map((v) => _MovieHomeItem(_cacheSnapshot, v));
      case GridType.downloads:
        return _downloadedItems(MediaType.video, downloads);
      case GridType.mix:
        final LinkedHashSet<_HomeItem> items = LinkedHashSet();
        items.addAll(_downloadedItems(MediaType.video, downloads));
        _view.addedMovies
            .forEach((v) => items.add(_MovieHomeItem(_cacheSnapshot, v)));
        return items;
    }
  }
}

class _SeriesHomeGrid extends _HomeGrid {
  _SeriesHomeGrid(GridType _type, CacheSnapshot _snapshot, IndexView _index,
      HomeView _view, VoidContextCallback _onSearch)
      : super(_type, _snapshot, _index, _view, _onSearch);

  @override
  double _gridAspectRatio() => seriesAspectRatio;

  @override
  double _gridMaxCrossAxisExtent() => seriesGridWidth;

  @override
  Iterable<_HomeItem> _items(List<DownloadEntry> downloads) {
    switch (_type) {
      case GridType.released:
      case GridType.added:
        return _view.newSeries!.map((v) => _SeriesHomeItem(_cacheSnapshot, v));
      case GridType.downloads:
        return _downloadedItems(MediaType.podcast, downloads);
      case GridType.mix:
        final LinkedHashSet<_HomeItem> items = LinkedHashSet();
        items.addAll(_downloadedItems(MediaType.podcast, downloads));
        _view.newSeries!
            .forEach((v) => items.add(_SeriesHomeItem(_cacheSnapshot, v)));
        return items;
    }
  }
}
