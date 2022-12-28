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
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logging/logging.dart';

import 'schema.dart';
import 'main.dart';
import 'playlist.dart';
import 'client.dart';
import 'downloads.dart';
import 'spiff.dart';
import 'style.dart';
import 'cache.dart';
import 'menu.dart';
import 'global.dart';
import 'widget.dart';

class RadioWidget extends StatefulWidget {
  final RadioView _view;

  RadioWidget(this._view);

  @override
  RadioState createState() => RadioState(_view);
}

class RadioState extends State<RadioWidget> {
  static final log = Logger('RadioState');

  RadioView _view;

  RadioState(this._view);

  List<DownloadEntry> _radioFilter(List<DownloadEntry> entries) {
    final list = List<DownloadEntry>.from(entries);
    list.retainWhere(
        (e) => e is SpiffDownloadEntry && e.spiff.playlist.creator == 'Radio');
    return list;
  }

  @override
  Widget build(BuildContext context) {
    print('radio build');

    final builder = (BuildContext) => StreamBuilder<List<DownloadEntry>>(
        stream: Downloads.downloadsSubject,
        builder: (context, snapshot) {
          List<DownloadEntry> entries = snapshot.data ?? [];
          entries = _radioFilter(entries);
          bool haveDownloads = entries.isNotEmpty;
          haveDownloads = false;
          return DefaultTabController(
              length: haveDownloads ? 5 : 4, // TODO FIXME
              child: RefreshIndicator(
                  onRefresh: () => _onRefresh(),
                  child: Scaffold(
                      appBar: AppBar(
                          title:
                              header(AppLocalizations.of(context)!.radioLabel),
                          actions: [
                            popupMenu(context, [
                              PopupItem.refresh(context, (_) => _onRefresh()),
                            ]),
                          ],
                          bottom: TabBar(
                            tabs: [
                              Tab(
                                  text: AppLocalizations.of(context)!
                                      .genresLabel),
                              Tab(
                                  text: AppLocalizations.of(context)!
                                      .decadesLabel),
                              Tab(
                                  text:
                                      AppLocalizations.of(context)!.otherLabel),
                              Tab(
                                  text: AppLocalizations.of(context)!
                                      .streamsLabel),
                              if (haveDownloads)
                                Tab(
                                    text: AppLocalizations.of(context)!
                                        .downloadsLabel)
                            ],
                          )),
                      body: TabBarView(
                        children: [
                          if (_view.genre != null) _stations(_view.genre!),
                          if (_view.period != null) _stations(_view.period!),
                          _stations(_merge(
                              _view.series != null ? _view.series! : [],
                              _view.other != null ? _view.other! : [])),
                          if (_view.stream != null) _stations(_view.stream!),
                          if (haveDownloads)
                            DownloadListWidget(filter: _radioFilter)
                        ],
                      ))));
        });
    return Navigator(
        key: radioKey,
        initialRoute: '/',
        observers: [heroController()],
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute(builder: builder, settings: settings);
        });
  }

  List<Station> _merge(List<Station> a, List<Station> b) {
    final list = a + b;
    list.sort((x, y) => x.name.compareTo(y.name));
    return list;
  }

  Widget _stations(List<Station> stations) {
    return ListView.builder(
        itemCount: stations.length,
        itemBuilder: (context, index) {
          return StreamBuilder<ConnectivityResult>(
              stream: TakeoutState.connectivityStream.distinct(),
              builder: (context, snapshot) {
                final result = snapshot.data;
                final isStream =
                    stations[index].type == "stream"; // enum for station types
                return ListTile(
                    enabled:
                        isStream ? TakeoutState.allowStreaming(result) : true,
                    onTap: () => isStream
                        ? _onStream(stations[index])
                        : _onStation(context, stations[index]),
                    leading: Icon(Icons.radio),
                    title: Text(stations[index].name),
                    trailing: isStream
                        ? Icon(Icons.play_arrow)
                        : IconButton(
                            icon: Icon(IconsDownload),
                            onPressed: TakeoutState.allowDownload(result)
                                ? () => _onDownload(context, stations[index])
                                : null));
              });
        });
  }

  void _onStream(Station station) async {
    final client = Client();
    client.station(station.id, ttl: Duration.zero).then((spiff) {
      MediaQueue.playSpiff(spiff);
      showPlayer();
    });
  }

  void _onStation(BuildContext context, Station station) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RefreshSpiffWidget(
                () => Client().station(station.id, ttl: Duration.zero))));
  }

  void _onDownload(BuildContext context, Station station) {
    Downloads.downloadStation(context, station);
  }

  Future<void> _onRefresh() async {
    try {
      final client = Client();
      final result = await client.radio(ttl: Duration.zero);
      if (mounted) {
        setState(() {
          _view = result;
        });
      }
    } catch (error) {
      log.warning(error);
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
  static final log = Logger('RefreshSpiffState');

  final Future<Spiff> Function()? _fetchSpiff;
  Spiff? _spiff;

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
          title: header(_spiff?.playlist.title ?? ''),
          actions: [
            popupMenu(context, [
              PopupItem.refresh(context, (_) => _onRefresh()),
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
                          child: StreamBuilder<CacheSnapshot>(
                              stream: MediaCache.stream(),
                              builder: (context, snapshot) {
                                final cacheSnapshot =
                                    snapshot.data ?? CacheSnapshot.empty();
                                final isCached = _spiff != null
                                    ? cacheSnapshot
                                        .containsAll(_spiff!.playlist.tracks)
                                    : false;
                                return Column(children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      OutlinedButton.icon(
                                          label: Text(
                                              AppLocalizations.of(context)!
                                                  .playLabel),
                                          icon: Icon(Icons.play_arrow),
                                          onPressed:
                                              TakeoutState.allowStreaming(
                                                      result)
                                                  ? () => _onPlay()
                                                  : null),
                                      OutlinedButton.icon(
                                          label: Text(isCached
                                              ? AppLocalizations.of(context)!
                                                  .completeLabel
                                              : AppLocalizations.of(context)!
                                                  .downloadLabel),
                                          icon: Icon(IconsDownload),
                                          onPressed:
                                              TakeoutState.allowDownload(result)
                                                  ? () => _onDownload(context)
                                                  : null),
                                    ],
                                  ),
                                  Divider(),
                                  SpiffTrackListView(_spiff!),
                                ]);
                              }));
                })));
  }

  void _onPlay() {
    MediaQueue.playSpiff(_spiff!);
    showPlayer();
  }

  void _onDownload(BuildContext context) {
    Downloads.downloadSpiff(context, _spiff!);
  }

  Future<void> _onRefresh() async {
    try {
      final result = await _fetchSpiff!();
      if (mounted) {
        setState(() {
          _spiff = result;
        });
      }
    } catch (error) {
      log.warning(error);
    }
  }
}
