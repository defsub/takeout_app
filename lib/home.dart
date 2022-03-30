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
import 'package:takeout_app/global.dart';
import 'package:takeout_app/menu.dart';
import 'package:takeout_app/model.dart';
import 'package:takeout_app/video.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rxdart/rxdart.dart';

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
import 'util.dart';

class HomeWidget extends StatefulWidget {
  final IndexView _index;
  final HomeView _view;

  HomeWidget(this._index, this._view);

  @override
  HomeState createState() => HomeState(_index, _view);
}

class _GridState {
  final String setting;
  final CacheSnapshot cacheSnapshot;

  _GridState(this.setting, this.cacheSnapshot);
}

class HomeState extends State<HomeWidget> {
  IndexView _index;
  HomeView _view;

  HomeState(this._index, this._view);

  _HomeGrid _grid(
      MediaType mediaType, GridType gridType, CacheSnapshot cacheSnapshot) {
    switch (mediaType) {
      case MediaType.video:
        return _MovieHomeGrid(gridType, cacheSnapshot, _index, _view);
      case MediaType.music:
      case MediaType.stream: // unused for now
        return _MusicHomeGrid(gridType, cacheSnapshot, _index, _view);
      case MediaType.podcast:
        return _SeriesHomeGrid(gridType, cacheSnapshot, _index, _view);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_GridState>(
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
      print('refresh err $error');
    }
  }
}

abstract class _HomeItem {
  Widget Function() get onTap;

  String get title;

  String? get subtitle;

  String get key;

  Widget get trailing;

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
  String get title => album.album;

  @override
  String? get subtitle => album.creator.isNotEmpty ? album.creator : null;

  Widget _downloadIcon(SpiffDownloadEntry download, IconData completeIcon,
      IconData downloadingIcon) {
    final isCached = snapshot.containsAll(download.spiff.playlist.tracks);
    return Icon(isCached ? completeIcon : downloadingIcon,
        color: Colors.white70);
  }

  @override
  Widget get trailing {
    var year = album.year;
    if (album is SpiffDownloadEntry) {
      return _downloadIcon(
          album as SpiffDownloadEntry, IconsDownloadDone, IconsDownload);
    } else if (year > 1) {
      return Text('$year');
    }
    return Container();
  }

  @override
  String get key {
    if (_key == null) {
      _key = "$title/$subtitle";
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
  String get title => ''; //(album as Movie).rating;

  @override
  String? get subtitle => null;

  @override
  Widget get trailing => Container();

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
  String get title => '';

  @override
  String? get subtitle => when((album as Series).date);

  @override
  Widget get trailing => Container();

  @override
  Widget get image {
    return gridPoster(album.image);
  }

  String when(String date) {
    return relativeDate(date);
  }
}

abstract class _HomeGrid extends StatelessWidget {
  final GridType _type;
  final CacheSnapshot _cacheSnapshot;
  final IndexView _index;
  final HomeView _view;

  _HomeGrid(this._type, this._cacheSnapshot, this._index, this._view);

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
    return SliverGrid.extent(
        childAspectRatio: _gridAspectRatio(),
        maxCrossAxisExtent: _gridMaxCrossAxisExtent(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: [
          ...items.map((i) => Container(
              child: GestureDetector(
                  onTap: () => _onTap(context, i),
                  child: GridTile(
                    footer: Material(
                        color: Colors.transparent,
                        // shape: RoundedRectangleBorder(
                        //     borderRadius: BorderRadius.vertical(
                        //         bottom: Radius.circular(4))),
                        clipBehavior: Clip.antiAlias,
                        child: GridTileBar(
                          backgroundColor: Colors.black26,
                          title: Text(i.title),
                          subtitle:
                              i.subtitle != null ? Text(i.subtitle!) : null,
                          trailing: i.trailing,
                        )),
                    child: i.image,
                  ))))
        ]);
  }

  @override
  Widget build(BuildContext context) {
    final mediaType = settingsMediaType(type: MediaType.music);

    final buttons = SplayTreeMap<MediaType, IconButton>(
        (a, b) => a.index.compareTo(b.index));

    final iconSize = 22.0;
    final selectedColor = Theme.of(context).indicatorColor;
    if (_index.hasMusic) {
      buttons[MediaType.music] = IconButton(
          iconSize: iconSize,
          color: mediaType == MediaType.music ? selectedColor : null,
          icon: Icon(Icons.audiotrack),
          onPressed: () => _onMusicSelected(context));
    }
    if (_index.hasMovies) {
      buttons[MediaType.video] = IconButton(
          iconSize: iconSize,
          color: mediaType == MediaType.video ? selectedColor : null,
          icon: Icon(Icons.movie),
          onPressed: () => _onVideoSelected(context));
    }
    if (_index.hasPodcasts) {
      buttons[MediaType.podcast] = IconButton(
          iconSize: iconSize,
          color: mediaType == MediaType.podcast ? selectedColor : null,
          icon: Icon(Icons.podcasts),
          onPressed: () => _onPodcastsSelected(context));
    }

    final iconBar = <Widget>[];
    if (_cacheSnapshot.downloading.isNotEmpty) {
      // add icon to show download progress
      final downloadProgress = _cacheSnapshot.downloading.values
          .fold<DownloadSnapshot>(
              DownloadSnapshot(0, 0),
              (total, e) => DownloadSnapshot(
                  total.size + e.size, total.offset + e.offset));
      iconBar.add(Center(
          child: SizedBox(
              width: iconSize,
              height: iconSize,
              child:
                  CircularProgressIndicator(value: downloadProgress.value))));
    }
    iconBar.addAll(buttons.values);

    return CustomScrollView(slivers: [
      SliverAppBar(
        pinned: false,
        floating: true,
        snap: true,
        title: header(AppLocalizations.of(context)!.takeoutTitle),
        actions: [
          ...iconBar,
          popupMenu(context, [
            PopupItem.settings(context, (context) => _onSettings(context)),
            PopupItem.downloads(context, (context) => _onDownloads(context)),
            PopupItem.logout(context, (_) => TakeoutState.logout()),
            PopupItem.divider(),
            PopupItem.about(context, (context) => _onAbout(context)),
          ]),
        ],
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
              onTap: () => launch(appSource)),
          InkWell(
              child: Text(
                appHome,
                style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: Colors.blueAccent),
              ),
              onTap: () => launch(appHome)),
        ]);
  }
}

class _MusicHomeGrid extends _HomeGrid {
  _MusicHomeGrid(
      GridType _type, CacheSnapshot _snapshot, IndexView _index, HomeView _view)
      : super(_type, _snapshot, _index, _view);

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
  _MovieHomeGrid(
      GridType _type, CacheSnapshot _snapshot, IndexView _index, HomeView _view)
      : super(_type, _snapshot, _index, _view);

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
  _SeriesHomeGrid(
      GridType _type, CacheSnapshot _snapshot, IndexView _index, HomeView _view)
      : super(_type, _snapshot, _index, _view);

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
