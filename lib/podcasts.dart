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

import 'package:flutter/material.dart';
import 'package:takeout_app/buttons.dart';
import 'package:takeout_app/cache/offset.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:takeout_app/app/context.dart';
import 'package:takeout_app/art/builder.dart';
import 'package:takeout_app/art/cover.dart';
import 'package:takeout_app/api/model.dart';
import 'package:takeout_app/client/download.dart';
import 'package:takeout_app/cache/track.dart';
import 'package:takeout_app/page/page.dart';
import 'package:takeout_app/util.dart';

import 'style.dart';
import 'playlist.dart';
import 'global.dart';
import 'menu.dart';
import 'tiles.dart';

class SeriesWidget extends ClientPage<SeriesView> {
  final Series _series;

  SeriesWidget(this._series);

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.series(_series.id, ttl: ttl);
  }

  @override
  Widget page(BuildContext context, SeriesView view) {
    return FutureBuilder<Color?>(
        future: getImageBackgroundColor(context, _series.image),
        builder: (context, snapshot) {
          final backgroundColor = snapshot.data;
          final screen = MediaQuery.of(context).size;
          final expandedHeight = screen.height / 2;
          return Scaffold(
              backgroundColor: backgroundColor,
              body: RefreshIndicator(
                  onRefresh: () => refreshPage(context),
                  child: BlocBuilder<TrackCacheCubit, TrackCacheState>(
                      builder: (context, state) {
                    final isCached = state.containsAll(view.episodes);
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
                            background: Stack(fit: StackFit.expand, children: [
                              releaseSmallCover(context, _series.image),
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
                                  child: _playButton(context, isCached)),
                              Align(
                                  alignment: Alignment.bottomRight,
                                  child: _downloadButton(context, isCached)),
                            ])),
                      ),
                      SliverToBoxAdapter(
                          child: Container(
                              padding: EdgeInsets.fromLTRB(4, 16, 4, 4),
                              child: Column(children: [
                                _title(context),
                              ]))),
                      SliverToBoxAdapter(
                          child:
                              _SeriesEpisodeListWidget(view, backgroundColor)),
                    ]);
                  })));
        });
  }

  Widget _title(BuildContext context) {
    return Container(
        padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: Text(_series.title,
            style: Theme.of(context).textTheme.headlineSmall));
  }

  Widget _playButton(BuildContext context, bool isCached) {
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(Icons.play_arrow, size: 32),
            onPressed: () => _onPlay(context))
        : StreamingButton(onPressed: () => _onPlay(context));
  }

  Widget _downloadButton(BuildContext context, bool isCached) {
    return isCached
        ? IconButton(
            color: overlayIconColor(context),
            icon: Icon(IconsDownloadDone),
            onPressed: () => {})
        : DownloadButton(onPressed: () => _onDownload(context));
  }

  void _onPlay(BuildContext context) {
    // MediaQueue.play(context, series: _series);
    // showPlayer();
  }

  void _onDownload(BuildContext context) {
    // Downloads.downloadSeries(context, _series);
  }
}

class _SeriesEpisodeListWidget extends StatelessWidget {
  final SeriesView _view;
  final Color? backgroundColor;

  const _SeriesEpisodeListWidget(this._view, this.backgroundColor);

  @override
  Widget build(BuildContext context) {
    final episodes = List<Episode>.from(_view.episodes.map((e) =>
        e.copyWith(album: _view.series.title, image: _view.series.image)));
    return BlocBuilder<DownloadCubit, DownloadState>(builder: (context, state) {
      return Column(children: [
        ...episodes.asMap().keys.toList().map((index) => ListTile(
            isThreeLine: true,
            trailing: _trailing(context, state, episodes[index]),
            onTap: () => _onPlay(context, episodes[index]),
            onLongPress: () => _onEpisode(context, episodes[index], index),
            title: Text(episodes[index].title),
            subtitle: _subtitle(context, episodes[index])))
      ]);
    });
  }

