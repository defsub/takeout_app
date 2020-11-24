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

import 'package:json_annotation/json_annotation.dart';
import 'package:takeout_app/client.dart';

part 'spiff.g.dart';

@JsonSerializable()
class Spiff {
  final int index;
  final double position;
  final Playlist playlist;

  Spiff({this.index, this.position, this.playlist});

  factory Spiff.fromJson(Map<String, dynamic> json) => _$SpiffFromJson(json);

  Map<String, dynamic> toJson() => _$SpiffToJson(this);

  Spiff copyWith({
    int index,
    double position,
  }) =>
      Spiff(
        index: index ?? this.index,
        position: position ?? this.position,
        playlist: playlist ?? this.playlist,
      );

  static Spiff empty() =>
      Spiff(index: -1, position: 0, playlist: Playlist(title: '', tracks: []));
}

@JsonSerializable()
class Entry extends Locatable {
  final String creator;
  final String album;
  final String title;
  final String image;
  @JsonKey(name: 'location')
  final List<String> locations;
  final List<String> identifier;

  Entry(
      {this.creator,
      this.album,
      this.title,
      this.image,
      this.locations,
      this.identifier});

  factory Entry.fromJson(Map<String, dynamic> json) => _$EntryFromJson(json);

  Map<String, dynamic> toJson() => _$EntryToJson(this);

  @override
  String get key {
    final etag = identifier[0];
    return etag.replaceAll(new RegExp(r'"'), '');
  }

  @override
  String get location {
    return locations[0];
  }
}

@JsonSerializable()
class Playlist {
  final String title;
  @JsonKey(name: 'track')
  final List<Entry> tracks;

  Playlist({this.title, this.tracks});

  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);

  Map<String, dynamic> toJson() => _$PlaylistToJson(this);
}
