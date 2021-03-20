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
import 'package:takeout_app/release.dart';

import 'music.dart';
import 'client.dart';
import 'artists.dart';
import 'style.dart';
import 'playlist.dart';
import 'downloads.dart';

class SearchWidget extends StatefulWidget {
  @override
  _SearchState createState() => _SearchState();
}

class _SearchState extends State<SearchWidget> {
  SearchView _view;
  TextEditingController _searchText = TextEditingController();

  void _onPlay() {
    MediaQueue.playTracks(_view.tracks);
  }

  void _onDownload() {
    final spiff = MediaQueue.fromTracks(_view.tracks, creator: 'Search', title: _searchText.text);
    Downloads.downloadSpiff(spiff);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: header('Search')),
        body: Column(children: [
          Container(
            padding: EdgeInsets.all(10),
            child: TextField(
              onSubmitted: _onSubmit,
              controller: _searchText,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                counterText: _view == null
                    ? null
                    : _view.hits > 0
                        ? '${_view.hits} matches'
                        : '',
                errorText: _view == null
                    ? null
                    : _view.hits == 0
                        ? 'no matches'
                        : null,
                helperText: 'text or artist:name or guitar:person',
              ),
            ),
          ),
          if (_view != null)
            Flexible(
                child: ListView(children: [
              if (_view.artists.isNotEmpty)
                Container(
                    child: Column(children: [
                  heading('Artists'),
                  _ArtistResultsWidget(_view.artists),
                ])),
              if (_view.releases.isNotEmpty)
                Container(
                    child: Column(children: [
                  heading('Releases'),
                  ReleaseListWidget(_view.releases),
                ])),
              if (_view.tracks.isNotEmpty)
                Container(
                    child: Column(children: [
                  heading('Tracks'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                          label: Text('Play'),
                          icon: Icon(Icons.play_arrow),
                          onPressed: () => _onPlay()),
                      OutlinedButton.icon(
                          label: Text('Download'),
                          icon: Icon(Icons.radio),
                          onPressed: () => _onDownload()),
                    ],
                  ),
                  TrackListWidget(_view.tracks),
                ]))
            ]))
        ]));
  }

  void _onSubmit(String q) {
    final client = Client();
    client.search(q).then((result) {
      setState(() {
        if (result.tracks == null) {
          result.tracks = [];
        }
        _view = result;
      });
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
              leading: Icon(Icons.people_alt),
              onTap: () => _onTapped(context, a),
              title: Text(a.name))))
    ]);
  }

  void _onTapped(BuildContext context, Artist artist) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => ArtistWidget(artist)));
  }
}
