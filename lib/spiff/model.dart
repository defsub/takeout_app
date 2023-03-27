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
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:takeout_app/cache/offset_repository.dart';
import 'package:takeout_app/client/download.dart';
import 'package:takeout_app/client/etag.dart';
import 'package:takeout_app/media_type/media_type.dart';
import 'package:takeout_app/model.dart';
import 'package:takeout_app/util.dart';

part 'model.g.dart';

Random _random = Random();

@JsonSerializable()
class Spiff {
  final int index;
  final double position;
  final Playlist playlist;
  final String type;
  final String cover;
  @JsonKey(ignore: true)
  final DateTime? lastModified;

  Spiff(
      {required this.index,
      required this.position,
      required this.playlist,
      required this.type,
      this.lastModified})
      : cover = playlist._cover;

  int get size => playlist.tracks.fold(0, (sum, t) => sum + t.size);

  String? get creator => playlist.creator;

  String get title => playlist.title;

  String? get location => playlist.location;

  String? get date => playlist.date;

  bool get isEmpty => playlist.tracks.isEmpty;

  bool get isNotEmpty => playlist.tracks.isNotEmpty;

  @override
  bool operator ==(other) {
    if (other is Spiff) {
      return playlist.title == other.playlist.title &&
          playlist.creator == other.playlist.creator &&
          playlist.location == other.playlist.location &&
          playlist.image == other.playlist.image &&
          playlist.date == other.playlist.date &&
          playlist.tracks.length == other.playlist.tracks.length &&
          listEquals(playlist.tracks, other.playlist.tracks);
    }
    return false;
  }

  Entry operator [](int index) {
    return playlist.tracks[index];
  }

  @override
  int get hashCode {
    return super.hashCode;
  }

  int get length {
    return playlist.tracks.length;
  }

  bool isLocal() {
    return playlist.location?.startsWith(RegExp(r'^file')) ?? false;
  }

  bool isRemote() {
    // https, http, or relative "/api" are remote
    return playlist.location?.startsWith(RegExp(r'^(http|/api)')) ?? false;
  }

  bool isMusic() {
    return MediaType.of(type) == MediaType.music;
  }

  bool isVideo() {
    return MediaType.of(type) == MediaType.video;
  }

  bool isPodcast() {
    return MediaType.of(type) == MediaType.podcast;
  }

  bool isStream() {
    return MediaType.of(type) == MediaType.stream;
  }

  MediaType get mediaType {
    if (type.isEmpty) {
      // FIXME remove after transition to require type is done
      return MediaType.music;
    }
    return MediaType.of(type);
  }

  factory Spiff.fromJson(Map<String, dynamic> json) {
    try {
      return _$SpiffFromJson(json);
    } catch (e) {
      print('got error $e, using empty');
      return Spiff(
          index: 0,
          position: 0,
          playlist: Playlist(title: 'error: $e', tracks: []),
          type: MediaType.music.name);
    }
  }

  Map<String, dynamic> toJson() => _$SpiffToJson(this);

  Spiff copyWith({
    int? index,
    double? position,
    Playlist? playlist,
    String? type,
    DateTime? lastModified,
  }) =>
      Spiff(
          index: index ?? this.index,
          position: position ?? this.position,
          playlist: playlist ?? this.playlist,
          type: type ?? this.type,
          lastModified: lastModified ?? this.lastModified);

  Spiff updateAt(int int, Entry entry) {
    return copyWith(playlist: playlist.updateAt(index, entry));
  }

  static Spiff cleanup(Spiff spiff) {
    final creator = _playlistCreator(spiff);
    final title = _playlistTitle(spiff);
    if (creator != spiff.playlist.creator || title != spiff.playlist.title) {
      final playlist = spiff.playlist.copyWith(creator: creator, title: title);
      spiff = spiff.copyWith(playlist: playlist);
    }
    return spiff;
  }

  factory Spiff.empty() => Spiff(
      index: 0,
      position: 0,
      playlist: Playlist(title: '', tracks: []),
      type: MediaType.music.name);
}

