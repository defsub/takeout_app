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
import 'package:logging/logging.dart';

import 'package:takeout_app/tokens/repository.dart';
import 'package:takeout_app/client/provider.dart';
import 'package:takeout_app/cache/json_repository.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/settings/repository.dart';

import 'model.dart';

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

class _ClientError extends Error {
  final Object? message;

  /// Creates a client error with the provided [message].
  _ClientError([this.message]);

  String toString() {
    if (message != null) {
      return 'Client error: ${Error.safeToString(message)}';
    }
    return 'Client error';
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

// class DownloadSnapshot {
//   final int size;
//   final int offset;
//   final Object? err;
//
//   const DownloadSnapshot(this.size, this.offset, {this.err});
//
//   bool hasError() {
//     return err != null;
//   }
//
//   bool isComplete() {
//     return offset == size;
//   }
//
//   // Value used for progress display.
//   double get value {
//     return offset.toDouble() / size;
//   }
// }

// class _SnapshotSink extends Sink<int> {
//   final Locatable locatable;
//   int offset = 0;
//
//   _SnapshotSink(this.locatable);
//
//   void add(int chunk) {
//     offset += chunk;
//     Client._downloadSnapshotUpdate(locatable, offset);
//   }
//
//   void close() {}
// }

class _ClientWithUserAgent extends http.BaseClient {
  static final log = Logger('HttpClient');

  final http.Client _client;
  final String _userAgent;

  _ClientWithUserAgent(this._client, this._userAgent);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    log.finest('${request.method} ${request.url.toString()}');
    request.headers['User-Agent'] = _userAgent;
    return _client.send(request);
  }
}

typedef Future<T> FutureGenerator<T>();

class TakeoutClient implements ClientProvider {
  static final log = Logger('Client');

  static const settingAccessToken = 'access_token';
  static const settingMediaToken = 'media_token';
  static const settingRefreshToken = 'refresh_token';
  static const settingEndpoint = 'endpoint';
  static const fieldAccessToken = 'AccessToken';
  static const fieldRefreshToken = 'RefreshToken';
  static const fieldMediaToken = 'MediaToken';
  static const _defaultPlaylist = '/api/playlist';

  static const locationTTL = Duration(hours: 1);
  static const playlistTTL = Duration(minutes: 1);
  static const defaultTTL = Duration(hours: 24);
  static const defaultTimeout = Duration(seconds: 5);
  static const downloadTimeout = Duration(minutes: 5);

  static Uri _defaultPlaylistUri = Uri.parse(_defaultPlaylist);

  static Uri defaultPlaylistUri() {
    return _defaultPlaylistUri;
  }

  bool Function()? _allowDownloads;

  final SettingsRepository settingsRepository;
  final TokenRepository tokenRepository;
  final JsonCacheRepository jsonCacheRepository;
  final String _userAgent;
  late http.Client _client;

  TakeoutClient(
      {required this.settingsRepository,
      required this.tokenRepository,
      required this.jsonCacheRepository,
      String? userAgent})
      : _userAgent = userAgent ?? 'Takeout-App' {
    _client = _ClientWithUserAgent(http.Client(), _userAgent);
  }

  http.Client get client => _client;

  String get userAgent => _userAgent;

  bool get allowDownloads =>
      _allowDownloads != null ? _allowDownloads!() : true;

  String get endpoint {
    final settings = settingsRepository.settings;
    if (settings == null) {
      throw StateError('no settings');
    }
    if (settings.endpoint.isEmpty) {
      throw StateError('no endpoint');
    }
    return settings.endpoint;
  }

