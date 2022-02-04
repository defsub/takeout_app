// Copyright (C) 2022 The Takeout Authors.
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

import 'dart:async';

import 'package:flutter/material.dart';

import 'client.dart';
import 'schema.dart';
import 'cover.dart';
import 'style.dart';
import 'main.dart';
import 'downloads.dart';
import 'cache.dart';
import 'playlist.dart';
import 'global.dart';
import 'util.dart';

class SeriesWidget extends StatefulWidget {
  final Series _series;

  SeriesWidget(this._series);

  @override
  _SeriesWidgetState createState() => _SeriesWidgetState(_series);
}

class _SeriesWidgetState extends State<SeriesWidget> {
  final Series _series;
  SeriesView? _view;

  _SeriesWidgetState(this._series);

  @override
  void initState() {
    super.initState();
    final client = Client();
    client.series(_series.id).then((v) => _onSeriesUpdated(v));
  }

  void _onSeriesUpdated(SeriesView view) {
    if (mounted) {
      setState(() {
        _view = view;
        print(_view);
      });
    }
  }

  Future<void> _onRefresh() async {
    final client = Client();
    await client
        .series(_series.id, ttl: Duration.zero)
        .then((v) => _onSeriesUpdated(v));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Color?>(
        future: getImageBackgroundColor(_series.image),
        builder: (context, snapshot) {
          final backgroundColor = snapshot.data;
          final screen = MediaQuery.of(context).size;
          final expandedHeight = screen.height / 2;
          return Scaffold(
              backgroundColor: backgroundColor,
              body: RefreshIndicator(
                  onRefresh: () => _onRefresh(),
                  child: _view == null
                      ? Center(child: CircularProgressIndicator())
                      : StreamBuilder<Set<String>>(
                          stream: TrackCache.keysSubject,
                          builder: (context, snapshot) {
                            final keys = snapshot.data ?? Set<String>();
                            final isCached =
                                TrackCache.checkAll(keys, _view!.episodes);
                            return CustomScrollView(slivers: [
                              SliverAppBar(
                                // actions: [ ],
                                expandedHeight: expandedHeight,
                                flexibleSpace: FlexibleSpaceBar(
                                    // centerTitle: true,
                                    // title: Text(release.name, style: TextStyle(fontSize: 15)),
                                    stretchModes: [
                                      StretchMode.zoomBackground,
                                      StretchMode.fadeTitle
                                    ],
                                    background:
                                        Stack(fit: StackFit.expand, children: [
                                      releaseSmallCover(_series.image),
                                      const DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment(0.0, 0.75),
                                            end: Alignment(0.0, 0.0),
                                            colors: <Color>[
                                              Color(0x60000000),
                                              Color(0x00000000),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Align(
                                          alignment: Alignment.bottomLeft,
                                          child: _playButton(isCached)),
                                      Align(
                                          alignment: Alignment.bottomRight,
                                          child: _downloadButton(isCached)),
                                    ])),
                              ),
                              SliverToBoxAdapter(
                                  child: Container(
                                      padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
                                      child: Column(children: [
                                        _title(),
                                      ]))),
                              if (_view != null)
                                SliverToBoxAdapter(
                                    child: _EpisodeListWidget(_view!)),
                            ]);
                          })));
        });
  }

  Widget _title() {
    return Container(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
        child:
            Text(_series.title, style: Theme.of(context).textTheme.headline5));
  }

  Widget _playButton(bool isCached) {
    if (isCached) {
      return IconButton(
          icon: Icon(Icons.play_arrow, size: 32), onPressed: () => _onPlay());
    }
    return allowStreamingIconButton(Icon(Icons.play_arrow, size: 32), _onPlay);
  }

  Widget _downloadButton(bool isCached) {
    if (isCached) {
      return IconButton(icon: Icon(IconsDownloadDone), onPressed: () => {});
    }
    return allowDownloadIconButton(Icon(IconsDownload), _onDownload);
  }

  void _onPlay() {
    MediaQueue.play(series: _series);
    showPlayer();
  }

  void _onDownload() {
    Downloads.downloadSeries(_series);
  }
}

class _EpisodeListWidget extends StatelessWidget {
  final SeriesView _view;

  _EpisodeListWidget(this._view);

  @override
  Widget build(BuildContext context) {
    _view.episodes.forEach((e) {
      e.image = _view.series.image;
      e.album = _view.series.title;
    });

    return StreamBuilder<Set<String>>(
        stream: TrackCache.keysSubject,
        builder: (context, snapshot) {
          final keys = snapshot.data ?? Set<String>();
          final episodes = _view.episodes;
          return Column(children: [
            ...episodes.asMap().keys.toList().map((index) => ListTile(
                trailing: IconButton(
                    icon: Icon(keys.contains(episodes[index].key)
                        ? IconsCached
                        : IconsDownload),
                    onPressed: () => _onCache(context,
                        keys.contains(episodes[index].key), episodes[index])),
                onTap: () => _onEpisode(context, episodes[index], index),
                title: Text(episodes[index].title),
                subtitle: Text(
                    '${episodes[index].author} \u2022 ${relativeDate(episodes[index].date)}')))
          ]);
        });
  }

  void _onCache(BuildContext context, bool isCached, Episode episode) {
    if (isCached) {
      Downloads.deleteEpisode(episode);
    } else {
      Downloads.downloadSeriesEpisode(_view.series, episode);
    }
  }

  void _onEpisode(BuildContext context, Episode episode, int index) {
    print('index is $index');
    MediaQueue.play(series: _view.series, index: index);
    showPlayer();
  }
}
