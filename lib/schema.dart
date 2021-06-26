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
  final List<Release> added;
  @JsonKey(name: "NewReleases")
  final List<Release> released;
  final List<Movie> addedMovies;
  final List<Movie> newMovies;

  HomeView(
      {this.added = const [],
      this.released = const [],
      this.addedMovies = const [],
      this.newMovies = const []});

  factory HomeView.fromJson(Map<String, dynamic> json) =>
      _$HomeViewFromJson(json);

  Map<String, dynamic> toJson() => _$HomeViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class ArtistView {
  late final Artist artist;
  final String? image;
  final String? background;
  final List<Release> releases;
  final List<Track> popular;
  final List<Track> singles;
  final List<Artist> similar;

  ArtistView(
      {required this.artist,
      this.image,
      this.background,
      this.releases = const [],
      this.popular = const [],
      this.singles = const [],
      this.similar = const []});

  factory ArtistView.fromJson(Map<String, dynamic> json) =>
      _$ArtistViewFromJson(json);

  Map<String, dynamic> toJson() => _$ArtistViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class ReleaseView {
  final Artist artist;
  final Release release;
  final List<Track> tracks;
  final List<Track> popular;
  final List<Track> singles;
  final List<Release> similar;

  ReleaseView(
      {required this.artist,
      required this.release,
      this.tracks = const [],
      this.popular = const [],
      this.singles = const [],
      this.similar = const []});

  factory ReleaseView.fromJson(Map<String, dynamic> json) =>
      _$ReleaseViewFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseViewToJson(this);

  int get discs {
    int discs = 1;
    for (var t in tracks ?? []) {
      if (t.discNum > discs) {
        discs = t.discNum;
      }
    }
    return discs;
  }
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class SearchView {
  final List<Artist> artists;
  final List<Release> releases;
  final List<Track> tracks;
  final List<Movie> movies;
  final String query;
  final int hits;

  SearchView(
      {this.artists = const [],
      this.releases = const [],
      this.tracks = const [],
      this.movies = const [],
      required this.query,
      required this.hits});

  factory SearchView.fromJson(Map<String, dynamic> json) =>
      _$SearchViewFromJson(json);

  Map<String, dynamic> toJson() => _$SearchViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class ArtistsView {
  final List<Artist> artists;

  ArtistsView({this.artists = const []});

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
  final String? arid;
  final String? disambiguation;
  final String? country;
  final String? area;
  final String? date;
  final String? endDate;
  final String? genre;

  Artist(
      {required this.id,
      required this.name,
      required this.sortName,
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
  final String? rgid;
  @JsonKey(name: "REID")
  final String? reid;
  final String? disambiguation;
  final String? type;
  final String? date;
  final String? releaseDate;
  final bool artwork;
  final bool frontArtwork;
  final bool backArtwork;
  final String? otherArtwork;
  final bool groupArtwork;

  Release(
      {required this.id,
      required this.name,
      required this.artist,
      this.rgid,
      this.reid,
      this.disambiguation,
      this.type,
      this.date,
      this.releaseDate,
      this.artwork = false,
      this.frontArtwork = false,
      this.backArtwork = false,
      this.otherArtwork,
      this.groupArtwork = false});

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
    if (_year == -1 && date != null) {
      final d = DateTime.parse(date!);
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
    return '';
  }
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class Track extends Locatable implements MusicTrack {
  @JsonKey(name: "ID")
  final int id;
  final String artist;
  final String release;
  final String? date;
  final int trackNum;
  final int discNum;
  final String title;
  final int size;
  @JsonKey(name: "RGID")
  final String? rgid;
  @JsonKey(name: "REID")
  final String? reid;
  final String releaseTitle;
  @JsonKey(name: "ETag")
  final String etag;
  final bool artwork;
  final bool frontArtwork;
  final bool backArtwork;
  final String? otherArtwork;
  final bool groupArtwork;

  Track(
      {required this.id,
      required this.artist,
      required this.release,
      this.date,
      required this.trackNum,
      required this.discNum,
      required this.title,
      required this.size,
      this.rgid,
      this.reid,
      required this.releaseTitle,
      required this.etag,
      this.artwork = false,
      this.frontArtwork = false,
      this.backArtwork = false,
      this.otherArtwork,
      this.groupArtwork = false});

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
    if (_year == -1 && date != null) {
      final d = DateTime.parse(date!);
      _year = d.year;
    }
    return _year;
  }

  String _trackCoverUrl({int size = 250}) {
    final url = groupArtwork!
        ? 'https://coverartarchive.org/release-group/$rgid'
        : 'https://coverartarchive.org/release/$reid';
    if (artwork && frontArtwork) {
      return '$url/front-$size';
    } else if (artwork && isNotNullOrEmpty(otherArtwork)) {
      return '$url/$otherArtwork}-$size';
    }
    return '';
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

  Location(
      {required this.id,
      required this.url,
      required this.size,
      required this.etag});

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

  RadioView(
      {this.artist = const [],
      this.genre = const [],
      this.similar = const [],
      this.period = const [],
      this.series = const [],
      this.other = const []});

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

  Station({required this.id, required this.name, required this.ref});

  factory Station.fromJson(Map<String, dynamic> json) =>
      _$StationFromJson(json);

  Map<String, dynamic> toJson() => _$StationToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class SinglesView {
  final Artist artist;
  final List<Track> singles;

  SinglesView({required this.artist, this.singles = const []});

  factory SinglesView.fromJson(Map<String, dynamic> json) =>
      _$SinglesViewFromJson(json);

  Map<String, dynamic> toJson() => _$SinglesViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class PopularView {
  final Artist artist;
  final List<Track> popular;

  PopularView({required this.artist, this.popular = const []});

  factory PopularView.fromJson(Map<String, dynamic> json) =>
      _$PopularViewFromJson(json);

  Map<String, dynamic> toJson() => _$PopularViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class MoviesView {
  final List<Movie> movies;

  MoviesView({this.movies = const []});

  factory MoviesView.fromJson(Map<String, dynamic> json) =>
      _$MoviesViewFromJson(json);

  Map<String, dynamic> toJson() => _$MoviesViewToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.pascal)
class MovieView {
  final Movie movie;
  final Collection? collection;
  final List<Movie> other;
  final List<Cast> cast;
  final List<Crew> crew;
  final List<Person> starring;
  final List<Person> directing;
  final List<Person> writing;
  final List<String> genres;
  final int? vote;
  final int? voteCount;

  MovieView(
      {required this.movie,
      this.collection,
      this.other = const [],
      this.cast = const [],
      this.crew = const [],
      this.starring = const [],
      this.directing = const [],
      this.writing = const [],
      this.genres = const [],
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
  final String? profilePath;
  final String? bio;
  final String? birthplace;
  final String? birthday;
  final String? deathday;

  Person(
      {required this.id,
      required this.peid,
      required this.name,
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

  Cast(
      {required this.id,
      required this.tmid,
      required this.peid,
      required this.character,
      required this.person});

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

  Crew(
      {required this.id,
      required this.tmid,
      required this.peid,
      required this.department,
      required this.job,
      required this.person});

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

  Collection(
      {required this.id,
      required this.name,
      required this.sortName,
      required this.tmid});

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
  final double? voteAverage;
  final int? voteCount;
  final String backdropPath;
  final String posterPath;
  @JsonKey(name: "ETag")
  final String etag;

  Movie(
      {required this.id,
      required this.tmid,
      required this.imid,
      required this.title,
      required this.sortTitle,
      required this.date,
      required this.rating,
      required this.tagline,
      required this.overview,
      required this.budget,
      required this.revenue,
      required this.runtime,
      this.voteAverage,
      this.voteCount,
      required this.backdropPath,
      required this.posterPath,
      required this.etag});

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