  // Future<void> setEndpoint(String? v) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   _endpoint = v;
  //   if (v == null) {
  //     prefs.remove(settingEndpoint);
  //   } else {
  //     prefs.setString(settingEndpoint, v);
  //   }
  // }
  //
  // Future<String> getEndpoint() async {
  //   if (_endpoint == null) {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     if (prefs.containsKey(settingEndpoint)) {
  //       _endpoint = prefs.getString(settingEndpoint);
  //     }
  //   }
  //   return _endpoint!;
  // }
  //
  // Future<void> _clearTokens() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   _accessToken = null;
  //   _mediaToken = null;
  //   await prefs.remove(settingAccessToken);
  //   await prefs.remove(settingMediaToken);
  //   await prefs.remove(settingRefreshToken);
  // }
  //
  // // clear and refresh all tokens
  // Future<void> _setTokens(Map<String, dynamic> result) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //
  //   await _clearTokens();
  //   await _refreshTokens(result);
  //
  //   // media token
  //   _mediaToken = result[fieldMediaToken];
  //   if (_mediaToken != null) {
  //     await prefs.setString(settingMediaToken, _mediaToken!);
  //   }
  // }
  //
  // // refresh access and refresh tokens (not media)
  // Future<void> _refreshTokens(Map<String, dynamic> result) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //
  //   if (result.containsKey(fieldAccessToken)) {
  //     _accessToken = result[fieldAccessToken];
  //     if (_accessToken != null) {
  //       await prefs.setString(settingAccessToken, _accessToken!);
  //     }
  //   }
  //
  //   if (result.containsKey(fieldRefreshToken)) {
  //     final String? refreshToken = result[fieldRefreshToken];
  //     if (refreshToken != null) {
  //       await prefs.setString(settingRefreshToken, refreshToken);
  //     }
  //   }
  // }
  //
  // Future<Duration> _tokenTimeRemaining(String? token) async {
  //   if (token == null) {
  //     return Duration.zero;
  //   }
  //   final expired = JwtDecoder.isExpired(token);
  //   log.fine('expired $expired (${JwtDecoder.getExpirationDate(token)})');
  //   return JwtDecoder.getRemainingTime(token);
  // }
  //
  // Future<String?> getAccessToken() async => _getAccessToken();
  //
  // Future<String?> _getAccessToken() async {
  //   if (_accessToken == null) {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     if (prefs.containsKey(settingAccessToken)) {
  //       _accessToken = prefs.getString(settingAccessToken);
  //     }
  //   }
  //   // final duration = await _tokenTimeRemaining(_accessToken);
  //   // log.fine('access token remaining $duration');
  //   return _accessToken;
  // }
  //
  // Future<String?> _getMediaToken() async {
  //   if (_mediaToken == null) {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     if (prefs.containsKey(settingMediaToken)) {
  //       _mediaToken = prefs.getString(settingMediaToken);
  //     }
  //   }
  //   // final duration = await _tokenTimeRemaining(_mediaToken);
  //   // log.fine('media token remaining $duration');
  //   return _mediaToken;
  // }
  //
  // Future<String?> _getRefreshToken() async {
  //   String? token;
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   if (prefs.containsKey(settingRefreshToken)) {
  //     token = prefs.getString(settingRefreshToken);
  //   }
  //   return token;
  // }

  Map<String, String> _headersWithAccessToken() {
    final accessToken = tokenRepository.accessToken;
    return {
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  Map<String, String> _headersWithRefreshToken() {
    final refreshToken = tokenRepository.refreshToken;
    return {
      if (refreshToken != null) 'Authorization': 'Bearer $refreshToken',
    };
  }

  Map<String, String> headersWithMediaToken() {
    final mediaToken = tokenRepository.mediaToken;
    return {
      if (mediaToken != null) 'Authorization': 'Bearer $mediaToken',
      HttpHeaders.userAgentHeader: _userAgent,
    };
  }

  Map<String, String> headers() {
    return {HttpHeaders.userAgentHeader: userAgent};
  }

  // Future<bool> needLogin() async {
  //   final token = await _getRefreshToken();
  //   // TODO check age?
  //   return token == null;
  // }
  //
  bool _haveTokens() {
    return tokenRepository.refreshToken != null &&
        tokenRepository.accessToken != null;
  }

  // Future<void> logout() async {
  //   return _clearTokens();
  // }

  Future<Map<String, dynamic>> _getJson(String uri,
      {bool cacheable = true, Duration? ttl}) async {
    // final token = await _getAccessToken();
    // if (token == null) {
    //   throw ClientException(
    //     statusCode: HttpStatus.networkAuthenticationRequired,
    //   );
    // }

    ttl = ttl ?? defaultTTL;
    Map<String, dynamic>? cachedJson = null;

    if (cacheable) {
      final result = await jsonCacheRepository.get(uri, ttl: ttl);
      if (result.exists) {
        log.fine('cached $uri expired is ${result.expired}');
        try {
          cachedJson = await result.read();
        } catch (e) {
          // can't parse cached json, will try to replace it
          log.warning(e);
        }
        if (cachedJson != null && result.expired == false) {
          // not expired so use the cached value
          return cachedJson;
        }
      }
    }

    try {
      log.fine('GET $endpoint$uri');
      final response = await _client
          .get(Uri.parse('$endpoint$uri'), headers: _headersWithAccessToken())
          .timeout(defaultTimeout);
      log.fine('got ${response.statusCode}');
      if (response.statusCode != HttpStatus.ok) {
        if (response.statusCode >= 500 && cachedJson != null) {
          return cachedJson;
        }
        throw ClientException(
            statusCode: response.statusCode,
            url: response.request?.url.toString());
      }
      log.finest('got response ${response.body}');
      if (cacheable) {
        jsonCacheRepository.put(uri, response.bodyBytes);
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e, stackTrace) {
      if (e is SocketException || e is TimeoutException || e is TlsException) {
        if (cachedJson != null) {
          log.warning('got error $e; using cached json');
          return cachedJson;
        }
      }
      return Future<Map<String, dynamic>>.error(e, stackTrace);
    }
  }

  Future _delete(String uri) async {
    final token = tokenRepository.accessToken;
    if (token == null) {
      throw ClientException(
        statusCode: HttpStatus.networkAuthenticationRequired,
      );
    }

    try {
      log.fine('DELETE $endpoint$uri');
      final response = await _client.delete(Uri.parse('$endpoint$uri'),
          headers: _headersWithAccessToken());
      log.fine('got ${response.statusCode}');
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
      {bool requireAuth = false}) async {
    Map<String, String> headers = {
      HttpHeaders.contentTypeHeader: ContentType.json.toString()
    };

    if (requireAuth) {
      final token = tokenRepository.accessToken;
      if (token == null) {
        throw ClientException(
          statusCode: HttpStatus.networkAuthenticationRequired,
        );
      }
      headers.addAll(_headersWithAccessToken());
    }

    log.fine('$endpoint$uri');
    log.finer(jsonEncode(json));
    return _client
        .post(Uri.parse('$endpoint$uri'),
            headers: headers, body: jsonEncode(json))
        .then((response) {
      log.fine('response ${response.statusCode}');
      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.noContent) {
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

  /// no caching
  Future<PatchResult> _patchJson(
      String uri, List<Map<String, dynamic>> json) async {
    final token = tokenRepository.accessToken;
    if (token == null) {
      return Future.error(ClientException(
        statusCode: HttpStatus.networkAuthenticationRequired,
      ));
    }

    log.fine('$endpoint$uri');
    log.finer(jsonEncode(json));
    final headers = await _headersWithAccessToken();
    headers[HttpHeaders.contentTypeHeader] = 'application/json-patch+json';
    return _client
        .patch(Uri.parse('$endpoint$uri'),
            headers: headers, body: jsonEncode(json))
        .then((response) {
      log.fine('response ${response.statusCode}');
      if (response.statusCode == HttpStatus.ok) {
        return PatchResult(
            HttpStatus.ok, jsonDecode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == HttpStatus.noContent) {
        return PatchResult(HttpStatus.noContent, {});
      } else {
        return Future.error(ClientException(
            statusCode: response.statusCode,
            url: response.request?.url.toString()));
      }
    });
  }

  /// POST /api/token
  Future<bool> login(String user, String pass) async {
    var success = false;
    final json = {'User': user, 'Pass': pass};
    try {
      final result = await _postJson('/api/token', json);
      log.fine(result);
      if (result.containsKey(fieldAccessToken) &&
          result.containsKey(fieldMediaToken) &&
          result.containsKey(fieldRefreshToken)) {
        tokenRepository.add(
            accessToken: result[fieldAccessToken],
            mediaToken: result[fieldMediaToken],
            refreshToken: result[fieldRefreshToken]);
        success = true;
      }
      return success;
    } on ClientException {
      return false;
    }
  }

  /// GET /api/token
  Future<bool> _refreshAccessToken() async {
    final uri = '/api/token';
    bool success = false;
    try {
      log.fine('GET $endpoint$uri');
      final response = await _client.get(Uri.parse('$endpoint$uri'),
          headers: await _headersWithRefreshToken());
      log.fine('got ${response.statusCode}');
      if (response.statusCode == 200) {
        final result = jsonDecode(utf8.decode(response.bodyBytes));
        log.fine(result);
        if (result.containsKey(fieldAccessToken) &&
            result.containsKey(fieldRefreshToken)) {
          tokenRepository.add(
              accessToken: result[fieldAccessToken],
              refreshToken: result[fieldRefreshToken]);
          success = true;
        }
      }
    } on TlsException catch (e) {
      return Future.error(e);
    }
    return success;
  }

// TODO ensure mutex to avoid multiple access tokens
  Future<T> _retry<T>(FutureGenerator<T> aFuture) async {
    try {
      return await aFuture();
    } catch (e) {
      log.fine('in retry got $e');
      if (e is ClientException && e.authenticationFailed && _haveTokens()) {
        // have refresh token, try to refresh access token
        final result = await _refreshAccessToken();
        log.fine('in retry result is $result');
        if (result == true) {
          return await aFuture();
        }
      }
      rethrow;
    }
  }

  /// GET /api/search?q=query (no cache by default)
  Future<SearchView> search(String q, {Duration? ttl = Duration.zero}) async =>
      _retry<SearchView>(() =>
          _getJson('/api/search?q=${Uri.encodeQueryComponent(q)}', ttl: ttl)
              .then((j) => SearchView.fromJson(j))
              .catchError((e) => Future<SearchView>.error(e)));

  /// GET /api/index
  Future<IndexView> index({Duration? ttl}) async =>
      _retry<IndexView>(() => _getJson('/api/index', ttl: ttl)
          .then((j) => IndexView.fromJson(j))
          .catchError((e) => Future<IndexView>.error(e)));

  /// GET /api/home
  Future<HomeView> home({Duration? ttl}) async =>
      _retry<HomeView>(() => _getJson('/api/home', ttl: ttl)
          .then((j) => HomeView.fromJson(j))
          .catchError((e) => Future<HomeView>.error(e)));

  /// GET /api/artists
  Future<ArtistsView> artists({Duration? ttl}) async =>
      _retry<ArtistsView>(() => _getJson('/api/artists', ttl: ttl)
          .then((j) => ArtistsView.fromJson(j))
          .catchError((e) => Future<ArtistsView>.error(e)));

  /// GET /api/artists/1
  Future<ArtistView> artist(int id, {Duration? ttl}) async =>
      _retry<ArtistView>(() => _getJson('/api/artists/$id', ttl: ttl)
          .then((j) => ArtistView.fromJson(j))
          .catchError((e) => Future<ArtistView>.error(e)));

  /// GET /api/artists/1/singles
  Future<SinglesView> artistSingles(int id, {Duration? ttl}) async =>
      _retry<SinglesView>(() => _getJson('/api/artists/$id/singles', ttl: ttl)
          .then((j) => SinglesView.fromJson(j))
          .catchError((e) => Future<SinglesView>.error(e)));

  /// GET /api/artists/1/singles/playlist
  Future<Spiff> artistSinglesPlaylist(int id, {Duration? ttl}) async =>
      spiff('/api/artists/$id/singles/playlist', ttl: ttl);

  /// GET /api/artists/1/popular
  Future<PopularView> artistPopular(int id, {Duration? ttl}) async =>
      _retry<PopularView>(() => _getJson('/api/artists/$id/popular', ttl: ttl)
          .then((j) => PopularView.fromJson(j))
          .catchError((e) => Future<PopularView>.error(e)));

  /// GET /api/artists/1/popular/playlist
  Future<Spiff> artistPopularPlaylist(int id, {Duration? ttl}) async =>
      spiff('/api/artists/$id/popular/playlist', ttl: ttl);

  /// GET /api/artists/1/playlist
  Future<Spiff> artistPlaylist(int id, {Duration? ttl}) async =>
      spiff('/api/artists/$id/playlist', ttl: ttl);

  /// GET /api/artists/1/radio/playlist
  Future<Spiff> artistRadio(int id, {Duration? ttl}) async =>
      spiff('/api/artists/$id/radio/playlist', ttl: ttl);

  /// GET /api/releases/1
  Future<ReleaseView> release(int id, {Duration? ttl}) async =>
      _retry<ReleaseView>(() => _getJson('/api/releases/$id', ttl: ttl)
          .then((j) => ReleaseView.fromJson(j))
          .catchError((e) => Future<ReleaseView>.error(e)));

  /// GET /api/releases/1/playlist
  Future<Spiff> releasePlaylist(int id, {Duration? ttl}) async =>
      spiff('/api/releases/$id/playlist', ttl: ttl);

  /// GET /api/playlist
  Future<Spiff> playlist() async => spiff('/api/playlist', ttl: playlistTTL);

  /// GET /api/radio
  Future<RadioView> radio({Duration? ttl}) async =>
      _retry<RadioView>(() => _getJson('/api/radio', ttl: ttl)
          .then((j) => RadioView.fromJson(j))
          .catchError((e) => Future<RadioView>.error(e)));

  /// GET /api/radio/stations/1
  Future<Spiff> station(int id, {Duration? ttl}) async =>
      spiff('/api/radio/stations/$id/playlist', ttl: ttl);

  /// GET /path -> spiff
  Future<Spiff> spiff(String path, {Duration? ttl}) async =>
      _retry<Spiff>(() => _getJson(path, ttl: ttl)
          .then((j) => Spiff.fromJson(j))
          .catchError((e) => Future<Spiff>.error(e)));

  Future<PatchResult> patch(List<Map<String, dynamic>> body) async =>
      _retry<PatchResult>(() => _patchJson('/api/playlist', body));

  /// GET /api/movies
  Future<MoviesView> movies({Duration? ttl}) async =>
      _retry<MoviesView>(() => _getJson('/api/movies', ttl: ttl)
          .then((j) => MoviesView.fromJson(j))
          .catchError((e) => Future<MoviesView>.error(e)));

  /// GET /api/movies
  Future<GenreView> moviesGenre(String genre, {Duration? ttl}) async =>
      _retry<GenreView>(() =>
          _getJson('/api/movies/genres/${Uri.encodeComponent(genre)}', ttl: ttl)
              .then((j) => GenreView.fromJson(j))
              .catchError((e) => Future<GenreView>.error(e)));

  /// GET /api/movies/1
  Future<MovieView> movie(int id, {Duration? ttl}) async =>
      _retry<MovieView>(() => _getJson('/api/movies/$id', ttl: ttl)
          .then((j) => MovieView.fromJson(j))
          .catchError((e) => Future<MovieView>.error(e)));

  /// GET /api/movies/1/playlist
  Future<Spiff> moviePlaylist(int id, {Duration? ttl}) async =>
      spiff('/api/movies/$id/playlist', ttl: ttl);

  /// GET /api/profiles/1
  Future<ProfileView> profile(int id, {Duration? ttl}) async =>
      _retry<ProfileView>(() => _getJson('/api/profiles/$id', ttl: ttl)
          .then((j) => ProfileView.fromJson(j))
          .catchError((e) => Future<ProfileView>.error(e)));

  /// GET /api/podcasts
  Future<PodcastsView> podcasts({Duration? ttl}) async =>
      _retry<PodcastsView>(() => _getJson('/api/podcasts', ttl: ttl)
          .then((j) => PodcastsView.fromJson(j))
          .catchError((e) => Future<PodcastsView>.error(e)));

  /// GET /api/series/1
  Future<SeriesView> series(int id, {Duration? ttl}) async =>
      _retry<SeriesView>(() => _getJson('/api/series/$id', ttl: ttl)
          .then((j) => SeriesView.fromJson(j))
          .catchError((e) => Future<SeriesView>.error(e)));

  /// GET /api/series/1/playlist
  Future<Spiff> seriesPlaylist(int id, {Duration? ttl}) async =>
      spiff('/api/series/$id/playlist', ttl: ttl);

  /// GET /api/episodes/1
  Future<EpisodeView> episode(int id, {Duration? ttl}) async =>
      _getJson('/api/episodes/$id', ttl: ttl)
          .then((j) => EpisodeView.fromJson(j))
          .catchError((e) => Future<EpisodeView>.error(e));

  /// GET /api/episodes/1/playlist
  Future<Spiff> episodePlaylist(int id, {Duration? ttl}) async =>
      spiff('/api/episode/$id/playlist', ttl: ttl);

  /// GET /api/progress
  Future<ProgressView> progress({Duration? ttl}) async =>
      _retry<ProgressView>(() => _getJson('/api/progress', ttl: ttl)
          .then((j) => ProgressView.fromJson(j))
          .catchError((e) => Future<ProgressView>.error(e)));

  /// POST /api/progress
  Future<int> updateProgress(Offsets offsets) async {
    try {
      log.fine('updateProgress $offsets');
      final result = await _retry(() =>
          _postJson('/api/progress', offsets.toJson(), requireAuth: true));
      log.fine('updateProgress got $result');
      return result['statusCode'];
    } on ClientException {
      return HttpStatus.badRequest;
    }
  }

// Future deleteProgress(Offset offset) async {
//   return _retry(() => _delete('/api/progress/${offset.id}'));
// }

  /// GET /api/activity
  Future<ActivityView> activity({Duration? ttl}) async =>
      _retry<ActivityView>(() => _getJson('/api/activity', ttl: ttl)
          .then((j) => ActivityView.fromJson(j))
          .catchError((e) => Future<ActivityView>.error(e)));

  /// POST /api/activity
  Future<int> updateActivity(Events events) async {
    try {
      log.fine('updateActivity $events');
      final result = await _retry(
          () => _postJson('/api/activity', events.toJson(), requireAuth: true));
      log.fine('updateActivity got $result');
      return result['statusCode'];
    } on ClientException {
      return HttpStatus.badRequest;
    }
  }

  /// GET /api/activity/tracks/recent/playlist
  Future<Spiff> recentTracks({Duration? ttl}) async =>
      spiff('/api/activity/tracks/recent/playlist', ttl: ttl);

  /// GET /api/activity/tracks/popular/playlist
  Future<Spiff> popularTracks({Duration? ttl}) async =>
      spiff('/api/activity/tracks/popular/playlist', ttl: ttl);

  /// Download locatable to a file with optional retries.
  Future<int> download(Uri uri, File file, int size,
      {Sink<int>? progress, int retries = 0}) async {
    for (;;) {
      try {
        return await _retry<int>(
            () => _download(uri, file, size, progress: progress));
      } catch (err) {
        log.warning(err);
        if (retries > 0) {
          // try again
          retries--;
          continue;
        }
        rethrow;
      }
    }
  }

  /// Download locatable to a file.
  Future<int> _download(Uri uri, File file, int size,
      {Sink<int>? progress}) async {
    final completer = Completer<int>();
    log.fine('download file is $file');

    HttpClient()
        .getUrl(uri)
        .then((request) async {
          final headers = await headersWithMediaToken();
          headers.forEach((k, v) {
            request.headers.set(k, v);
          });
          return request.close();
        })
        .then((response) {
          final sink = file.openWrite();
          response.listen((data) {
            sink.add(data);
            if (progress != null) progress.add(data.length);
          }, onDone: () {
            if (progress != null) progress.close();
            sink.flush().whenComplete(() => sink.close().whenComplete(() {
                  if (size == file.lengthSync()) {
                    completer.complete(size);
                  } else {
                    throw _ClientError('${size} != ${file.lengthSync()}');
                  }
                }));
          }, onError: (err) {
            throw err;
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
    throw UnsupportedError;
    // final result = <bool>[];
    // for (var t in spiff.playlist.tracks) {
    //   await download(t)
    //       .then((v) => result.add(true))
    //       .catchError((e) => result.add(false));
    // }
    // return result;
  }

  /// Obtain the Uri to playback/stream a resource. This will either be a local
  /// file from the cache or a url indirectly pointing to s3 bucket item.
  // Future<Uri> locate(Locatable d) async {
  //   if (d.location.startsWith('http')) {
  //     // already located or internet radio
  //     return Uri.parse(d.location);
  //   }
  //   final result = null; //await trackCacheRepository.get(d);
  //   if (result is File) {
  //     return result.uri;
  //   } else {
  //     return Uri.parse('$endpoint${d.location}');
  //   }
  // }
}
