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
import 'package:takeout_app/global.dart';
import 'package:takeout_app/menu.dart';
import 'package:takeout_app/model.dart';
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: settingsChangeSubject.stream,
        builder: (context, snapshot) {
          // TODO will rebuild on any settings change
          final type = settingsGridType(settingHomeGridType, GridType.mix);
          return Scaffold(
              body: RefreshIndicator(
            onRefresh: () => _onRefresh(),
            child: _HomeGrid(type, _view),
          ));
        });
  }

  Future<void> _onRefresh() async {
    try {
      final client = Client();
      final result = await client.home(ttl: Duration.zero);
      setState(() {
        _view = result;
      });
    } catch (error) {
      print('refresh err $error');
    }
  }
}

class _HomeItem {
  MusicAlbum album;
  Widget Function() onTap;
  String _key;

  _HomeItem(this.album, this.onTap);

  String get title => album.album;

  String get subtitle => album.creator;

  Widget downloadIcon(
      DownloadEntry download, IconData completeIcon, IconData downloadingIcon) {
    return StreamBuilder(
        stream: TrackCache.keysSubject,
        builder: (context, snapshot) {
          final keys = snapshot.data ?? Set<String>();
          final isCached =
              TrackCache.checkAll(keys, download.spiff.playlist.tracks);
          return Icon(isCached ? completeIcon : downloadingIcon,
              color: Colors.white70);
        });
  }

  Widget get trailing {
    if (album.year > 1) return Text('${album.year}');
    if (album is DownloadEntry) {
      return downloadIcon(album, Icons.cloud_done_outlined, Icons.cloud_download_outlined);
    }
    return Text('');
  }

  String get key {
    if (_key == null) {
      _key = "$title/$subtitle";
    }
    return _key;
  }

  Widget image() {
    return gridCover(album.image);
  }

  @override
  int get hashCode {
    return key.hashCode;
  }

  @override
  bool operator ==(Object o) {
    return o is _HomeItem && o.key == key;
  }
}

class _HomeGrid extends StatelessWidget {
  final GridType _type;
  final HomeView _view;

  _HomeGrid(this._type, this._view);

  void _onTap(BuildContext context, _HomeItem item) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => item.onTap()));
  }

  Iterable<_HomeItem> _items(List<DownloadEntry> downloads) {
    LinkedHashSet<_HomeItem> items = LinkedHashSet();

    if (_type == GridType.mix) {
      for (var d in downloads) {
        items.add(_HomeItem(d, () => DownloadWidget(spiff: d.spiff)));
      }
      for (var r in _view.added) {
        final i = _HomeItem(r, () => ReleaseWidget(r));
        if (!items.contains(i)) {
          items.add(i);
        }
      }
    } else if (_type == GridType.downloads) {
      for (var d in downloads) {
        items.add(_HomeItem(d, () => DownloadWidget(spiff: d.spiff)));
      }
    } else if (_type == GridType.added) {
      for (var r in _view.added) {
        items.add(_HomeItem(r, () => ReleaseWidget(r)));
      }
    } else if (_type == GridType.released) {
      for (var r in _view.released) {
        items.add(_HomeItem(r, () => ReleaseWidget(r)));
      }
    }
    return items;
  }

  SliverGrid _releaseGrid(BuildContext context, Iterable<_HomeItem> items) {
    return SliverGrid.count(
        crossAxisCount: 2,
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
                          subtitle: Text(i.subtitle),
                          trailing: i.trailing,
                        )),
                    child: i.image(),
                  ))))
        ]);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      SliverAppBar(
        pinned: false,
        floating: true,
        snap: true,
        title: header('Takeout'),
        actions: [
          popupMenu(context, [
            PopupItem.settings((context) => _onSettings(context)),
            PopupItem.downloads((context) => _onDownloads(context)),
            PopupItem.logout((_) => TakeoutState.logout()),
            PopupItem.divider(),
            PopupItem.about((context) => _onAbout(context)),
          ]),
        ],
      ),
      StreamBuilder(
          stream: Downloads.downloadsSubject,
          builder: (context, snapshot) {
            final List<DownloadEntry> entries = snapshot.data ?? [];
            downloadsSort(DownloadSortType.newest, entries);
            return _releaseGrid(context, _items(entries));
          }),
    ]);
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
        applicationName: appName,
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
