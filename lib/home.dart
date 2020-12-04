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

import 'package:flutter/material.dart';

import 'music.dart';
import 'release.dart';
import 'style.dart';
import 'downloads.dart';

class HomeWidget extends StatelessWidget {
  final HomeView _view;

  HomeWidget(this._view);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: header('Home')),
        body: SingleChildScrollView(
            child: Column(
          children: [
            headingButton('Downloads', () {
              _onDownloads(context);
            }),
            Container(child: DownloadListWidget()),
            Divider(),
            headingButton('Recently Added', () {
              _onAdded(context);
            }),
            Container(child: ReleaseListWidget(_view.added.sublist(0, 3))),
            Divider(),
            headingButton('Recently Released', () {
              _onReleased(context);
            }),
            Container(child: ReleaseListWidget(_view.released.sublist(0, 3))),
          ],
        )));
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
