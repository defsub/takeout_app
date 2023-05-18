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
import 'package:takeout_lib/api/model.dart';
import 'package:takeout_lib/page/page.dart';
import 'package:takeout_watch/app/context.dart';
import 'package:takeout_watch/player.dart';

class RadioPage extends ClientPage<RadioView> {
  RadioPage({super.key});

  @override
  void load(BuildContext context, {Duration? ttl}) {
    context.client.radio();
  }

  @override
  Widget page(BuildContext context, RadioView state) {
    return Scaffold(
        appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Center(
                child: Text('Radio', overflow: TextOverflow.ellipsis))),
        body: RefreshIndicator(
            onRefresh: () => reloadPage(context),
            child: Center(
                child: ListView(shrinkWrap: true, children: [
                  if (state.genre != null)
                    tile(context, 'Genres', state.genre ?? []),
                  if (state.period != null)
                    tile(context, 'Decades', state.period ?? []),
                  if (state.other != null)
                    tile(context, 'Other', state.other ?? []),
                  if (state.stream != null)
                    tile(context, 'Streams', state.stream ?? []),
                ]))));
  }

  Widget tile(BuildContext context, String title, List<Station> stations) {
    return ListTile(
        title: Center(child: Text(title)),
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => stationsPage(title, stations)));
        });
  }

  Widget stationsPage(String title, List<Station> stations) {
    return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
                automaticallyImplyLeading: false,
                floating: true,
                title: Center(child: Text(title, overflow: TextOverflow.ellipsis))),
            SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return stationTile(context, stations[index]);
                }, childCount: stations.length))
          ],
        ));
  }

  Widget stationTile(BuildContext context, Station station) {
    return ListTile(
        title: Center(child: Text(station.name)),
        onTap: () => onStation(context, station));
  }

  void onStation(BuildContext context, Station station) {
    context.playlist.replace(station.reference);
    showPlayer(context);
  }
}
