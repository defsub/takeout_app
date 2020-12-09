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

import 'dart:core';

import 'package:json_annotation/json_annotation.dart';
import 'package:takeout_app/client.dart';

part 'music.g.dart';

@JsonSerializable(fieldRename: FieldRename.pascal)
class HomeView {
  List<Release> added;
  List<Release> released;

  HomeView({this.added, this.released});

  factory HomeView.fromJson(Map<String, dynamic> json) =>
      _$HomeViewFromJson(json);

  Map<String, dynamic> toJson() => _$HomeViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class ArtistView {
  Artist artist;
  List<Release> releases;
  List<Track> popular;
  List<Track> singles;
  List<Artist> similar;

  ArtistView(
      {this.artist, this.releases, this.popular, this.singles, this.similar});

  factory ArtistView.fromJson(Map<String, dynamic> json) =>
      _$ArtistViewFromJson(json);

  Map<String, dynamic> toJson() => _$ArtistViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class ReleaseView {
  Artist artist;
  Release release;
  List<Track> tracks;
  List<Track> popular;
  List<Track> singles;
  List<Release> similar;

  ReleaseView({this.artist,
    this.release,
    this.tracks,
    this.popular,
    this.singles,
    this.similar});

  factory ReleaseView.fromJson(Map<String, dynamic> json) =>
      _$ReleaseViewFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseViewToJson(this);

  int get discs {
    int discs = 1;
    for (var t in tracks) {
      if (t.discNum > discs) {
        discs = t.discNum;
      }
    }
    return discs;
  }
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class SearchView {
  List<Artist> artists;
  List<Release> releases;
  List<Track> tracks;
  String query;
  int hits;

  SearchView({this.artists, this.releases, this.tracks, this.query, this.hits});

  factory SearchView.fromJson(Map<String, dynamic> json) =>
      _$SearchViewFromJson(json);

  Map<String, dynamic> toJson() => _$SearchViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class ArtistsView {
  List<Artist> artists;

  ArtistsView({this.artists});

  factory ArtistsView.fromJson(Map<String, dynamic> json) =>
      _$ArtistsViewFromJson(json);

  Map<String, dynamic> toJson() => _$ArtistsViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class Artist {
  @JsonKey(name: "ID")
  final int id;
  final String name;
  final String sortName;
  @JsonKey(name: "ARID")
  final String arid;

  Artist({this.id, this.name, this.sortName, this.arid});

  factory Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);

  Map<String, dynamic> toJson() => _$ArtistToJson(this);

// releases
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class Release {
  @JsonKey(name: "ID")
  final int id;
  final String name;
  final String artist;
  @JsonKey(name: "RGID")
  final String rgid;
  @JsonKey(name: "REID")
  final String reid;
  final String disambiguation;
  final String type;
  final String date;
  final bool artwork;
  final bool frontArtwork;
  final bool backArtwork;
  final String otherArtwork;

  Release({this.id,
    this.name,
    this.artist,
    this.rgid,
    this.reid,
    this.disambiguation,
    this.type,
    this.date,
    this.artwork, this.frontArtwork, this.backArtwork, this.otherArtwork});

  factory Release.fromJson(Map<String, dynamic> json) =>
      _$ReleaseFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class Track extends Locatable {
  @JsonKey(name: "ID")
  final int id;
  final String artist;
  final String release;
  final String date;
  final int trackNum;
  final int discNum;
  final String title;
  final int size;
  @JsonKey(name: "RGID")
  final String rgid;
  @JsonKey(name: "REID")
  final String reid;
  final String releaseTitle;
  @JsonKey(name: "ETag")
  final String etag;
  final bool artwork;
  final bool frontArtwork;
  final bool backArtwork;
  final String otherArtwork;

  Track({this.id,
    this.artist,
    this.release,
    this.date,
    this.trackNum,
    this.discNum,
    this.title,
    this.size,
    this.rgid,
    this.reid,
    this.releaseTitle,
    this.etag,
    this.artwork, this.frontArtwork, this.backArtwork, this.otherArtwork});

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);

  Map<String, dynamic> toJson() => _$TrackToJson(this);

  @override
  String get key {
    return etag.replaceAll(new RegExp(r'"'), '');
  }

  @override
  String get location {
    return '/api/tracks/$id/location';
  }
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class Location {
  @JsonKey(name: "ID")
  final int id;
  final String url;
  final int size;
  @JsonKey(name: "ETag")
  final String etag;

  Location({this.id, this.url, this.size, this.etag});

  factory Location.fromJson(Map<String, dynamic> json) =>
      _$LocationFromJson(json);

  Map<String, dynamic> toJson() => _$LocationToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class RadioView {
  List<Station> artist;
  List<Station> genre;
  List<Station> similar;
  List<Station> period;

  RadioView({this.artist, this.genre, this.similar, this.period});

  factory RadioView.fromJson(Map<String, dynamic> json) =>
      _$RadioViewFromJson(json);

  Map<String, dynamic> toJson() => _$RadioViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class Station {
  @JsonKey(name: "ID")
  final int id;
  final String name;
  final String ref;

  Station({this.id, this.name, this.ref});

  factory Station.fromJson(Map<String, dynamic> json) =>
      _$StationFromJson(json);

  Map<String, dynamic> toJson() => _$StationToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class SinglesView {
  final Artist artist;
  final List<Track> singles;

  SinglesView({this.artist, this.singles});

  factory SinglesView.fromJson(Map<String, dynamic> json) =>
      _$SinglesViewFromJson(json);

  Map<String, dynamic> toJson() => _$SinglesViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class PopularView {
  final Artist artist;
  final List<Track> popular;

  PopularView({this.artist, this.popular});

  factory PopularView.fromJson(Map<String, dynamic> json) =>
      _$PopularViewFromJson(json);

  Map<String, dynamic> toJson() => _$PopularViewToJson(this);
}