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

import 'music.dart';
import 'playlist.dart';

class RadioWidget extends StatelessWidget {
  final RadioView _view;

  RadioWidget(this._view);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: const Text('Stations')),
        body: Column(children: [
          Expanded(
              child: ListView.builder(
            itemCount: _view.genre.length,
            itemBuilder: (context, index) {
              return ListTile(
                onTap: () => _onPlay(_view.genre[index]),
                leading: Icon(Icons.radio),
                title: Text(_view.genre[index].name),
                trailing: IconButton(
                    icon: Icon(Icons.download_sharp),
                    onPressed: () => _onPlay(_view.genre[index])),
              );
            },
          ))
        ]));
  }

  void _onPlay(Station station) {
    var playlist = PlaylistFacade();
    playlist.play(station: station);
  }
}
