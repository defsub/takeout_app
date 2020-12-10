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

class RadioWidget extends StatefulWidget {
  final RadioView _view;

  RadioWidget(this._view);

  @override
  RadioState createState() => RadioState(_view);
}

class RadioState extends State<RadioWidget> {
  RadioView _view;

  RadioState(this._view);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 4,
        child: RefreshIndicator(
            onRefresh: () => _onRefresh(),
            child: Scaffold(
                appBar: AppBar(
                    title: Text('Radio'),
                    bottom: TabBar(
                      tabs: [
                        Tab(text: 'Genres'),
                        Tab(text: 'Similar'),
                        Tab(text: 'Artists'),
                        Tab(text: 'Decades'),
                      ],
                    )),
                body: TabBarView(
                  children: [
                    _stations(_view.genre),
                    _stations(_view.similar),
                    _stations(_view.artist),
                    _stations(_view.period),
                  ],
                ))));
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
        appBar: AppBar(title: header(_spiff?.playlist?.title ?? '')),
        body: RefreshIndicator(
            onRefresh: () => _onRefresh(),
            child: StreamBuilder<ConnectivityResult>(
                stream: TakeoutState.connectivityStream.distinct(),
                builder: (context, snapshot) {
                  final result = snapshot.data;
                  return (_spiff == null)
                      ? Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          child: Column(children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                  icon: Icon(Icons.playlist_play),
                                  onPressed: TakeoutState.allowStreaming(result)
                                      ? () => _onPlay()
                                      : null),
                              IconButton(
                                  icon: Icon(Icons.cloud_download_outlined),
                                  onPressed: TakeoutState.allowDownload(result)
                                      ? () => _onDownload()
                                      : null),
                            ],
                          ),
                          Divider(),
                          SpiffTrackListView(_spiff),
                        ]));
                })));
  }

  void _onPlay() {
    MediaQueue.playSpiff(_spiff);
  }

  void _onDownload() {
    Downloads.downloadSpiff(_spiff);
  }

  Future<void> _onRefresh() async {
    try {
      final result = await _fetchSpiff();
      setState(() {
        _spiff = result;
      });
    } catch (error) {
      print('refresh err $error');
    }
  }
}