@JsonSerializable()
class Entry extends DownloadIdentifier implements MediaTrack, OffsetIdentifier {
  final String creator;
  final String album;
  final String title;
  final String image;
  final String date;
  @JsonKey(name: 'location')
  final List<String> locations;
  @JsonKey(name: 'identifier')
  final List<String>? identifiers;
  @JsonKey(name: 'size')
  final List<int>? sizes;
  final int _year;

  Entry(
      {required this.creator,
      required this.album,
      required this.title,
      required this.image,
      this.date = '',
      required this.locations,
      this.identifiers,
      this.sizes})
      : _year = parseYear(date);

  Entry copyWith({
    String? title,
    // List<String>? locations,
  }) =>
      Entry(
          creator: this.creator,
          album: this.album,
          title: title ?? this.title,
          image: this.image,
          date: this.date,
          locations: this.locations,
          identifiers: this.identifiers,
          sizes: this.sizes);

  factory Entry.fromJson(Map<String, dynamic> json) {
    try {
      return _$EntryFromJson(json);
    } catch (e) {
      if (json['creator'] == null) json['creator'] = 'no creator';
      if (json['album'] == null) json['album'] = 'no album';
      if (json['title'] == null) json['title'] = 'no title';
      if (json['image'] == null) json['image'] = '';
      return _$EntryFromJson(json);
    }
  }

  Map<String, dynamic> toJson() => _$EntryToJson(this);

  @override
  String get key {
    return ETag(etag).key;
  }

  @override
  String get etag {
    return identifiers?[0] ?? '';
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
  int get year => _year;
}

@JsonSerializable()
class Playlist {
  final String? location;
  final String? creator;
  final String title;
  final String? image;
  final String? date;
  @JsonKey(name: 'track')
  final List<Entry> tracks;
  final String _cover;

  Playlist(
      {this.location,
      this.creator,
      required this.title,
      this.image,
      this.date,
      required this.tracks})
      : _cover = _pickCover(image, tracks);

  Playlist copyWith({
    String? location,
    String? creator,
    String? title,
    List<Entry>? tracks,
  }) =>
      Playlist(
        location: location ?? this.location,
        creator: creator ?? this.creator,
        title: title ?? this.title,
        image: this.image,
        tracks: tracks ?? this.tracks,
      );

  Playlist updateAt(int index, Entry entry) {
    if (index >= 0 && index < tracks.length) {
      final newTracks = List<Entry>.from(tracks);
      newTracks[index] = entry;
      return copyWith(tracks: newTracks);
    } else {
      throw IndexError.withLength(index, tracks.length);
    }
  }

  factory Playlist.fromJson(Map<String, dynamic> json) =>
      _$PlaylistFromJson(json);

  Map<String, dynamic> toJson() => _$PlaylistToJson(this);

  static String _pickCover(String? image, List<Entry> tracks) {
    if (isNotNullOrEmpty(image)) {
      return image!;
    }
    if (tracks.length == 0) {
      return '';
    }
    for (var i = 0; i < 3; i++) {
      final pick = _random.nextInt(tracks.length);
      if (isNotNullOrEmpty(tracks[pick].image)) {
        return tracks[pick].image;
      }
    }
    try {
      return tracks.firstWhere((t) => isNotNullOrEmpty(t.image)).image;
    } on StateError {
      return '';
    }
  }
}

String spiffDate(Spiff spiff, {Entry? entry, Playlist? playlist}) {
  if (entry != null) {
    return spiff.isPodcast() ? ymd(entry.date) : entry.year.toString();
  }
  if (playlist != null && playlist.date != null) {
    return spiff.isPodcast()
        ? ymd(playlist.date!)
        : parseYear(playlist.date!).toString();
  }
  return '';
}

String playlistDate(Spiff spiff) {
  return spiffDate(spiff, playlist: spiff.playlist);
}

String _playlistCreator(Spiff spiff) {
  if (spiff.playlist.creator != null) {
    return spiff.playlist.creator!;
  }
  final list = LinkedHashSet<String>();
  // use track creator(s)
  list.addAll(spiff.playlist.tracks.map((e) => e.creator));
  return list.join(', ');
}

String _playlistTitle(Spiff spiff) {
  if (spiff.playlist.title.isNotEmpty) {
    return spiff.playlist.title;
  }
  final list = LinkedHashSet<String>()
    ..addAll(spiff.playlist.tracks.map((e) => e.album));
  return list.join(', ');
}
