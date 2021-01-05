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
import 'package:takeout_app/global.dart';
import 'package:takeout_app/menu.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'music.dart';
import 'release.dart';
import 'style.dart';
import 'downloads.dart';
import 'client.dart';

class HomeWidget extends StatefulWidget {
  final HomeView _view;

  HomeWidget(this._view);

  @override
  HomeState createState() => HomeState(_view);
}

const recentSize = 3;

class HomeState extends State<HomeWidget> {
  HomeView _view;

  HomeState(this._view);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: header('Home'),
          actions: [
            popupMenu(context, [
              PopupItem.downloads((context) => _onDownloads(context)),
              PopupItem.refresh((_) => _onRefresh),
              PopupItem.logout((_) => TakeoutState.logout()),
              PopupItem.divider(),
              PopupItem.about((context) => _onAbout(context)),
            ]),
          ],
        ),
        body: RefreshIndicator(
            onRefresh: () => _onRefresh(),
            child: SingleChildScrollView(
                child: Column(
              children: [
                StreamBuilder(
                    stream: Downloads.downloadsSubject,
                    builder: (context, snapshot) {
                      final List<DownloadEntry> entries = snapshot.data ?? [];
                      if (entries.isEmpty) {
                        return SizedBox.shrink();
                      }
                      return Column(children: [
                        headingButton(
                            'Recently Downloaded', () => _onDownloads(context)),
                        Container(
                            child: DownloadListWidget(
                                limit: recentSize,
                                sortType: DownloadSortType.newest)),
                        Divider(),
                      ]);
                    }),
                headingButton('Recently Added', () => _onAdded(context)),
                Container(
                    child: ReleaseListWidget(_view.added
                        .sublist(0, min(recentSize, _view.added.length)))),
                Divider(),
                headingButton('Recently Released', () => _onReleased(context)),
                Container(
                    child: ReleaseListWidget(_view.released
                        .sublist(0, min(recentSize, _view.released.length)))),
              ],
            ))));
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

  void _onAdded(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                RecentReleasesWidget('Recently Added', _view.added)));
  }

  void _onReleased(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                RecentReleasesWidget('Recently Released', _view.released)));
  }

  void _onDownloads(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => DownloadsWidget()));
  }

  void _onAbout(BuildContext context) {
    showAboutDialog(
        context: context,
        applicationName: appName,
        applicationVersion: appVersion,
        applicationLegalese: 'Copyleft © 2020-2021 The Takeout Authors',
        children: <Widget>[
          FlatButton(
              child: Text('https://github.com/defsub/takeout_app'),
              onPressed: () => launch('https://github.com/defsub/takeout_app')),
        ]);
  }
}

class RecentReleasesWidget extends StatelessWidget {
  final String _title;
  final List<Release> _releases;

  RecentReleasesWidget(this._title, this._releases);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: SingleChildScrollView(
            child: Column(
          children: [
            Container(child: ReleaseListWidget(_releases)),
          ],
        )));
  }
}
