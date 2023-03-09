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

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:takeout_app/cache/spiff.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logging/logging.dart';

import 'package:takeout_app/api/model.dart';
import 'package:takeout_app/app/context.dart';
import 'package:takeout_app/art/artwork.dart';
import 'package:takeout_app/art/cover.dart';
import 'package:takeout_app/media_type/media_type.dart';
import 'package:takeout_app/page/page.dart';
import 'package:takeout_app/client/download.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/spiff/widget.dart';
import 'package:takeout_app/client/client.dart';
import 'package:takeout_app/tiles.dart';
import 'package:takeout_app/downloads.dart';

import 'release.dart';
import 'settings.dart';
import 'style.dart';
import 'podcasts.dart';
import 'global.dart';
import 'menu.dart';
import 'model.dart';
import 'video.dart';

class HomeState {
  final IndexView index;
  final HomeView home;

  HomeState({required this.index, required this.home});
}

class HomeWidget extends NavigatorClientPage<HomeState> {
  static final log = Logger('HomeState');
  final VoidContextCallback _onSearch;

  HomeWidget(this._onSearch) : super(homeKey);

  _HomeGrid _grid(HomeState state, MediaType mediaType, GridType gridType,
      DownloadState downloadState) {
    switch (mediaType) {
      case MediaType.video:
        return _MovieHomeGrid(state, gridType, downloadState, _onSearch);
      case MediaType.music:
      case MediaType.stream: // unused for now
        return _MusicHomeGrid(state, gridType, downloadState, _onSearch);
      case MediaType.podcast:
        return _SeriesHomeGrid(state, gridType, downloadState, _onSearch);
    }
  }

  @override
  void load(BuildContext context, {Duration? ttl}) {
    // TODO combine results?
    context.client.home(ttl: ttl);
    context.client.index(ttl: ttl);
  }

  @override
  Widget page(BuildContext context, HomeState state) {
    final bloc = context.watch<SelectedMediaType>();
    final downloads = context.watch<DownloadCubit>();
    final builder = (_) => Builder(builder: (context) {
          final type = settingsGridType(settingHomeGridType, GridType.mix);
          return Scaffold(
              body: RefreshIndicator(
            onRefresh: () => refreshPage(context),
            child: _grid(state, bloc.state, type, downloads.state),
          ));
        });

    return Navigator(
        key: homeKey,
        initialRoute: '/',
        observers: [heroController()],
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute(builder: builder, settings: settings);
        });
  }
}

abstract class _HomeItem {
  Widget Function() get onTap;

  bool get overlay;

  Widget? get title;

  Widget? get subtitle;

  String get key;

  Widget getTrailing(BuildContext context);

  Widget image(BuildContext context);

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
  DownloadState downloadState;
  String? _key;

  _MediaHomeItem(
    this.downloadState,
    this.album,
  );

  @override
  Widget Function() get onTap {
    return () => SpiffWidget(value: album as Spiff);
  }

  @override
  bool get overlay => album.album.isNotEmpty || album.creator.isNotEmpty;

  @override
  Widget? get title => Text(album.album);

  @override
  Widget? get subtitle => album.creator.isNotEmpty ? Text(album.creator) : null;

  Widget _downloadIcon(BuildContext context, Spiff download,
      IconData completeIcon, IconData downloadingIcon) {
    final isCached = downloadState.containsAll(download.playlist.tracks);
    return Icon(isCached ? completeIcon : downloadingIcon,
        color: overlayIconColor(context));
  }

  @override
  Widget getTrailing(BuildContext context) {
    var year = album.year;
    if (album is Spiff) {
      return _downloadIcon(
          context, album as Spiff, IconsDownloadDone, IconsDownload);
    } else if (year > 1) {
      return Text('$year');
    }
    return SizedBox.shrink();
  }

  @override
  String get key {
    if (_key == null) {
      _key = "${album.album}/${album.creator}";
    }
    return _key!;
  }

  @override
  Widget image(BuildContext context) {
    return gridCover(context, album.image);
  }
}

class _ReleaseHomeItem extends _MediaHomeItem {
  _ReleaseHomeItem(DownloadState downloadState, Release release)
      : super(downloadState, release);

  @override
  Widget Function() get onTap {
    return () => ReleaseWidget(album as Release);
  }
}

class _MovieHomeItem extends _MediaHomeItem {
  _MovieHomeItem(DownloadState downloadState, Movie movie)
      : super(downloadState, movie);

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
  Widget getTrailing(BuildContext context) => SizedBox.shrink();

