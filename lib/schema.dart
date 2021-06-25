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

import 'model.dart';
import 'util.dart';

part 'schema.g.dart';

@JsonSerializable(fieldRename: FieldRename.pascal)
class HomeView {
  @JsonKey(name: "AddedReleases")
  List<Release> added;
  @JsonKey(name: "NewReleases")
  List<Release> released;
  List<Movie> addedMovies;
  List<Movie> newMovies;

  HomeView({this.added, this.released});

  factory HomeView.fromJson(Map<String, dynamic> json) =>
      _$HomeViewFromJson(json);

  Map<String, dynamic> toJson() => _$HomeViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class ArtistView {
  Artist artist;
  String image;
  String background;
  List<Release> releases;
  List<Track> popular;
  List<Track> singles;
  List<Artist> similar;

  ArtistView(
      {this.artist,
      this.image,
      this.background,
      this.releases,
      this.popular,
      this.singles,
      this.similar});

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

  ReleaseView(
      {this.artist,
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
  List<Movie> movies;
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
  final String disambiguation;
  final String country;
  final String area;
  final String date;
  final String endDate;
  final String genre;

  Artist(
      {this.id,
      this.name,
      this.sortName,
      this.arid,
      this.disambiguation,
      this.country,
      this.area,
      this.date,
      this.endDate,
      this.genre});

  factory Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);

  Map<String, dynamic> toJson() => _$ArtistToJson(this);

// releases
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class Release implements MusicAlbum {
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
  final String releaseDate;
  final bool artwork;
  final bool frontArtwork;
  final bool backArtwork;
  final String otherArtwork;
  final bool groupArtwork;

  Release(
      {this.id,
      this.name,
      this.artist,
      this.rgid,
      this.reid,
      this.disambiguation,
      this.type,
      this.date,
      this.releaseDate,
      this.artwork,
      this.frontArtwork,
      this.backArtwork,
      this.otherArtwork,
      this.groupArtwork});

  factory Release.fromJson(Map<String, dynamic> json) =>
      _$ReleaseFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseToJson(this);

  @override
  String get album => name;

  @override
  String get creator => artist;

  @override
  String get image => _releaseCoverUrl();

  int _year = -1;

  @override
  int get year {
    if (_year == -1) {
      final d = DateTime.parse(date);
      _year = d.year;
    }
    return _year;
  }

  @override
  int get size => 0;

  String _releaseCoverUrl({int size = 250}) {
    final url = groupArtwork
        ? 'https://coverartarchive.org/release-group/$rgid'
        : 'https://coverartarchive.org/release/$reid';
    if (artwork && frontArtwork) {
      return '$url/front-$size';
    } else if (artwork && isNotNullOrEmpty(otherArtwork)) {
      return '$url/$otherArtwork-$size';
    }
    return null;
  }
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class Track extends Locatable implements MusicTrack {
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
  final bool groupArtwork;

  Track(
      {this.id,
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
      this.artwork,
      this.frontArtwork,
      this.backArtwork,
      this.otherArtwork,
      this.groupArtwork});

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

  @override
  String get album => release;

  @override
  String get creator => artist;

  @override
  int get disc => discNum;

  @override
  String get image => _trackCoverUrl();

  @override
  int get number => trackNum;

  int _year = -1;

  @override
  int get year {
    if (_year == -1) {
      final d = DateTime.parse(date);
      _year = d.year;
    }
    return _year;
  }

  String _trackCoverUrl({int size = 250}) {
    final url = groupArtwork
        ? 'https://coverartarchive.org/release-group/$rgid'
        : 'https://coverartarchive.org/release/$reid';
    if (artwork && frontArtwork) {
      return '$url/front-$size';
    } else if (artwork && isNotNullOrEmpty(otherArtwork)) {
      return '$url/$otherArtwork}-$size';
    }
    return null;
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
  List<Station> series;
  List<Station> other;

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

@JsonSerializable(fieldRename: FieldRename.pascal)
class MoviesView {
  final List<Movie> movies;

  MoviesView({this.movies});

  factory MoviesView.fromJson(Map<String, dynamic> json) =>
      _$MoviesViewFromJson(json);

  Map<String, dynamic> toJson() => _$MoviesViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class MovieView {
  final Movie movie;
  final Collection collection;
  final List<Movie> other;
  final List<Cast> cast;
  final List<Crew> crew;
  final List<Person> starring;
  final List<Person> directing;
  final List<Person> writing;
  final List<String> genres;
  final int vote;
  final int voteCount;

  MovieView(
      {this.movie,
      this.collection,
      this.other,
      this.cast,
      this.crew,
      this.starring,
      this.directing,
      this.writing,
      this.genres,
      this.vote,
      this.voteCount});

  factory MovieView.fromJson(Map<String, dynamic> json) =>
      _$MovieViewFromJson(json);

  Map<String, dynamic> toJson() => _$MovieViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class Person {
  @JsonKey(name: "ID")
  final int id;
  @JsonKey(name: "PEID")
  final int peid;
  final String name;
  final String profilePath;
  final String bio;
  final String birthplace;
  final String birthday;
  final String deathday;

  Person(
      {this.id,
      this.peid,
      this.name,
      this.profilePath,
      this.bio,
      this.birthplace,
      this.birthday,
      this.deathday});

  factory Person.fromJson(Map<String, dynamic> json) => _$PersonFromJson(json);

  Map<String, dynamic> toJson() => _$PersonToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class Cast {
  @JsonKey(name: "ID")
  final int id;
  @JsonKey(name: "TMID")
  final int tmid;
  @JsonKey(name: "PEID")
  final int peid;
  final String character;
  final Person person;

  Cast({this.id, this.tmid, this.peid, this.character, this.person});

  factory Cast.fromJson(Map<String, dynamic> json) => _$CastFromJson(json);

  Map<String, dynamic> toJson() => _$CastToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class Crew {
  @JsonKey(name: "ID")
  final int id;
  @JsonKey(name: "TMID")
  final int tmid;
  @JsonKey(name: "PEID")
  final int peid;
  final String department;
  final String job;
  final Person person;

  Crew({this.id, this.tmid, this.peid, this.department, this.job, this.person});

  factory Crew.fromJson(Map<String, dynamic> json) => _$CrewFromJson(json);

  Map<String, dynamic> toJson() => _$CrewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class Collection {
  @JsonKey(name: "ID")
  final int id;
  final String name;
  final String sortName;
  @JsonKey(name: "TMID")
  final String tmid;

  Collection({this.id, this.name, this.sortName, this.tmid});

  factory Collection.fromJson(Map<String, dynamic> json) =>
      _$CollectionFromJson(json);

  Map<String, dynamic> toJson() => _$CollectionToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class Movie extends Locatable {
  @JsonKey(name: "ID")
  final int id;
  @JsonKey(name: "TMID")
  final int tmid;
  @JsonKey(name: "IMID")
  final String imid;
  final String title;
  final String sortTitle;
  final String date;
  final String rating;
  final String tagline;
  final String overview;
  final int budget;
  final int revenue;
  final int runtime;
  final double voteAverage;
  final int voteCount;
  final String backdropPath;
  final String posterPath;
  @JsonKey(name: "ETag")
  final String etag;

  Movie(
      {this.id,
      this.tmid,
      this.imid,
      this.title,
      this.sortTitle,
      this.date,
      this.rating,
      this.tagline,
      this.overview,
      this.budget,
      this.revenue,
      this.runtime,
      this.voteAverage,
      this.voteCount,
      this.backdropPath,
      this.posterPath,
      this.etag});

  factory Movie.fromJson(Map<String, dynamic> json) => _$MovieFromJson(json);

  Map<String, dynamic> toJson() => _$MovieToJson(this);

  @override
  String get key {
    return etag.replaceAll(new RegExp(r'"'), '');
  }

  @override
  String get location {
    return '/api/movies/$id/location';
  }

  int _year = -1;

  int get year {
    if (_year == -1) {
      final d = DateTime.parse(date);
      _year = d.year;
    }
    return _year;
  }
}
