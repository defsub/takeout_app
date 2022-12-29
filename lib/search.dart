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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:takeout_app/release.dart';

import 'schema.dart';
import 'client.dart';
import 'artists.dart';
import 'style.dart';
import 'playlist.dart';
import 'downloads.dart';
import 'video.dart';
import 'global.dart';
import 'history.dart';

class SearchWidget extends StatefulWidget {
  @override
  _SearchState createState() => _SearchState();
}

class _SearchState extends State<SearchWidget> {
  SearchView? _view;
  TextEditingController _searchText = TextEditingController();

  void _onPlay() {
    final List<Track>? tracks = _view!.tracks;
    if (tracks != null && tracks.length > 0) {
      MediaQueue.playTracks(tracks);
    }
  }

  void _onDownload(BuildContext context) {
    final List<Track>? tracks = _view!.tracks;
    if (tracks != null && tracks.length > 0) {
      final spiff = MediaQueue.fromTracks(tracks,
          creator: 'Search', title: _searchText.text);
      Downloads.downloadSpiff(context, spiff);
    }
  }

  @override
  Widget build(BuildContext context) {
    History.instance; // TODO start load
    final builder = (BuildContext) => StreamBuilder<History>(
        stream: History.stream,
        builder: (ctx, snapshot) {
          final history = snapshot.data;
          final searches =
              history != null ? history.searches : <SearchHistory>[];
          searches.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          final words = searches.map((e) => e.search);
          final artists = artistMap.keys.toList();
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
                          ..addAll(artists
                              .where((e) => e.toLowerCase().contains(s)));
                        return options.toList();
                      }
                    },
                    onSelected: (value) {
                      _onSubmit(value);
                    },
                  )),
              body: Container(
                  child: Column(children: [
                if (_view != null)
                  Flexible(
                      child: ListView(children: [
                    if (_view!.artists != null && _view!.artists!.isNotEmpty)
                      Container(
                          child: Column(children: [
                        heading(AppLocalizations.of(context)!.artistsLabel),
                        _ArtistResultsWidget(_view!.artists!),
                      ])),
                    if (_view!.releases != null && _view!.releases!.isNotEmpty)
                      Container(
                          child: Column(children: [
                        heading(AppLocalizations.of(context)!.releasesLabel),
                        ReleaseListWidget(_view!.releases!),
                      ])),
                    if (_view!.tracks != null && _view!.tracks!.isNotEmpty)
                      Container(
                          child: Column(children: [
                        heading(AppLocalizations.of(context)!.tracksLabel),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            OutlinedButton.icon(
                                label: Text(
                                    AppLocalizations.of(context)!.playLabel),
                                icon: Icon(Icons.play_arrow),
                                onPressed: () => _onPlay()),
                            OutlinedButton.icon(
                                label: Text(AppLocalizations.of(context)!
                                    .downloadLabel),
                                icon: Icon(Icons.radio),
                                onPressed: () => _onDownload(context)),
                          ],
                        ),
                        TrackListWidget(_view!.tracks!),
                      ])),
                    if (_view!.movies != null && _view!.movies!.isNotEmpty)
                      Container(
                          child: Column(children: [
                        heading(AppLocalizations.of(context)!.moviesLabel),
                        MovieListWidget(_view!.movies!),
                      ])),
                  ]))
              ])));
        });
    return Navigator(
        key: searchKey,
        initialRoute: '/',
        observers: [heroController()],
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute(builder: builder, settings: settings);
        });
  }

  void _onSubmit(String q) {
    q = q.trim();
    History.instance.then((history) => history.add(search: q));
    final client = Client();
    client.search(q).then((result) {
      if (mounted) {
        setState(() {
          _view = result;
        });
      }
    });
  }
}

class _ArtistResultsWidget extends StatelessWidget {
  final List<Artist> _artists;

  _ArtistResultsWidget(this._artists);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ..._artists.map((a) => Container(
          child: ListTile(
              onTap: () => _onTapped(context, a), title: Text(a.name))))
    ]);
  }

  void _onTapped(BuildContext context, Artist artist) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => ArtistWidget(artist)));
  }
}