  @override
  Widget image(BuildContext context) {
    return gridPoster(context, album.image);
  }
}

class _SeriesHomeItem extends _MediaHomeItem {
  _SeriesHomeItem(DownloadState downloadState, Series series)
      : super(downloadState, series);

  @override
  Widget Function() get onTap {
    return () => SeriesWidget(album as Series);
  }

  @override
  String get key => album.album + '/' + album.creator; // == title/author

  @override
  Widget? get title => null;

  @override
  Widget? get subtitle => RelativeDateWidget.from((album as Series).date);

  @override
  Widget getTrailing(BuildContext context) =>
      SizedBox.shrink(); // no trailer (year)

  @override
  Widget image(BuildContext context) {
    return gridPoster(context, album.image);
  }
}

class _SpiffAlbum implements MediaAlbum {
  final Spiff spiff;

  _SpiffAlbum(this.spiff);

  String get creator => spiff.playlist.creator ?? '';

  String get album => spiff.playlist.title;

  String get image => spiff.cover;

  int get year {
    return -1;
  }
}

abstract class _HomeGrid extends StatelessWidget {
  final HomeState _state;
  final GridType _type;
  final DownloadState _downloadState;
  final VoidContextCallback _onSearch;
  final _buttons =
      SplayTreeMap<MediaType, IconButton>((a, b) => a.index.compareTo(b.index));

  _HomeGrid(this._state, this._type, this._downloadState, this._onSearch);

  Iterable<_HomeItem> _items(List<Spiff> downloads);

  double _gridAspectRatio();

  double _gridMaxCrossAxisExtent();

  void _onTap(BuildContext context, _HomeItem item) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.onTap()));
  }

  List<_MediaHomeItem> _downloadedItems(
      MediaType mediaType, List<Spiff> downloads) {
    List<_MediaHomeItem> items = [];
    downloads.forEach((d) {
      if (d.mediaType == mediaType) {
        items.add(_MediaHomeItem(_downloadState, _SpiffAlbum(d)));
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
                      nextGridType(context);
                    } else if (dir == 1) {
                      prevGridType(context);
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
                    child: i.image(context),
                  ))))
        ]);
  }

  void nextGridType(BuildContext context) => context.selectedMediaType.next();

  void prevGridType(BuildContext context) =>
      context.selectedMediaType.previous();

  @override
  Widget build(BuildContext context) {
    final mediaType = context.selectedMediaType.state;
    final iconSize = 22.0;
    final selectedColor = Theme.of(context).indicatorColor;
    _buttons.clear();
    if (_state.index.hasMusic) {
      _buttons[MediaType.music] = IconButton(
          iconSize: iconSize,
          color: mediaType == MediaType.music ? selectedColor : null,
          icon: Icon(Icons.audiotrack),
          onPressed: () => _onMusicSelected(context));
    }
    if (_state.index.hasMovies) {
      _buttons[MediaType.video] = IconButton(
          iconSize: iconSize,
          color: mediaType == MediaType.video ? selectedColor : null,
          icon: Icon(Icons.movie),
          onPressed: () => _onVideoSelected(context));
    }
    if (_state.index.hasPodcasts) {
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
        leading: IconButton(
            icon: Icon(Icons.search), onPressed: () => _onSearch(context)),
        // title: header(AppLocalizations.of(context)!.takeoutTitle),
        actions: [
          ...iconBar,
          popupMenu(context, [
            PopupItem.playlist(context, (context) => _onRecentTracks(context)),
            PopupItem.popular(context, (context) => _onPopularTracks(context)),
            PopupItem.divider(),
            PopupItem.settings(context, (context) => _onSettings(context)),
            PopupItem.downloads(context, (context) => _onDownloads(context)),
            PopupItem.logout(context, (_) => _onLogout(context)),
            PopupItem.divider(),
            PopupItem.about(context, (context) => _onAbout(context)),
          ]),
        ],
        bottom: _appBarBottom(),
      ),
      BlocBuilder<SpiffCacheCubit, SpiffCacheState>(
          builder: (context, cacheState) {
        final downloads = List<Spiff>.from(cacheState.spiffs ?? <Spiff>[]);
        downloadsSort(DownloadSortType.newest, downloads);
        return _itemGrid(context, _items(downloads));
      })
    ]);
  }

  // void _onSearch(BuildContext context) {
  //   Navigator.push(
  //       context, MaterialPageRoute(builder: (context) => SearchWidget()));
  // }

  PreferredSizeWidget? _appBarBottom() {
    return null;
    // return _downloadState.downloading.isNotEmpty
    //     ? PreferredSize(
    //         child: LinearProgressIndicator(value: _cacheSnapshot.fold().value),
    //         preferredSize: Size.fromHeight(4.0),
    //       )
    //     : null;
  }

  void _onVideoSelected(BuildContext context) {
    context.selectedMediaType.select(MediaType.video);
  }

  void _onMusicSelected(BuildContext context) {
    context.selectedMediaType.select(MediaType.music);
  }

  void _onPodcastsSelected(BuildContext context) {
    context.selectedMediaType.select(MediaType.podcast);
  }

  void _onDownloads(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => DownloadsWidget()));
  }

  void _onSettings(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AppSettings()));
  }

  void _onRecentTracks(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SpiffWidget(
                fetch: (ClientCubit client, {Duration? ttl}) =>
                    client.recentTracks(ttl: Duration.zero))));
  }

  void _onPopularTracks(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SpiffWidget(
                fetch: (ClientCubit client, {Duration? ttl}) =>
                    client.popularTracks(ttl: Duration.zero))));
  }

  void _onLogout(BuildContext context) {
    throw UnimplementedError;
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
  _MusicHomeGrid(
      super.state, super._type, super._downloadState, super._onSearch);

  @override
  double _gridAspectRatio() => coverAspectRatio;

  @override
  double _gridMaxCrossAxisExtent() => coverGridWidth;

  @override
  Iterable<_HomeItem> _items(List<Spiff> downloads) {
    switch (_type) {
      case GridType.released:
        return _state.home.released
            .map((r) => _ReleaseHomeItem(_downloadState, r));
      case GridType.added:
        return _state.home.added
            .map((r) => _ReleaseHomeItem(_downloadState, r));
      case GridType.downloads:
        return _downloadedItems(MediaType.music, downloads);
      case GridType.mix:
        final LinkedHashSet<_HomeItem> items = LinkedHashSet();
        items.addAll(_downloadedItems(MediaType.music, downloads));
        _state.home.added
            .forEach((r) => items.add(_ReleaseHomeItem(_downloadState, r)));
        return items;
    }
  }
}

