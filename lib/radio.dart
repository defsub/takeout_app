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
import 'package:connectivity/connectivity.dart';

import 'music.dart';
import 'main.dart';
import 'playlist.dart';
import 'client.dart';
import 'downloads.dart';
import 'spiff.dart';
import 'style.dart';
import 'cache.dart';
import 'menu.dart';
import 'global.dart';

class RadioWidget extends StatefulWidget {
  final RadioView _view;

  RadioWidget(this._view);

  @override
  RadioState createState() => RadioState(_view);
}

class RadioState extends State<RadioWidget> {
  RadioView _view;

  RadioState(this._view);

  List<DownloadEntry> _radioFilter(List<DownloadEntry> entries) {
    final list = List<DownloadEntry>.from(entries);
    list.retainWhere((e) => e.spiff.playlist.creator == 'Radio');
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: Downloads.downloadsSubject,
        builder: (context, snapshot) {
          List<DownloadEntry> entries = snapshot.data ?? [];
          entries = _radioFilter(entries);
          bool haveDownloads = entries.isNotEmpty;
          return DefaultTabController(
              length: haveDownloads ? 4 : 3,
              child: RefreshIndicator(
                  onRefresh: () => _onRefresh(),
                  child: Scaffold(
                      appBar: AppBar(
                          title: Text('Radio'),
                          actions: [
                            popupMenu(context, [
                              PopupItem.refresh((_) => _onRefresh()),
                            ]),
                          ],
                          bottom: TabBar(
                            tabs: [
                              Tab(text: 'Genres'),
                              Tab(text: 'Decades'),
                              Tab(text: 'Other'),
                              if (haveDownloads) Tab(text: 'Downloads')
                            ],
                          )),
                      body: TabBarView(
                        children: [
                          _stations(_view.genre),
                          _stations(_view.period),
                          _stations(_merge(_view.series, _view.other)),
                          if (haveDownloads)
                            DownloadListWidget(filter: _radioFilter)
                        ],
                      ))));
        });
  }

  List<Station> _merge(List<Station> a, List<Station> b) {
    a ??= [];
    b ??= [];
    final list = a + b;
    list.sort((x, y) => x.name.compareTo(y.name));
    return list;
  }

  Widget _stations(List<Station> stations) {
    return ListView.builder(
        itemCount: stations?.length ?? 0,
        itemBuilder: (context, index) {
          return StreamBuilder<ConnectivityResult>(
              stream: TakeoutState.connectivityStream.distinct(),
              builder: (context, snapshot) {
                final result = snapshot.data;
                return ListTile(
                  // enabled: TakeoutState.allowStreaming(result),
                  // onTap: TakeoutState.allowStreaming(result)
                  //     ? () => _onPlay(stations[index])
                  //     : null,
                  onTap: () => _onStation(stations[index]),
                  leading: Icon(Icons.radio),
                  title: Text(stations[index].name),
                  trailing: IconButton(
                      icon: Icon(Icons.cloud_download_outlined),
                      onPressed: TakeoutState.allowDownload(result)
                          ? () => _onDownload(stations[index])
                          : null),
                );
              });
        });
  }

  void _onStation(Station station) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RefreshSpiffWidget(
                () => Client().station(station.id, ttl: Duration.zero))));
  }

  void _onDownload(Station station) {
    Downloads.downloadStation(station);
  }

  Future<void> _onRefresh() async {
    try {
      final client = Client();
      final result = await client.radio(ttl: Duration.zero);
      setState(() {
        _view = result;
      });
    } catch (error) {
      print('refresh err $error');
    }
  }
}

class RefreshSpiffWidget extends StatefulWidget {
  final Future<Spiff> Function() _fetchSpiff;

  RefreshSpiffWidget(this._fetchSpiff);

  @override
  _RefreshSpiffState createState() => _RefreshSpiffState(_fetchSpiff);
}

class _RefreshSpiffState extends State<RefreshSpiffWidget> {
  final Future<Spiff> Function() _fetchSpiff;
  Spiff _spiff;

  _RefreshSpiffState(this._fetchSpiff);

  @override
  void initState() {
    super.initState();
    _onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: header(_spiff?.playlist?.title ?? ''),
          actions: [
            popupMenu(context, [
              PopupItem.refresh((_) => _onRefresh()),
            ]),
          ],
        ),
        body: RefreshIndicator(
            onRefresh: () => _onRefresh(),
            child: StreamBuilder<ConnectivityResult>(
                stream: TakeoutState.connectivityStream.distinct(),
                builder: (context, snapshot) {
                  final result = snapshot.data;
                  return (_spiff == null)
                      ? Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          child: StreamBuilder(
                              stream: TrackCache.keysSubject,
                              builder: (context, snapshot) {
                                final keys = snapshot.data ?? Set<String>();
                                final isCached = _spiff != null
                                    ? TrackCache.checkAll(
                                        keys, _spiff.playlist.tracks)
                                    : false;
                                return Column(children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      OutlinedButton.icon(
                                          label: Text('Play'),
                                          icon: Icon(Icons.play_arrow),
                                          onPressed:
                                              TakeoutState.allowStreaming(
                                                      result)
                                                  ? () => _onPlay()
                                                  : null),
                                      OutlinedButton.icon(
                                          label: Text(isCached
                                              ? 'Complete'
                                              : 'Download'),
                                          icon: Icon(
                                              Icons.cloud_download_outlined),
                                          onPressed:
                                              TakeoutState.allowDownload(result)
                                                  ? () => _onDownload()
                                                  : null),
                                    ],
                                  ),
                                  Divider(),
                                  SpiffTrackListView(_spiff),
                                ]);
                              }));
                })));
  }

  void _onPlay() {
    MediaQueue.playSpiff(_spiff);
    showPlayer();
  }

  void _onDownload() {
    Downloads.downloadSpiff(_spiff);
  }

  Future<void> _onRefresh() async {
    try {
      final result = await _fetchSpiff();
      print('got $result');
      setState(() {
        _spiff = result;
      });
    } catch (error) {
      print('refresh err $error');
    }
  }
}
