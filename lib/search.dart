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

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:takeout_app/api/model.dart';
import 'package:takeout_app/app/context.dart';
import 'package:takeout_app/history/history.dart';
import 'package:takeout_app/history/model.dart';
import 'package:takeout_app/page/page.dart';
import 'package:takeout_app/podcasts.dart';
import 'package:takeout_app/release.dart';

import 'artists.dart';
import 'nav.dart';
import 'style.dart';
import 'video.dart';

class SearchWidget extends ClientPage<SearchView> {
  final _query = StringBuffer();

  SearchWidget() : super(value: SearchView.empty());

  void _onPlay(BuildContext context, SearchView view) {
    final List<Track>? tracks = view.tracks;
    if (tracks != null && tracks.length > 0) {
      // TODO need spiff to play tracks
    }
  }

  void _onDownload(BuildContext context, SearchView view) {
    // TODO need spiff to download tracks
  }

  @override
  void load(BuildContext context, {Duration? ttl}) {
    if (_query.isNotEmpty) {
      context.client.search(_query.toString(), ttl: ttl ?? Duration.zero);
    }
  }

  @override
  Widget page(BuildContext context, SearchView view) {
    print('search page $view');
    return Builder(builder: (context) {
      final history = context.watch<HistoryCubit>().state.history;
      final searches = List<SearchHistory>.from(history.searches);
      searches.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      final words = searches.map((e) => e.search);
      return Scaffold(
          appBar: AppBar(
              leading: IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context)),
              title: Autocomplete<String>(
                optionsBuilder: (editValue) {
                  final text = editValue.text;
                  if (text.isEmpty) {
                    return words;
                  } else {
                    final s = text.toLowerCase();
                    final options = LinkedHashSet<String>()
                      ..add(text)
                      ..addAll(
                          words.where((e) => e.toLowerCase().startsWith(s)))
                      ..addAll(context.search.findArtistsByName(s));
                    return options.toList();
                  }
                },
                onSelected: (value) {
                  _onSubmit(context, value);
                },
              )),
          body: Container(
              child: Column(children: [
            Flexible(
                child: ListView(children: [
              if (view.artists != null && view.artists!.isNotEmpty)
                Container(
                    child: Column(children: [
                  heading(context.strings.artistsLabel),
                  _ArtistResultsWidget(view.artists!),
                ])),
              if (view.releases != null && view.releases!.isNotEmpty)
                Container(
                    child: Column(children: [
                  heading(context.strings.releasesLabel),
                  ReleaseListWidget(view.releases!),
                ])),
              if (view.tracks != null && view.tracks!.isNotEmpty)
                Container(
                    child: Column(children: [
                  heading(context.strings.tracksLabel),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                          label: Text(context.strings.playLabel),
                          icon: Icon(Icons.play_arrow),
                          onPressed: () => _onPlay(context, view)),
                      OutlinedButton.icon(
                          label: Text(context.strings.downloadLabel),
                          icon: Icon(Icons.radio),
                          onPressed: () => _onDownload(context, view)),
                    ],
                  ),
                  TrackListWidget(view.tracks!),
                ])),
              if (view.movies != null && view.movies!.isNotEmpty)
                Container(
                    child: Column(children: [
                  heading(context.strings.moviesLabel),
                  MovieListWidget(view.movies!),
                ])),
              if (view.series != null && view.series!.isNotEmpty)
                Container(
                    child: Column(children: [
                  heading(context.strings.seriesLabel),
                  SeriesListWidget(view.series!),
                ])),
              if (view.episodes != null && view.episodes!.isNotEmpty)
                Container(
                    child: Column(children: [
                  heading(context.strings.episodesLabel),
                  EpisodeListWidget(view.episodes!),
                ])),
            ]))
          ])));
    });
  }

  void _onSubmit(BuildContext context, String q) {
    _query.clear();
    _query.write(q.trim());
    if (_query.isNotEmpty) {
      context.history.add(search: _query.toString());
      load(context);
    }
  }
}

class _ArtistResultsWidget extends StatelessWidget {
  final List<Artist> _artists;

  const _ArtistResultsWidget(this._artists);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._artists.map((a) => Container(
          child: ListTile(
              onTap: () => _onTapped(context, a), title: Text(a.name))))
    ]);
  }

  void _onTapped(BuildContext context, Artist artist) {
    push(context, builder: (_) => ArtistWidget(artist));
  }
}