class _MovieHomeGrid extends _HomeGrid {
  _MovieHomeGrid(
      super.state, super._type, super._downloadState, super._onSearch);

  @override
  double _gridAspectRatio() => posterAspectRatio;

  @override
  double _gridMaxCrossAxisExtent() => posterGridWidth;

  @override
  Iterable<_HomeItem> _items(List<Spiff> downloads) {
    switch (_type) {
      case GridType.released:
        return _state.home.newMovies
            .map((v) => _MovieHomeItem(_downloadState, v));
      case GridType.added:
        return _state.home.addedMovies
            .map((v) => _MovieHomeItem(_downloadState, v));
      case GridType.downloads:
        return _downloadedItems(MediaType.video, downloads);
      case GridType.mix:
        final LinkedHashSet<_HomeItem> items = LinkedHashSet();
        items.addAll(_downloadedItems(MediaType.video, downloads));
        _state.home.addedMovies
            .forEach((v) => items.add(_MovieHomeItem(_downloadState, v)));
        return items;
    }
  }
}

class _SeriesHomeGrid extends _HomeGrid {
  _SeriesHomeGrid(
      super.state, super._type, super._downloadState, super._onSearch);

  @override
  double _gridAspectRatio() => seriesAspectRatio;

  @override
  double _gridMaxCrossAxisExtent() => seriesGridWidth;

  @override
  Iterable<_HomeItem> _items(List<Spiff> downloads) {
    switch (_type) {
      case GridType.released:
      case GridType.added:
        return _state.home.newSeries!
            .map((v) => _SeriesHomeItem(_downloadState, v));
      case GridType.downloads:
        final items = <_HomeItem>[];
        final downloadedItems = _downloadedItems(MediaType.podcast, downloads);
        _state.home.newSeries!.forEach((v) {
          // use series items with downloads over download items
          final seriesItem = _SeriesHomeItem(_downloadState, v);
          if (downloadedItems.any((e) => e.key == seriesItem.key)) {
            items.add(seriesItem);
          }
        });
        return items;
      case GridType.mix:
        // final LinkedHashSet<_HomeItem> items = LinkedHashSet();
        // items.addAll(_downloadedItems(MediaType.podcast, downloads));
        // _view.newSeries!
        //     .forEach((v) => items.add(_SeriesHomeItem(_cacheSnapshot, v)));
        // prefer series items over downloads
        final items = _state.home.newSeries!
            .map((v) => _SeriesHomeItem(_downloadState, v));
        return items;
    }
  }
}
