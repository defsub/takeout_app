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

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cache.dart';
import 'schema.dart';
import 'spiff.dart';

class ClientException implements Exception {
  final int statusCode;
  final String? url;

  const ClientException({required this.statusCode, this.url});

  bool get authenticationFailed =>
      statusCode == HttpStatus.networkAuthenticationRequired ||
      statusCode == HttpStatus.unauthorized ||
      statusCode == HttpStatus.forbidden;

  String toString() => 'ClientException: $statusCode => $url';
}

class ClientError extends Error {
  final Object? message;

  /// Creates a client error with the provided [message].
  ClientError([this.message]);

  String toString() {
    if (message != null) {
      return "Client error: ${Error.safeToString(message)}";
    }
    return "Client error";
  }
}

abstract class Locatable {
  /// Cache key.
  String get key;

  /// Location URL to get location.
  String get location;

  int get size;
}

class LocatableKey implements Locatable {
  final String key;

  LocatableKey(this.key);

  String get location {
    throw UnimplementedError;
  }

  int get size {
    throw UnimplementedError;
  }
}

class PostResult {
  final int statusCode;

  PostResult(this.statusCode);

  bool noContent() {
    return statusCode == HttpStatus.noContent;
  }

  bool resetContent() {
    return statusCode == HttpStatus.resetContent;
  }

  bool clientError() {
    return statusCode == HttpStatus.badRequest;
  }

  bool serverError() {
    return statusCode == HttpStatus.internalServerError;
  }
}

class PatchResult extends PostResult {
  final Map<String, dynamic> body;

  PatchResult(statusCode, this.body) : super(statusCode);

  bool isModified() {
    return statusCode == HttpStatus.ok;
  }

  bool notModified() => noContent();

  Spiff toSpiff() {
    return Spiff.fromJson(body);
  }
}

class DownloadSnapshot {
  final int size;
  final int offset;
  final Object? err;

  DownloadSnapshot(this.size, this.offset, {this.err});

  bool hasError() {
    return err != null;
  }

  bool isComplete() {
    return offset == size;
  }

  // Value used for progress display.
  double get value {
    return offset.toDouble() / size;
  }
}

class _SnapshotSink extends Sink<int> {
  final Locatable locatable;
  int offset = 0;

  _SnapshotSink(this.locatable);

  void add(int chunk) {
    offset += chunk;
    Client._downloadSnapshotUpdate(locatable, offset);
  }

  void close() {}
}

class Client {
  static const settingCookie = 'client_cookie';
  static const settingEndpoint = 'endpoint';
  static const cookieName = 'Takeout';
  static const _defaultPlaylist = '/api/playlist';

  static const locationTTL = Duration(hours: 1);
  static const playlistTTL = Duration(minutes: 1);
  static const defaultTTL = Duration(hours: 24);
  static const defaultTimeout = Duration(seconds: 5);
  static const downloadTimeout = Duration(minutes: 5);

  static String? _endpoint;
  static String? _cookie;
  static Uri _defaultPlaylistUri = Uri.parse(_defaultPlaylist);

  static Uri defaultPlaylistUri() {
    return _defaultPlaylistUri;
  }

  static final downloadStream =
      BehaviorSubject<Map<String, DownloadSnapshot>>.seeded(
          <String, DownloadSnapshot>{});
  static final _downloadSnapshots = <String, DownloadSnapshot>{};

  static void _downloadSnapshotUpdate(Locatable l, int offset) {
    _downloadSnapshots[l.key] = DownloadSnapshot(l.size, offset);
    _publish();
  }

  static bool _downloadInProgress(Locatable l) {
    return _downloadSnapshots.containsKey(l.key);
  }

  static void _downloadSnapshotRemove(Locatable l) {
    _downloadSnapshots.remove(l.key);
  }

  static void _publish() {
    downloadStream.add(_downloadSnapshots);
  }

  bool Function()? _allowDownloads;

  Client([this._allowDownloads]);

  bool get allowDownloads =>
      _allowDownloads != null ? _allowDownloads!() : true;

