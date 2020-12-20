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
import 'package:shared_preferences/shared_preferences.dart';

import 'cache.dart';
import 'music.dart';
import 'spiff.dart';

class ClientException implements Exception {
  final int statusCode;
  final String url;

  const ClientException({this.statusCode, this.url});

  String toString() => 'ClientException: $statusCode => $url';
}

abstract class Locatable {
  /// Cache key.
  String get key;

  /// Location URL to get location.
  String get location;
}

class PatchResult {
  final int statusCode;
  final Map<String, dynamic> body;

  PatchResult(this.statusCode, this.body);

  bool notModified() {
    return statusCode == HttpStatus.noContent;
  }

  bool isModified() {
    return statusCode == HttpStatus.ok;
  }

  Spiff toSpiff() {
    return Spiff.fromJson(body);
  }
}

class Client {
  static const prefsCookie = 'client_cookie';
  static const prefsEndpoint = 'endpoint';
  static const cookieName = 'Takeout';

  static const locationTTL = Duration(hours: 1);
  static const playlistTTL = Duration(minutes: 1);
  static const downloadTimeout = Duration(minutes: 5);

  static String _endpoint;
  static String _cookie;
  static String _defaultPlaylistUrl;
  static Uri _defaultPlaylistUri;

  static Future<String> getDefaultPlaylistUrl() async {
    if (_defaultPlaylistUrl == null) {
      final baseUrl = await Client().getEndpoint();
      _defaultPlaylistUrl = '$baseUrl/api/playlist';
    }
    return _defaultPlaylistUrl;
  }

  static Future<Uri> defaultPlaylistUri() async {
    if (_defaultPlaylistUri == null) {
      _defaultPlaylistUri = Uri.parse(await getDefaultPlaylistUrl());
    }
    return _defaultPlaylistUri;
  }

