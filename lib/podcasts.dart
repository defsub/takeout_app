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
import 'package:takeout_app/util.dart';
import 'package:takeout_app/widget.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'client.dart';
import 'schema.dart';
import 'cover.dart';
import 'style.dart';
import 'main.dart';
import 'downloads.dart';
import 'cache.dart';
import 'playlist.dart';
import 'global.dart';
import 'menu.dart';

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
        future: getImageBackgroundColor(context, _series.image),
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
                      : StreamBuilder<CacheSnapshot>(
                          stream: MediaCache.stream(),
                          builder: (context, snapshot) {
                            final cacheSnapshot =
                                snapshot.data ?? CacheSnapshot.empty();
                            final isCached =
                                cacheSnapshot.containsAll(_view!.episodes);
                            return CustomScrollView(slivers: [
                              SliverAppBar(
                                // actions: [ ],
                                foregroundColor: overlayIconColor(context),
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
                                          child:
                                              _playButton(context, isCached)),
                                      Align(
                                          alignment: Alignment.bottomRight,
                                          child: _downloadButton(
                                              context, isCached)),
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
                                    child: _SeriesEpisodeListWidget(
                                        _view!, backgroundColor)),
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

  Widget _playButton(BuildContext context, bool isCached) {
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(Icons.play_arrow, size: 32),
            onPressed: () => _onPlay())
        : allowStreamingIconButton(
            context, Icon(Icons.play_arrow, size: 32), _onPlay);
  }

  Widget _downloadButton(BuildContext context, bool isCached) {
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(IconsDownloadDone),
            onPressed: () => {})
        : allowDownloadIconButton(
            context, Icon(IconsDownload), () => _onDownload(context));
  }

  void _onPlay() {
    MediaQueue.play(series: _series);
    showPlayer();
  }

  void _onDownload(BuildContext context) {
    Downloads.downloadSeries(context, _series);
  }
}

class _SeriesEpisodeListWidget extends StatelessWidget {
  final SeriesView _view;
  final Color? backgroundColor;

  _SeriesEpisodeListWidget(this._view, this.backgroundColor);

  @override
  Widget build(BuildContext context) {
    _view.episodes.forEach((e) {
      e.image = _view.series.image;
      e.album = _view.series.title;
    });

    return StreamBuilder<CacheSnapshot>(
        stream: MediaCache.stream(),
        builder: (context, snapshot) {
          final cacheSnapshot = snapshot.data ?? CacheSnapshot.empty();
          final episodes = _view.episodes;
          return Column(children: [
            ...episodes.asMap().keys.toList().map((index) => ListTile(
                isThreeLine: true,
                trailing: _trailing(context, cacheSnapshot, episodes[index]),
                onTap: () => _onPlay(context, episodes[index]),
                onLongPress: () => _onEpisode(context, episodes[index], index),
                title: Text(episodes[index].title),
                subtitle: _subtitle(context, cacheSnapshot, episodes[index])))
          ]);
        });
  }

  Widget _subtitle(
      BuildContext context, CacheSnapshot snapshot, Episode episode) {
    final children = <Widget>[];
    final remaining = snapshot.remaining(episode);
    if (remaining != null && remaining.inSeconds > 0) {
      final value = snapshot.value(episode);
      if (value != null) {
        children.add(LinearProgressIndicator(value: value));
      }
    }
    children.add(RelativeDateWidget.from(episode.date, prefix: episode.author));
    return Column(
        children: children, crossAxisAlignment: CrossAxisAlignment.start);
  }

  Widget? _trailing(
      BuildContext context, CacheSnapshot snapshot, Episode episode) {
    final downloading = snapshot.downloadSnapshot(episode);
    if (downloading != null) {
      final value = downloading.value;
      return value > 1.0
          ? CircularProgressIndicator()
          : CircularProgressIndicator(value: value);
    }
    return snapshot.contains(episode) ? Icon(IconsCached) : null;
  }

  // void _onCache(BuildContext context, bool isCached, Episode episode) {
  //   if (isCached) {
  //     Downloads.deleteEpisode(episode);
  //   } else {
  //     Downloads.downloadSeriesEpisode(_view.series, episode);
  //   }
  // }

  void _onEpisode(BuildContext context, Episode episode, int index) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _EpisodeWidget(episode, _view.series.title,
                backgroundColor: backgroundColor)));
  }

  void _onPlay(BuildContext context, Episode episode) {
    MediaQueue.play(episode: episode);
    showPlayer();
  }
}

class _EpisodeWidget extends StatelessWidget {
  final Episode episode;
  final String title;
  final Color? backgroundColor;

