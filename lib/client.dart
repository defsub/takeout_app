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
  static const baseUrl = 'https://defsub.com';
  static const prefsCookie = 'client_cookie';
  static const cookieName = 'Takeout';

  static const locationTTL = Duration(hours: 1);
  static const playlistTTL = Duration(minutes: 1);
  static const downloadTimeout = Duration(minutes: 5);

  String _cookie;

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
        result.readAsString().then((String body) {
          completer.complete(jsonDecode(body));
        });
        return completer.future;
      }
    }

    print('$baseUrl/$uri');
    final response = await http.get('$baseUrl$uri',
        headers: {HttpHeaders.cookieHeader: '$cookieName=$cookie'});
    print('got ${response.statusCode}');
    if (response.statusCode != HttpStatus.ok) {
      throw ClientException(
          statusCode: response.statusCode,
          url: response.request.url.toString());
    }
    print('got response ${response.body}');
    if (cacheable) {
      cache.put(uri, response.body);
    }
    return jsonDecode(response.body);
  }

  /// no cookie, no caching
  Future<Map<String, dynamic>> _postJson(
      String uri, Map<String, dynamic> json) async {
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
      print('got response ${response.body}');
      return jsonDecode(response.body);
    });
  }

  /// no caching
  Future<PatchResult> _patchJson(
      String uri, List<Map<String, dynamic>> json) async {
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
            completer.complete(PatchResult(HttpStatus.ok, jsonDecode(response.body)));
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

  // TODO url encode q
  // GET /api/search?q=query
  Future<SearchView> search(String q) async =>
      _getJson('/api/search?q=$q').then((j) => SearchView.fromJson(j));

  /// GET /api/home
  Future<HomeView> home() async =>
      _getJson('/api/home').then((j) => HomeView.fromJson(j));

  /// GET /api/artists
  Future<ArtistsView> artists() async =>
      _getJson('/api/artists').then((j) => ArtistsView.fromJson(j));

  /// GET /api/artists/1
  Future<ArtistView> artist(int id) async =>
      _getJson('/api/artists/$id').then((j) => ArtistView.fromJson(j));

  /// GET /api/artists/1/singles
  Future<SinglesView> artistSingles(int id) async =>
      _getJson('/api/artists/$id/singles').then((j) => SinglesView.fromJson(j));

  /// GET /api/artists/1/popular
  Future<PopularView> artistPopular(int id) async =>
      _getJson('/api/artists/$id/popular').then((j) => PopularView.fromJson(j));

  /// GET /api/releases/1
  Future<ReleaseView> release(int id) async =>
      _getJson('/api/releases/$id').then((j) => ReleaseView.fromJson(j));

  /// GET /api/releases/1/playlist
  Future<Spiff> releasePlaylist(int id) async =>
      _getJson('/api/releases/$id/playlist').then((j) => Spiff.fromJson(j));

  /// GET /api/tracks/1/location
  // Future<Location> location(Locatable d) async {
  //   return _getJson(d.location, ttl: locationTTL)
  //       .then((j) => Location.fromJson(j));
  // }

  /// GET /api/playlist
  Future<Spiff> playlist() async =>
      _getJson('/api/playlist', ttl: playlistTTL).then((j) => Spiff.fromJson(j));

  /// GET /api/radio
  Future<RadioView> radio() async =>
      _getJson('/api/radio').then((j) => RadioView.fromJson(j));

  /// GET /api/channels/1
  Future<Spiff> station(int id) async =>
      _getJson('/api/station/$id').then((j) => Spiff.fromJson(j));

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

    HttpClient()
        .getUrl(Uri.parse('$baseUrl${d.location}'))
        .then((request) {
          request.headers.add(HttpHeaders.cookieHeader, '$cookieName=$cookie');
          return request.close();
        })
        .then((response) {
          cache.put(d).then((sink) => response.pipe(sink).then((v) {
                completer.complete();
              }).catchError((e) {
                completer.completeError(e);
              }));
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
  Future<List<bool>> downloadStation(Station s) async {
    final spiff = await station(s.id);
    return downloadSpiff(spiff);
  }

  /// Download
  Future<List<bool>> downloadSpiff(Spiff spiff) async {
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
    return downloadSpiff(spiff);
  }

  /// Obtain the Uri to playback/stream a resource. This will either be a local
  /// file from the cache or a url indirectly pointing to s3 bucket item.
  Future<Uri> locate(Locatable d) async {
    final cache = TrackCache();
    final result = await cache.get(d);
    if (result is File) {
      return result.uri;
    } else {
      // TODO wifi
      return Uri.parse('$baseUrl${d.location}');
    }
  }
}
