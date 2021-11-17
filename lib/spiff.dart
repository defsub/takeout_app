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

import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:takeout_app/client.dart';

import 'model.dart';

part 'spiff.g.dart';

@JsonSerializable()
class Spiff {
  final int index;
  final double position;
  final Playlist playlist;

  Spiff({required this.index, required this.position, required this.playlist});

  int get size {
    return playlist.tracks.fold(0, (sum, t) => sum + t.size);
  }

  @override
  bool operator ==(other) {
    if (other is Spiff) {
      return playlist.title == other.playlist.title &&
          playlist.creator == other.playlist.creator &&
          playlist.location == other.playlist.location &&
          playlist.image == other.playlist.image &&
          playlist.tracks.length == other.playlist.tracks.length &&
          listEquals(playlist.tracks, other.playlist.tracks);
    }
    return false;
  }

  @override
  int get hashCode {
    return super.hashCode;
  }

  bool isLocal() {
    return playlist.location?.startsWith(RegExp(r'^file')) ?? false;
  }

  bool isRemote() {
    return playlist.location?.startsWith(RegExp(r'^http')) ?? false;
  }

  bool isMusic() {
    // TODO music or video based on URI
    return playlist.tracks.every((e) => e.location.startsWith("/api/tracks/"));
  }

  bool isVideo() {
    // TODO music or video based on URI
    return playlist.tracks.every((e) => e.location.startsWith("/api/movies/"));
  }

  MediaType get mediaType {
    return isMusic()
        ? MediaType.music
        : isVideo()
            ? MediaType.video
            : MediaType.music; // TODO
  }

  factory Spiff.fromJson(Map<String, dynamic> json) => _$SpiffFromJson(json);

  Map<String, dynamic> toJson() => _$SpiffToJson(this);

  Spiff copyWith({
    int? index,
    double? position,
    Playlist? playlist,
  }) =>
      Spiff(
        index: index ?? this.index,
        position: position ?? this.position,
        playlist: playlist ?? this.playlist,
      );

  static Spiff empty() =>
      Spiff(index: -1, position: 0, playlist: Playlist(title: '', tracks: []));

  static Future<Spiff> fromFile(File file) async {
    final completer = Completer<Spiff>();
    file.exists().then((exists) {
      if (exists) {
        file.readAsBytes().then((body) {
          completer.complete(Spiff.fromJson(jsonDecode(utf8.decode(body))));
        }).catchError((e) {
          completer.completeError(e);
        });
      } else {
        completer.complete(Spiff.empty());
      }
    });
    return completer.future;
  }
}

@JsonSerializable()
class Entry extends Locatable implements MediaTrack {
  final String creator;
  final String album;
  final String title;
  final String image;
  @JsonKey(name: 'location')
  final List<String> locations;
  @JsonKey(name: 'identifier')
  final List<String> identifiers;
  @JsonKey(name: 'size')
  final List<int>? sizes;

  Entry(
      {required this.creator,
      required this.album,
      required this.title,
      required this.image,
      required this.locations,
      required this.identifiers,
      this.sizes});

  factory Entry.fromJson(Map<String, dynamic> json) => _$EntryFromJson(json);

  Map<String, dynamic> toJson() => _$EntryToJson(this);

  @override
  String get key {
    final etag = identifiers[0];
    return etag.replaceAll(new RegExp(r'"'), '');
  }

  @override
  String get location {
    return locations[0];
  }

  int get size {
    return sizes == null || sizes!.isEmpty ? 0 : sizes![0];
  }

  @override
  int get disc => 1;

  @override
  int get number => 0;

  @override
  // TODO: implement year
  int get year => 0;
}

@JsonSerializable()
class Playlist {
  final String? location;
  final String? creator;
  final String title;
  final String? image;
  @JsonKey(name: 'track')
  final List<Entry> tracks;

  Playlist(
      {this.location,
      this.creator,
      required this.title,
      this.image,
      required this.tracks});

  Playlist copyWith({
    required String location,
  }) =>
      Playlist(
        location: location,
        creator: this.creator,
        title: this.title,
        image: this.image,
        tracks: this.tracks,
      );

  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);

  Map<String, dynamic> toJson() => _$PlaylistToJson(this);
}