  _EpisodeWidget(this.episode, this.title, {this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    final padding = const EdgeInsets.all(16);
    return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text(title),
          actions: [
            popupMenu(context, [
              // TODO this shows delete when there's nothing to delete
              PopupItem.delete(
                  context,
                  AppLocalizations.of(context)!.deleteItem,
                  (ctx) => _onDelete(ctx)),
            ])
          ],
        ),
        body: StreamBuilder<CacheSnapshot>(
            stream: MediaCache.stream(),
            builder: (context, snapshot) {
              final cacheSnapshot = snapshot.data ?? CacheSnapshot.empty();
              final when = cacheSnapshot.when(episode);
              final duration = cacheSnapshot.duration(episode);
              final remaining = cacheSnapshot.remaining(episode);
              final isCached = cacheSnapshot.contains(episode);
              var title = episode.creator;
              var subtitle = merge([
                ymd(episode.date),
                if (duration != null) duration.inHoursMinutes
              ]);
              return Container(
                child: Column(
                  children: [
                    Container(
                        padding: padding,
                        alignment: Alignment.centerLeft,
                        child: Text(episode.title,
                            style: Theme.of(context).textTheme.titleLarge)),
                    ListTile(
                      title: Text(title, overflow: TextOverflow.ellipsis),
                      subtitle: Text(subtitle, overflow: TextOverflow.ellipsis),
                      trailing: _downloadButton(context, cacheSnapshot),
                    ),
                    _progress(cacheSnapshot) ?? SizedBox(),
                    Expanded(child: _episodeDetail()),
                    ListTile(
                      title: remaining != null
                          ? Text(
                              '${remaining.inHoursMinutes} remaining') // TODO intl
                          : SizedBox(),
                      subtitle: remaining != null
                          ? RelativeDateWidget(when!)
                          : SizedBox(),
                      leading: _playButton(context, isCached),
                    ),
                  ],
                ),
              );
            }));
  }

  Widget? _progress(CacheSnapshot snapshot) {
    final remaining = snapshot.remaining(episode);
    if (remaining != null && remaining.inSeconds > 0) {
      final value = snapshot.value(episode);
      if (value != null) {
        return LinearProgressIndicator(value: value);
      }
    }
    return null;
  }

  Widget _episodeDetail() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            print('progress $progress');
          },
          onPageStarted: (String url) {
            print('started $url');
          },
          onPageFinished: (String url) {
            print('finished $url');
          },
          onWebResourceError: (WebResourceError error) {
            print(error);
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );

    final view = WebViewWidget(controller: controller);
    // TODO consider changing CSS font colors based on theme
    controller.loadHtmlString("""<!DOCTYPE html>
    <html>
      <head><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
      <body style='"margin: 0; padding: 0;'>
        <div>
          ${episode.description}
        </div>
      </body>
    </html>""");

    return view;
  }

  Widget _downloadButton(BuildContext context, CacheSnapshot cacheSnapshot) {
    final downloading = cacheSnapshot.downloadSnapshot(episode);
    if (downloading != null) {
      final value = downloading.value;
      return value > 1.0
          ? CircularProgressIndicator()
          : CircularProgressIndicator(value: value);
    }
    final isCached = cacheSnapshot.contains(episode);
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(IconsDownloadDone),
            onPressed: () => {})
        : allowDownloadIconButton(
            context, Icon(IconsDownload), () => _onDownload(context));
  }

  void _onDownload(BuildContext context) {
    Downloads.downloadEpisode(episode);
  }

  Widget _playButton(BuildContext context, bool isCached) {
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(Icons.play_arrow, size: 36),
            onPressed: () => _onPlay(context))
        : allowStreamingIconButton(
            context, Icon(Icons.play_arrow, size: 36), () => _onPlay(context));
  }

  void _onPlay(BuildContext context) {
    print('play $episode');
    MediaQueue.play(episode: episode);
    showPlayer();
  }

  void _onDelete(BuildContext context) {
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.confirmDelete),
            content: Text(AppLocalizations.of(context)!.deleteEpisode),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    Text(MaterialLocalizations.of(context).cancelButtonLabel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _onDeleteConfirmed();
                },
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          );
        });
  }

  void _onDeleteConfirmed() async {
    Downloads.deleteEpisode(episode);
  }
}

class SeriesListWidget extends StatelessWidget {
  final List<Series> _list;

  SeriesListWidget(this._list);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._list.asMap().keys.toList().map((index) => ListTile(
          onTap: () => _onTapped(context, _list[index]),
          leading: tileCover(_list[index].image),
          subtitle: Text(
              merge([
                ymd(_list[index].date),
                _list[index].author,
              ]),
              overflow: TextOverflow.ellipsis),
          title: Text(_list[index].title)))
    ]);
  }

  void _onTapped(BuildContext context, Series series) {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => SeriesWidget(series)));
  }
}

class EpisodeListWidget extends StatelessWidget {
  final List<Episode> _list;

  EpisodeListWidget(this._list);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._list.asMap().keys.toList().map((index) => ListTile(
          onTap: () => _onTapped(context, _list[index]),
          leading: tilePodcast(_list[index].image),
          subtitle: Text(
              merge([
                ymd(_list[index].date),
                _list[index].author,
              ]),
              overflow: TextOverflow.ellipsis),
          title: Text(_list[index].title)))
    ]);
  }

  void _onTapped(BuildContext context, Episode episode) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _EpisodeWidget(episode, ""))); // TODO need title
  }
}
