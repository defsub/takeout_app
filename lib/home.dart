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

import 'client.dart';
import 'downloads.dart';
import 'main.dart';
import 'schema.dart';
import 'release.dart';
import 'settings.dart';
import 'style.dart';
import 'cover.dart';
import 'cache.dart';

class HomeWidget extends StatefulWidget {
  final HomeView _view;

  HomeWidget(this._view);

  @override
  HomeState createState() => HomeState(_view);
}

class HomeState extends State<HomeWidget> {
  HomeView _view;

  HomeState(this._view);

  _HomeGrid _grid(MediaType mediaType, GridType gridType, HomeView view) {
    if (mediaType == MediaType.video) {
      return _MovieHomeGrid(gridType, view);
    } else {
      return _MusicHomeGrid(gridType, view);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: settingsChangeSubject.stream,
        builder: (context, snapshot) {
          // TODO will rebuild on any settings change
          final type = settingsGridType(settingHomeGridType, GridType.mix);
          final mediaType = settingsMediaType(MediaType.music);
          return Scaffold(
              body: RefreshIndicator(
            onRefresh: () => _onRefresh(),
            child: _grid(mediaType, type, _view),
          ));
        });
  }

  Future<void> _onRefresh() async {
    try {
      final client = Client();
      final result = await client.home(ttl: Duration.zero);
      if (mounted) {
        setState(() {
          _view = result;
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
  String? _key;

  _MediaHomeItem(
    this.album,
  );

  @override
  Widget Function() get onTap {
    return () => DownloadWidget(spiff: (album as SpiffDownloadEntry).spiff);
  }

  @override
  String get title => album.album;

  @override
  String? get subtitle => album.creator.isNotEmpty ? album.creator : null;

  Widget _downloadIcon(SpiffDownloadEntry download, IconData completeIcon,
      IconData downloadingIcon) {
    return StreamBuilder<Set<String>>(
        stream: TrackCache.keysSubject,
        builder: (context, snapshot) {
          final keys = snapshot.data ?? Set<String>();
          final isCached =
              TrackCache.checkAll(keys, download.spiff.playlist.tracks);
          return Icon(isCached ? completeIcon : downloadingIcon,
              color: Colors.white70);
        });
  }

  @override
  Widget get trailing {
    var year = album.year;
    if (album is SpiffDownloadEntry) {
      return _downloadIcon(album as SpiffDownloadEntry,
          Icons.cloud_done_outlined, Icons.cloud_download_outlined);
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
  _ReleaseHomeItem(Release release) : super(release);

  @override
  Widget Function() get onTap {
    return () => ReleaseWidget(album as Release);
  }
}

class _MovieHomeItem extends _MediaHomeItem {
  _MovieHomeItem(Movie movie) : super(movie);

  @override
  Widget Function() get onTap {
    return () => MovieWidget(album as Movie);
  }

  @override
  String get key => (album as Movie).titleYear;

  @override
  String get title => (album as Movie).rating;

  @override
  String? get subtitle => null;

  @override
  Widget get image {
    return gridPoster(album.image);
  }
}

abstract class _HomeGrid extends StatelessWidget {
  final GridType _type;
  final HomeView _view;

  _HomeGrid(this._type, this._view);

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
        items.add(_MediaHomeItem(d));
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
    final mediaType = settingsMediaType(MediaType.music);
    return CustomScrollView(slivers: [
      SliverAppBar(
        pinned: false,
        floating: true,
        snap: true,
        title: header(AppLocalizations.of(context)!.takeoutTitle),
        actions: [
          popupMenu(context, [
            if (mediaType == MediaType.music)
              PopupItem.video(context, (context) => _onVideoSelected(context)),
            if (mediaType == MediaType.video)
              PopupItem.music(context, (context) => _onMusicSelected(context)),
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
            final List<DownloadEntry> entries = snapshot.data ?? [];
            downloadsSort(DownloadSortType.newest, entries);
            return _itemGrid(context, _items(entries));
          }),
    ]);
  }

  Future<void> _onVideoSelected(BuildContext context) async {
    return changeMediaType(MediaType.video);
  }

  Future<void> _onMusicSelected(BuildContext context) async {
    return changeMediaType(MediaType.music);
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
        applicationLegalese: 'Copyleft \u00a9 2020-2021 The Takeout Authors',
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
  _MusicHomeGrid(GridType _type, HomeView _view) : super(_type, _view);

  @override
  double _gridAspectRatio() => coverAspectRatio;

  @override
  double _gridMaxCrossAxisExtent() => coverGridWidth;

  @override
  Iterable<_HomeItem> _items(List<DownloadEntry> downloads) {
    switch (_type) {
      case GridType.released:
        return _view.released.map((r) => _ReleaseHomeItem(r));
      case GridType.added:
        return _view.added.map((r) => _ReleaseHomeItem(r));
      case GridType.downloads:
        return _downloadedItems(MediaType.music, downloads);
      case GridType.mix:
        final LinkedHashSet<_HomeItem> items = LinkedHashSet();
        items.addAll(_downloadedItems(MediaType.music, downloads));
        _view.added.forEach((r) => items.add(_ReleaseHomeItem(r)));
        return items;
    }
  }
}

class _MovieHomeGrid extends _HomeGrid {
  _MovieHomeGrid(GridType _type, HomeView _view) : super(_type, _view);

  @override
  double _gridAspectRatio() => posterAspectRatio;

  @override
  double _gridMaxCrossAxisExtent() => posterGridWidth;

  @override
  Iterable<_HomeItem> _items(List<DownloadEntry> downloads) {
    switch (_type) {
      case GridType.released:
        return _view.newMovies.map((v) => _MovieHomeItem(v));
      case GridType.added:
        return _view.addedMovies.map((v) => _MovieHomeItem(v));
      case GridType.downloads:
        return _downloadedItems(MediaType.video, downloads);
      case GridType.mix:
        final LinkedHashSet<_HomeItem> items = LinkedHashSet();
        items.addAll(_downloadedItems(MediaType.video, downloads));
        _view.addedMovies.forEach((v) => items.add(_MovieHomeItem(v)));
        return items;
    }
  }
}