  Widget _subtitle(BuildContext context, Episode episode) {
    return Builder(builder: (context) {
      final offsets = context.watch<OffsetCacheCubit>();
      final children = <Widget>[];
      final remaining = offsets.state.remaining(episode);
      if (remaining != null && remaining.inSeconds > 0) {
        final value = offsets.state.value(episode);
        if (value != null) {
          children.add(LinearProgressIndicator(value: value));
        }
      }
      children
          .add(RelativeDateWidget.from(episode.date, prefix: episode.author));
      return Column(
          children: children, crossAxisAlignment: CrossAxisAlignment.start);
    });
  }

  Widget? _trailing(
      BuildContext context, DownloadState state, Episode episode) {
    final progress = state.progress(episode);
    return (progress != null)
        ? CircularProgressIndicator(value: progress.value)
        : Icon(context.trackCache.state.contains(episode) ? IconsCached : null);
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
    // MediaQueue.play(context, episode: episode);
    // showPlayer();
  }
}

class _EpisodeWidget extends StatelessWidget {
  final Episode episode;
  final String title;
  final Color? backgroundColor;

  const _EpisodeWidget(this.episode, this.title, {this.backgroundColor});

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
        body: BlocBuilder<OffsetCacheCubit, OffsetCacheState>(
            builder: (context, state) {
          final when = state.when(episode);
          final duration = state.duration(episode);
          final remaining = state.remaining(episode);
          final isCached = state.contains(episode);
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
                  trailing: _downloadButton(context),
                ),
                _progress(state) ?? SizedBox.shrink(),
                Expanded(child: _episodeDetail()),
                ListTile(
                  title: remaining != null
                      ? Text(
                          '${remaining.inHoursMinutes} remaining') // TODO intl
                      : SizedBox.shrink(),
                  subtitle: remaining != null
                      ? RelativeDateWidget(when!)
                      : SizedBox.shrink(),
                  leading: _playButton(context, isCached),
                ),
              ],
            ),
          );
        }));
  }

  Widget? _progress(OffsetCacheState state) {
    final remaining = state.remaining(episode);
    if (remaining != null && remaining.inSeconds > 0) {
      final value = state.value(episode);
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

  Widget _downloadButton(BuildContext context) {
    return Builder(builder: (context) {
      final downloads = context.watch<DownloadCubit>();
      final cache = context.watch<TrackCacheCubit>();

      final download = downloads.state.get(episode);
      if (download != null) {
        final value = download.progress?.value ?? 0.0;
        return value > 1.0
            ? CircularProgressIndicator()
            : CircularProgressIndicator(value: value);
      }
      final isCached = cache.state.contains(episode);
      return isCached
          ? IconButton(
              color: overlayIconColor(context),
              icon: Icon(IconsDownloadDone),
              onPressed: () => {})
          : DownloadButton(onPressed: () => _onDownload(context));
    });
  }

  void _onDownload(BuildContext context) {
    // Downloads.downloadEpisode(episode);
  }

  Widget _playButton(BuildContext context, bool isCached) {
    return isCached
        ? PlayButton(onPressed: () => _onPlay(context))
        : StreamingButton(onPressed: () => _onPlay(context));
  }

  void _onPlay(BuildContext context) {
    print('play $episode');
    // MediaQueue.play(context, episode: episode);
    // showPlayer();
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
    // Downloads.deleteEpisode(episode);
  }
}

class SeriesListWidget extends StatelessWidget {
  final List<Series> _list;

  const SeriesListWidget(this._list);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._list.asMap().keys.toList().map((index) => ListTile(
          onTap: () => _onTapped(context, _list[index]),
          leading: tileCover(context, _list[index].image),
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

  const EpisodeListWidget(this._list);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._list.asMap().keys.toList().map((index) => ListTile(
          onTap: () => _onTapped(context, _list[index]),
          leading: tilePodcast(context, _list[index].image),
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
