// Copyright (C) 2023 The Takeout Authors.
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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:takeout_lib/api/model.dart';
import 'package:takeout_lib/art/cover.dart';
import 'package:takeout_lib/cache/offset.dart';
import 'package:takeout_lib/page/page.dart';
import 'package:takeout_lib/util.dart';
import 'package:takeout_watch/app/context.dart';
import 'package:takeout_watch/player.dart';

class PodcastsPage extends StatelessWidget {
  final HomeView state;

  const PodcastsPage(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    return SeriesGrid(state.newSeries ?? []);
  }
}

class SeriesGrid extends StatelessWidget {
  final List<Series> series;

  const SeriesGrid(this.series, {super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
      ),
      itemCount: series.length,
      itemBuilder: (context, index) {
        return SeriesGridTile(series[index]);
      },
    );
  }
}

class SeriesGridTile extends StatelessWidget {
  final Series series;

  const SeriesGridTile(this.series, {super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return GestureDetector(
        onTap: () => onSeries(context),
        child: GridTile(
            footer: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                child: GridTileBar(
                  backgroundColor: Colors.black26,
                  title: Center(
                      child:
                          Text(series.title, overflow: TextOverflow.ellipsis)),
                  subtitle: Center(
                      child: Text(series.creator,
                          overflow: TextOverflow.ellipsis)),
                )),
            child:
                circleCover(context, series.image, radius: media.size.width) ??
                    const SizedBox.shrink()));
  }

  void onSeries(BuildContext context) {
    Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => SeriesPage(series)));
  }
}

class SeriesPage extends ClientPage<SeriesView> {
  final Series series;

  SeriesPage(this.series, {super.key});

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.series(series.id);
  }

  @override
  Widget page(BuildContext context, SeriesView state) {
    final offsets = context.watch<OffsetCacheCubit>().state;
    final episodes = state.episodes;
    return Scaffold(
        body: RefreshIndicator(
            onRefresh: () => reloadPage(context),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                    automaticallyImplyLeading: false,
                    floating: true,
                    title: Center(
                        child: Text(series.title,
                            overflow: TextOverflow.ellipsis))),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        episodeTile(context, episodes[index], offsets),
                    childCount: episodes.length,
                  ),
                )
              ],
            )));
  }

  Widget episodeTile(
      BuildContext context, Episode episode, OffsetCacheState offsets) {
    List<String> subtitle = [];
    final remaining = offsets.remaining(episode);
    if (remaining != null) {
      subtitle.add('${remaining.inHoursMinutes} remaining');
    }
    subtitle.add(ymd(episode.date));
    return ListTile(
        title:
            Center(child: Text(episode.title, overflow: TextOverflow.ellipsis)),
        subtitle:
            Center(child: Text(merge(subtitle), overflow: TextOverflow.ellipsis)),
        onTap: () => onEpisode(context, episode));
  }

  void onEpisode(BuildContext context, Episode episode) {
    context.playlist.replace(episode.reference);
    showPlayer(context);
  }
}