  Future<void> setEndpoint(String v) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _endpoint = v;
    if (v == null) {
      prefs.remove(prefsEndpoint);
    } else {
      prefs.setString(prefsEndpoint, _endpoint);
    }
  }

  Future<String> getEndpoint() async {
    if (_endpoint == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(prefsEndpoint)) {
        _endpoint = prefs.getString(prefsEndpoint);
      }
    }
    return _endpoint;
  }

  Future<void> _setCookie(String v) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _cookie = v;
    if (v == null) {
      prefs.remove(prefsCookie);
    } else {
      prefs.setString(prefsCookie, _cookie);
    }
  }

  Future<String> _getCookie() async {
    if (_cookie == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(prefsCookie)) {
        _cookie = prefs.getString(prefsCookie);
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
    return cookie != null;
  }

  Future<void> logout() async {
    return _setCookie(null);
  }

  Future<Map<String, dynamic>> _getJson(String uri,
      {bool cacheable = true, Duration ttl}) async {
    final cache = JsonCache();
    final cookie = await _getCookie();
    if (cookie == null) {
      throw ClientException(
        statusCode: HttpStatus.networkAuthenticationRequired,
      );
    }

    if (cacheable) {
      final result = await cache.get(uri, ttl: ttl);
      if (result is File) {
        final completer = Completer<Map<String, dynamic>>();
        print('cached $uri');
        result
            .readAsBytes()
            .then((body) => completer.complete(jsonDecode(utf8.decode(body))));
        return completer.future;
      }
    }

    final baseUrl = await getEndpoint();

    print('$baseUrl$uri');
    final response = await http.get('$baseUrl$uri',
        headers: {HttpHeaders.cookieHeader: '$cookieName=$cookie'});
    print('got ${response.statusCode}');
    if (response.statusCode != HttpStatus.ok) {
      throw ClientException(
          statusCode: response.statusCode,
          url: response.request.url.toString());
    }
    // print('got response ${response.body}');
    if (cacheable) {
      cache.put(uri, response.bodyBytes);
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  /// no cookie, no caching
  Future<Map<String, dynamic>> _postJson(
      String uri, Map<String, dynamic> json) async {
    final baseUrl = await getEndpoint();
    print('$baseUrl$uri');
    return http
        .post('$baseUrl$uri',
            headers: {
              HttpHeaders.contentTypeHeader: ContentType.json.toString()
            },
            body: jsonEncode(json))
        .then((response) {
      print('response ${response.statusCode}');
      if (response.statusCode != HttpStatus.ok) {
        throw ClientException(
            statusCode: response.statusCode,
            url: response.request.url.toString());
      }
      // print('got response ${response.body}');
      return jsonDecode(utf8.decode(response.bodyBytes));
    });
  }

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
            .patch('$baseUrl$uri',
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
            completer.complete(PatchResult(HttpStatus.noContent, null));
          } else {
            completer.completeError(ClientException(
                statusCode: response.statusCode,
                url: response.request.url.toString()));
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
          .catchError((e) => Future.error(e));

  /// GET /api/home
  Future<HomeView> home({Duration ttl}) async => _getJson('/api/home', ttl: ttl)
      .then((j) => HomeView.fromJson(j))
      .catchError((e) => Future.error(e));

  /// GET /api/artists
  Future<ArtistsView> artists({Duration ttl}) async =>
      _getJson('/api/artists', ttl: ttl)
          .then((j) => ArtistsView.fromJson(j))
          .catchError((e) => Future.error(e));

  /// GET /api/artists/1
  Future<ArtistView> artist(int id, {Duration ttl}) async =>
      _getJson('/api/artists/$id', ttl: ttl)
          .then((j) => ArtistView.fromJson(j))
          .catchError((e) => Future.error(e));

  /// GET /api/artists/1/singles
  Future<SinglesView> artistSingles(int id, {Duration ttl}) async =>
      _getJson('/api/artists/$id/singles', ttl: ttl)
          .then((j) => SinglesView.fromJson(j))
          .catchError((e) => Future.error(e));

  /// GET /api/artists/1/singles/playlist
  Future<Spiff> artistSinglesPlaylist(int id, {Duration ttl}) async =>
      _getJson('/api/artists/$id/singles/playlist', ttl: ttl)
          .then((j) => Spiff.fromJson(j))
          .catchError((e) => Future.error(e));

  /// GET /api/artists/1/popular
  Future<PopularView> artistPopular(int id, {Duration ttl}) async =>
      _getJson('/api/artists/$id/popular', ttl: ttl)
          .then((j) => PopularView.fromJson(j))
          .catchError((e) => Future.error(e));

  /// GET /api/artists/1/popular/playlist
  Future<Spiff> artistPopularPlaylist(int id, {Duration ttl}) async =>
      _getJson('/api/artists/$id/popular/playlist', ttl: ttl)
          .then((j) => Spiff.fromJson(j))
          .catchError((e) => Future.error(e));

  /// GET /api/artists/1/playlist
  Future<Spiff> artistPlaylist(int id, {Duration ttl}) async =>
      _getJson('/api/artists/$id/playlist', ttl: ttl)
          .then((j) => Spiff.fromJson(j))
          .catchError((e) => Future.error(e));

  /// GET /api/artists/1/radio
  Future<Spiff> artistRadio(int id, {Duration ttl}) async =>
      _getJson('/api/artists/$id/radio', ttl: ttl)
          .then((j) => Spiff.fromJson(j))
          .catchError((e) => Future.error(e));

  /// GET /api/releases/1
  Future<ReleaseView> release(int id, {Duration ttl}) async =>
      _getJson('/api/releases/$id', ttl: ttl)
          .then((j) => ReleaseView.fromJson(j))
          .catchError((e) => Future.error(e));

  /// GET /api/releases/1/playlist
  Future<Spiff> releasePlaylist(int id, {Duration ttl}) async =>
      _getJson('/api/releases/$id/playlist', ttl: ttl)
          .then((j) => Spiff.fromJson(j))
          .catchError((e) => Future.error(e));

  /// GET /api/playlist
  Future<Spiff> playlist() async => _getJson('/api/playlist', ttl: playlistTTL)
      .then((j) => Spiff.fromJson(j));

  /// GET /api/radio
  Future<RadioView> radio({Duration ttl}) async =>
      _getJson('/api/radio', ttl: ttl)
          .then((j) => RadioView.fromJson(j))
          .catchError((e) => Future.error(e));

  /// GET /api/radio/1
  Future<Spiff> station(int id, {Duration ttl}) async =>
      _getJson('/api/radio/$id', ttl: ttl)
          .then((j) => Spiff.fromJson(j))
          .catchError((e) => Future.error(e));

  Future<PatchResult> patch(List<Map<String, dynamic>> body) async =>
      _patchJson('/api/playlist', body);

  /// Download locatable to a file.
  Future download(Locatable d) async {
    final cache = TrackCache();
    final result = await cache.get(d);
    if (result is File) {
      return Future.value();
    }
    final cookie = await _getCookie();
    final completer = Completer();
    final baseUrl = await getEndpoint();

    HttpClient()
        .getUrl(Uri.parse('$baseUrl${d.location}'))
        .then((request) {
          request.headers.add(HttpHeaders.cookieHeader, '$cookieName=$cookie');
          return request.close();
        })
        .then((response) {
          cache.put(d).then((sink) => response
              .pipe(sink)
              .then((v) => completer.complete())
              .catchError((e) => completer.completeError(e)));
        })
        .timeout(downloadTimeout)
        .catchError((e) => completer.completeError(e));
    return completer.future;
  }

  /// Download a list of tracks
  Future<List<bool>> downloadTracks(List<Track> tracks) async {
    final result = List<bool>();
    for (var t in tracks) {
      await download(t)
          .then((v) => result.add(true))
          .catchError((e) => result.add(false));
    }
    return result;
  }

  /// Download
  Future<List<bool>> downloadSpiffTracks(Spiff spiff) async {
    final result = List<bool>();
    for (var t in spiff.playlist.tracks) {
      await download(t)
          .then((v) => result.add(true))
          .catchError((e) => result.add(false));
    }
    return result;
  }

  /// Download
  Future<List<bool>> downloadRelease(Release r) async {
    final spiff = await releasePlaylist(r.id);
    return downloadSpiffTracks(spiff);
  }

  /// Obtain the Uri to playback/stream a resource. This will either be a local
  /// file from the cache or a url indirectly pointing to s3 bucket item.
  Future<Uri> locate(Locatable d) async {
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
