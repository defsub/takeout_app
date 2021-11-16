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
import 'package:flutter/rendering.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:takeout_app/release.dart';

import 'schema.dart';
import 'client.dart';
import 'artists.dart';
import 'style.dart';
import 'playlist.dart';
import 'downloads.dart';
import 'video.dart';

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

  void _onDownload() {
    final List<Track>? tracks = _view!.tracks;
    if (tracks != null && tracks.length > 0) {
      final spiff = MediaQueue.fromTracks(tracks,
          creator: 'Search', title: _searchText.text);
      Downloads.downloadSpiff(spiff);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    return Scaffold(
        appBar:
            AppBar(title: header(AppLocalizations.of(context)!.searchLabel)),
        body: Column(children: [
          Container(
            padding: EdgeInsets.all(10),
            child: TextField(
              onSubmitted: _onSubmit,
              controller: _searchText,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                counterText: view == null
                    ? null
                    : AppLocalizations.of(context)!.matchCount(view.hits),
                errorText: view == null
                    ? null
                    : view.hits == 0
                        ? AppLocalizations.of(context)!.matchCount(view.hits)
                        : null,
                helperText: AppLocalizations.of(context)!.searchHelperText,
              ),
            ),
          ),
          if (view != null)
            Flexible(
                child: ListView(children: [
              if (view.artists != null && view.artists!.isNotEmpty)
                Container(
                    child: Column(children: [
                  heading(AppLocalizations.of(context)!.artistsLabel),
                  _ArtistResultsWidget(view.artists!),
                ])),
              if (view.releases != null && view.releases!.isNotEmpty)
                Container(
                    child: Column(children: [
                  heading(AppLocalizations.of(context)!.releasesLabel),
                  ReleaseListWidget(view.releases!),
                ])),
              if (view.tracks != null && view.tracks!.isNotEmpty)
                Container(
                    child: Column(children: [
                  heading(AppLocalizations.of(context)!.tracksLabel),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                          label: Text(AppLocalizations.of(context)!.playLabel),
                          icon: Icon(Icons.play_arrow),
                          onPressed: () => _onPlay()),
                      OutlinedButton.icon(
                          label:
                              Text(AppLocalizations.of(context)!.downloadLabel),
                          icon: Icon(Icons.radio),
                          onPressed: () => _onDownload()),
                    ],
                  ),
                  TrackListWidget(view.tracks!),
                ])),
              if (view.movies != null && view.movies!.isNotEmpty)
                Container(
                    child: Column(children: [
                  heading(AppLocalizations.of(context)!.moviesLabel),
                  MovieListWidget(view.movies!),
                ])),
            ]))
        ]));
  }

  void _onSubmit(String q) {
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