  Future<void> setEndpoint(String? v) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _endpoint = v;
    if (v == null) {
      prefs.remove(settingEndpoint);
    } else {
      prefs.setString(settingEndpoint, v);
    }
  }

  Future<String> getEndpoint() async {
    if (_endpoint == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(settingEndpoint)) {
        _endpoint = prefs.getString(settingEndpoint);
      }
    }
    return _endpoint!;
  }

  Future<void> _setCookie(String? v) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _cookie = v;
    if (v == null) {
      await prefs.remove(settingCookie);
    } else {
      await prefs.setString(settingCookie, v);
    }
  }

  Future<String?> _getCookie() async {
    if (_cookie == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(settingCookie)) {
        _cookie = prefs.getString(settingCookie);
      }
    }
    return _cookie;
  }

  Future<Map<String, String>> headers() async {
    final cookie = await _getCookie();
    return {HttpHeaders.cookieHeader: '$cookieName=$cookie'};
  }

  Future<bool> needLogin() async {
    final cookie = await _getCookie();
    // TODO check cookie age
    return cookie == null;
  }

  Future<bool> loggedIn() async {
    final cookie = await _getCookie();
    // TODO check cookie age
    if (cookie != null) {
      // needed to ensure endpoint is set
      await getEndpoint();
    }
    return cookie != null;
  }

  Future<void> logout() async {
    return _setCookie(null);
  }

  Future<Map<String, dynamic>> _getJson(String uri,
      {bool cacheable = true, Duration? ttl}) async {
    final cache = JsonCache();
    final cookie = await _getCookie();
    if (cookie == null) {
      throw ClientException(
        statusCode: HttpStatus.networkAuthenticationRequired,
      );
    }

    // Ensure there's a default TTL
    ttl = ttl ?? defaultTTL;

    Map<String, dynamic>? cachedJson = null;

    if (cacheable) {
      final result = await cache.get(uri, ttl: ttl);
      if (result.exists && result is JsonCacheEntry) {
        print('cached $uri expired is ${result.expired}');
        cachedJson = await result.file
            .readAsBytes()
            .then((body) => jsonDecode(utf8.decode(body)));
        if (cachedJson != null && result.expired == false) {
          // not expired so use the cached value
          return cachedJson;
        }
      }
    }

    try {
      final baseUrl = await getEndpoint();
      print('GET $baseUrl$uri');
      final response = await http.get(Uri.parse('$baseUrl$uri'), headers: {
        HttpHeaders.cookieHeader: '$cookieName=$cookie'
      }).timeout(defaultTimeout);
      print('got ${response.statusCode}');
      if (response.statusCode != HttpStatus.ok) {
        if (response.statusCode > 500 && cachedJson != null) {
          return cachedJson;
        }
        throw ClientException(
            statusCode: response.statusCode,
            url: response.request?.url.toString());
      }
      // print('got response ${response.body}');
      if (cacheable) {
        cache.put(uri, response.bodyBytes);
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is TlsException) {
        if (cachedJson != null) {
          print('got error $e; using cached json');
          return cachedJson;
        }
      }
      return Future<Map<String, dynamic>>.error(e);
    }
  }

  Future _delete(String uri) async {
    final cookie = await _getCookie();
    if (cookie == null) {
      throw ClientException(
        statusCode: HttpStatus.networkAuthenticationRequired,
      );
    }

    try {
      final baseUrl = await getEndpoint();
      print('DELETE $baseUrl$uri');
      final response = await http.delete(Uri.parse('$baseUrl$uri'),
          headers: {HttpHeaders.cookieHeader: '$cookieName=$cookie'});
      print('got ${response.statusCode}');
      switch (response.statusCode) {
        case HttpStatus.accepted:
        case HttpStatus.noContent:
        case HttpStatus.ok:
          // success
          break;
        default:
          // failure
          throw ClientException(
              statusCode: response.statusCode,
              url: response.request?.url.toString());
      }
    } on TlsException catch (e) {
      return Future.error(e);
    }
  }

  /// no caching
  Future<Map<String, dynamic>> _postJson(String uri, Map<String, dynamic> json,
      {bool requireCookie = false}) async {
    Map<String, String> headers = {
      HttpHeaders.contentTypeHeader: ContentType.json.toString(),
    };

    if (requireCookie) {
      final cookie = await _getCookie();
      if (cookie == null) {
        throw ClientException(
          statusCode: HttpStatus.networkAuthenticationRequired,
        );
      }
      headers[HttpHeaders.cookieHeader] = '$cookieName=$cookie';
    }

    final baseUrl = await getEndpoint();
    print('$baseUrl$uri');
    print(jsonEncode(json));
    return http
        .post(Uri.parse('$baseUrl$uri'),
            headers: headers, body: jsonEncode(json))
        .then((response) {
      print('response ${response.statusCode}');
      if (response.statusCode != HttpStatus.ok) {
        throw ClientException(
            statusCode: response.statusCode,
            url: response.request?.url.toString());
      }
      if (response.body.isEmpty) {
        return {
          'reasonPhrase': response.reasonPhrase,
          'statusCode': response.statusCode
        };
      } else {
        return jsonDecode(utf8.decode(response.bodyBytes));
      }
    });
  }

  // /// no cookie, no caching
  // Future<Map<String, dynamic>> _oldPostJson(
  //     String uri, Map<String, dynamic> json) async {
  //   final baseUrl = await getEndpoint();
  //   print('$baseUrl$uri');
  //   return http
  //       .post(Uri.parse('$baseUrl$uri'),
  //           headers: {
  //             HttpHeaders.contentTypeHeader: ContentType.json.toString()
  //           },
  //           body: jsonEncode(json))
  //       .then((response) {
  //     print('response ${response.statusCode}');
  //     if (response.statusCode != HttpStatus.ok) {
  //       throw ClientException(
  //           statusCode: response.statusCode,
  //           url: response.request?.url.toString());
  //     }
  //     // print('got response ${response.body}');
  //     return jsonDecode(utf8.decode(response.bodyBytes));
  //   });
  // }

  /// no caching
  Future<PatchResult> _patchJson(
      String uri, List<Map<String, dynamic>> json) async {
    final baseUrl = await getEndpoint();
    final completer = Completer<PatchResult>();
    _getCookie().then((cookie) {
      if (cookie == null) {
        completer.completeError(ClientException(
          statusCode: HttpStatus.networkAuthenticationRequired,
        ));
      } else {
        print('$baseUrl$uri');
        print(jsonEncode(json));
        http
            .patch(Uri.parse('$baseUrl$uri'),
                headers: {
                  HttpHeaders.contentTypeHeader: 'application/json-patch+json',
                  HttpHeaders.cookieHeader: '$cookieName=$cookie',
                },
                body: jsonEncode(json))
            .then((response) {
          print('response ${response.statusCode}');
          if (response.statusCode == HttpStatus.ok) {
            completer.complete(PatchResult(
                HttpStatus.ok, jsonDecode(utf8.decode(response.bodyBytes))));
          } else if (response.statusCode == HttpStatus.noContent) {
            completer.complete(PatchResult(HttpStatus.noContent, {}));
          } else {
            completer.completeError(ClientException(
                statusCode: response.statusCode,
                url: response.request?.url.toString()));
          }
        });
      }
    });
    return completer.future;
  }

  /// POST /api/login
  Future<Map<String, dynamic>> login(String user, String pass) async {
    await _setCookie(null);
    final json = {'User': user, 'Pass': pass};
    try {
      final result = await _postJson('/api/login', json);
      print(result);
      if (result['Status'] == 200) {
        await _setCookie(result['Cookie']);
      }
      return result;
    } on ClientException {
      return {'Status': 500};
    }
  }

  /// GET /api/search?q=query (no cache by default)
  Future<SearchView> search(String q, {Duration ttl = Duration.zero}) async =>
      _getJson('/api/search?q=${Uri.encodeQueryComponent(q)}', ttl: ttl)
          .then((j) => SearchView.fromJson(j))
          .catchError((e) => Future<SearchView>.error(e));

  /// GET /api/index
  Future<IndexView> index({Duration? ttl}) async =>
      _getJson('/api/index', ttl: ttl)
          .then((j) => IndexView.fromJson(j))
          .catchError((e) => Future<IndexView>.error(e));

  /// GET /api/home
  Future<HomeView> home({Duration? ttl}) async =>
      _getJson('/api/home', ttl: ttl)
          .then((j) => HomeView.fromJson(j))
          .catchError((e) => Future<HomeView>.error(e));

  /// GET /api/artists
  Future<ArtistsView> artists({Duration? ttl}) async =>
      _getJson('/api/artists', ttl: ttl)
          .then((j) => ArtistsView.fromJson(j))
          .catchError((e) => Future<ArtistsView>.error(e));

  /// GET /api/artists/1
  Future<ArtistView> artist(int id, {Duration? ttl}) async =>
      _getJson('/api/artists/$id', ttl: ttl)
          .then((j) => ArtistView.fromJson(j))
          .catchError((e) => Future<ArtistView>.error(e));

  /// GET /api/artists/1/singles
  Future<SinglesView> artistSingles(int id, {Duration? ttl}) async =>
      _getJson('/api/artists/$id/singles', ttl: ttl)
          .then((j) => SinglesView.fromJson(j))
          .catchError((e) => Future<SinglesView>.error(e));

  /// GET /api/artists/1/singles/playlist
  Future<Spiff> artistSinglesPlaylist(int id, {Duration? ttl}) async =>
      spiff('/api/artists/$id/singles/playlist', ttl: ttl);

  /// GET /api/artists/1/popular
  Future<PopularView> artistPopular(int id, {Duration? ttl}) async =>
      _getJson('/api/artists/$id/popular', ttl: ttl)
          .then((j) => PopularView.fromJson(j))
          .catchError((e) => Future<PopularView>.error(e));

  /// GET /api/artists/1/popular/playlist
  Future<Spiff> artistPopularPlaylist(int id, {Duration? ttl}) async =>
      spiff('/api/artists/$id/popular/playlist', ttl: ttl);

  /// GET /api/artists/1/playlist
  Future<Spiff> artistPlaylist(int id, {Duration? ttl}) async =>
      spiff('/api/artists/$id/playlist', ttl: ttl);

  /// GET /api/artists/1/radio
  Future<Spiff> artistRadio(int id, {Duration? ttl}) async =>
      spiff('/api/artists/$id/radio', ttl: ttl);

  /// GET /api/releases/1
  Future<ReleaseView> release(int id, {Duration? ttl}) async =>
      _getJson('/api/releases/$id', ttl: ttl)
          .then((j) => ReleaseView.fromJson(j))
          .catchError((e) => Future<ReleaseView>.error(e));

  /// GET /api/releases/1/playlist
  Future<Spiff> releasePlaylist(int id, {Duration? ttl}) async =>
      spiff('/api/releases/$id/playlist', ttl: ttl);

  /// GET /api/playlist
  Future<Spiff> playlist() async => spiff('/api/playlist', ttl: playlistTTL);

  /// GET /api/radio
  Future<RadioView> radio({Duration? ttl}) async =>
      _getJson('/api/radio', ttl: ttl)
          .then((j) => RadioView.fromJson(j))
          .catchError((e) => Future<RadioView>.error(e));

  /// GET /api/radio/1
  Future<Spiff> station(int id, {Duration? ttl}) async =>
      spiff('/api/radio/$id', ttl: ttl);

  /// GET /path -> spiff
  Future<Spiff> spiff(String path, {Duration? ttl}) async =>
      _getJson(path, ttl: ttl)
          .then((j) => Spiff.fromJson(j))
          .catchError((e) => Future<Spiff>.error(e));

  Future<PatchResult> patch(List<Map<String, dynamic>> body) async =>
      _patchJson('/api/playlist', body);

  /// GET /api/movies
  Future<MoviesView> movies({Duration? ttl}) async =>
      _getJson('/api/movies', ttl: ttl)
          .then((j) => MoviesView.fromJson(j))
          .catchError((e) => Future<MoviesView>.error(e));

  /// GET /api/movies
  Future<GenreView> moviesGenre(String genre, {Duration? ttl}) async =>
      _getJson('/api/movies/genres/${Uri.encodeComponent(genre)}', ttl: ttl)
          .then((j) => GenreView.fromJson(j))
          .catchError((e) => Future<GenreView>.error(e));

  /// GET /api/movies/1
  Future<MovieView> movie(int id, {Duration? ttl}) async =>
      _getJson('/api/movies/$id', ttl: ttl)
          .then((j) => MovieView.fromJson(j))
          .catchError((e) => Future<MovieView>.error(e));

  /// GET /api/movies/1/playlist
  Future<Spiff> moviePlaylist(int id, {Duration? ttl}) async =>
      spiff('/api/movies/$id/playlist', ttl: ttl);

  /// GET /api/profiles/1
  Future<ProfileView> profile(int id, {Duration? ttl}) async =>
      _getJson('/api/profiles/$id', ttl: ttl)
          .then((j) => ProfileView.fromJson(j))
          .catchError((e) => Future<ProfileView>.error(e));

  /// GET /api/podcasts
  Future<PodcastsView> podcasts({Duration? ttl}) async =>
      _getJson('/api/podcasts', ttl: ttl)
          .then((j) => PodcastsView.fromJson(j))
          .catchError((e) => Future<PodcastsView>.error(e));

  /// GET /api/series/1
  Future<SeriesView> series(int id, {Duration? ttl}) async =>
      _getJson('/api/series/$id', ttl: ttl)
          .then((j) => SeriesView.fromJson(j))
          .catchError((e) => Future<SeriesView>.error(e));

  /// GET /api/series/1/playlist
  Future<Spiff> seriesPlaylist(int id, {Duration? ttl}) async =>
      spiff('/api/series/$id/playlist', ttl: ttl);

  /// GET /api/episodes/1
  Future<EpisodeView> episode(int id, {Duration? ttl}) async =>
      _getJson('/api/episodes/$id', ttl: ttl)
          .then((j) => EpisodeView.fromJson(j))
          .catchError((e) => Future<EpisodeView>.error(e));

  /// GET /api/progress
  Future<ProgressView> progress({Duration? ttl}) async =>
      _getJson('/api/progress', ttl: ttl)
          .then((j) => ProgressView.fromJson(j))
          .catchError((e) => Future<ProgressView>.error(e));

  /// POST /api/progress
  Future<int> updateProgress(Offset offset, {void Function()? onError}) async {
    try {
      print('updateProgress $offset');
      final result = await _postJson('/api/progress', offset.toJson(),
          requireCookie: true);
      print('updateProgress got $result');
      return result['_statusCode'];
    } on ClientException {
      return HttpStatus.badRequest;
    }
  }

  Future deleteProgress(Offset offset) async {
    return _delete('/api/progress/${offset.id}');
  }

  /// Download locatable to a file with optional retries.
  Future download(Locatable d, {int retries = 0}) async {
    if (_downloadInProgress(d)) {
      print('download ${d.location} already in progress');
      // don't allow duplicate downloads
      return;
    }
    for (;;) {
      try {
        return await _download(d);
      } catch (err) {
        print(err);
        if (retries > 0) {
          // try again
          retries--;
          continue;
        }
        rethrow;
      } finally {
        _downloadSnapshotRemove(d);
      }
    }
  }

  /// Download locatable to a file.
  Future _download(Locatable d) async {
    final cache = TrackCache();
    final result = await cache.get(d);
    if (result is File) {
      return Future.value();
    }

    if (!allowDownloads) {
      return Future.error(ClientError('downloads not allowed'));
    }

    final cookie = await _getCookie();
    final completer = Completer();
    final baseUrl = await getEndpoint();
    final file = await cache.create(d);
    print('download file is $file');

    HttpClient()
        .getUrl(Uri.parse('$baseUrl${d.location}'))
        .then((request) {
          request.headers.add(HttpHeaders.cookieHeader, '$cookieName=$cookie');
          return request.close();
        })
        .then((response) {
          final sink = file.openWrite();
          final snap = _SnapshotSink(d);
          response.listen((data) {
            sink.add(data);
            snap.add(data.length);
          }, onDone: () {
            sink.close();
            snap.close();
            cache.put(d, file);
            completer.complete();
          }, onError: (err) {
            completer.completeError(err); // TODO need to throw?
          });
        })
        .timeout(downloadTimeout)
        .catchError((e) {
          if (file.existsSync()) {
            file.deleteSync();
          }
          completer.completeError(e);
        });
    return completer.future;
  }

  /// Download
  Future<List<bool>> downloadSpiffTracks(Spiff spiff) async {
    final result = <bool>[];
    for (var t in spiff.playlist.tracks) {
      await download(t)
          .then((v) => result.add(true))
          .catchError((e) => result.add(false));
    }
    return result;
  }

  /// Obtain the Uri to playback/stream a resource. This will either be a local
  /// file from the cache or a url indirectly pointing to s3 bucket item.
  Future<Uri> locate(Locatable d) async {
    if (d.location.startsWith("http")) {
      // already located or internet radio
      return Uri.parse(d.location);
    }
    final cache = TrackCache();
    final result = await cache.get(d);
    if (result is File) {
      return result.uri;
    } else {
      final baseUrl = await getEndpoint();
      return Uri.parse('$baseUrl${d.location}');
    }
  }
}
