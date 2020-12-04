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
import 'dart:math';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:takeout_app/playlist.dart';
import 'package:rxdart/rxdart.dart';

import 'client.dart';
import 'music.dart';
import 'spiff.dart';
import 'cache.dart';
import 'cover.dart';
import 'global.dart';

class DownloadsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Downloads')),
        body: SingleChildScrollView(
            child: Column(
          children: [
            Container(child: DownloadListWidget()),
          ],
        )));
  }
}

class DownloadListWidget extends StatefulWidget {
  @override
  DownloadListState createState() => DownloadListState();
}

class DownloadListState extends State<DownloadListWidget> {
  Random _random = Random();

  @override
  void initState() {
    super.initState();
    SpiffCache.entries(); // prime the cache
  }

  String _pickCover(Spiff spiff) {
    if (spiff.playlist.image != null && spiff.playlist.image.isNotEmpty) {
      return spiff.playlist.image;
    }
    int pick = _random.nextInt(spiff.playlist.tracks.length);
    return spiff.playlist.tracks[pick].image;
  }

  String _size(Spiff spiff) {
    return '${spiff.size ~/ megabyte} MB';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: Downloads.downloadsSubject,
        builder: (context, snapshot) {
          final entries = snapshot.data ?? [];
          return Column(children: [
            ...entries.map((entry) => Container(
                child: ListTile(
                    leading: cover(_pickCover(entry)),
                    trailing: Icon(Icons.playlist_play),
                    onTap: () => {_onDownload(entry)},
                    title: Text(entry.playlist.title),
                    subtitle: Text(
                        '${entry.playlist.creator} \u2022 ${_size(entry)}'))))
          ]);
        });
  }

  void _onDownload(Spiff spiff) {
    MediaQueue.playSpiff(spiff);
  }
}

class Downloads {
  static const _dir = 'downloads';

  static String _downloadFileName(Spiff spiff) {
    var name = spiff.playlist.title ?? 'download';
    name = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '$name.json';
  }

  static Future<File> _downloadFile(String fileName) async {
    return await checkAppDir(_dir).then((dir) {
      return File('${dir.path}/$fileName');
    });
  }

  static Future<void> _saveAs(Spiff spiff, File file) {
    final completer = Completer<void>();
    final data = utf8.encode(jsonEncode(spiff.toJson()));
    file.writeAsBytes(data).then((f) {
      completer.complete();
    }).catchError((e) {
      print(e);
      completer.completeError(e);
    });
    return completer.future;
  }

  static Future<bool> _download(
      Client client, Future<Spiff> Function() fetchSpiff) async {
    final completer = Completer<bool>();
    fetchSpiff().then((spiff) {
      _downloadFile(_downloadFileName(spiff)).then((file) {
        // override location with local file URI
        spiff = spiff.copyWith(
            playlist: spiff.playlist.copyWith(location: file.uri.toString()));
        print('download to $file');
        _downloads.add(spiff);
        SpiffCache.put(spiff);
        _broadcast();
        _saveAs(spiff, file).then((_) {
          client.downloadSpiffTracks(spiff).then((result) {
            completer.complete(result.length == spiff.playlist.tracks.length &&
                !result.any((e) => e == false));
          }).catchError((error) => completer.completeError(error));
        }).catchError(((error) => completer.completeError(error)));
      }).catchError((error) => completer.completeError(error));
    });
    return completer.future;
  }

  static Future<bool> downloadRelease(Release release) async {
    final client = Client();
    showSnackBar('Downloading ${release.name}');
    return _download(client, () => client.releasePlaylist(release.id))
        .whenComplete(() => showSnackBar('Finished ${release.name}'));
  }

  static Future<bool> downloadArtist(Artist artist) async {
    final client = Client();
    showSnackBar('Downloading ${artist.name}');
    return _download(client, () => client.artistPlaylist(artist.id))
        .whenComplete(() => showSnackBar('Finished ${artist.name}'));
  }

  static Future<bool> downloadStation(Station station) async {
    final client = Client();
    showSnackBar('Downloading ${station.name}');
    return _download(client, () => client.station(station.id))
        .whenComplete(() => showSnackBar('Finished ${station.name}'));
  }

  static final List<Spiff> _downloads = [];
  static final downloadsSubject = BehaviorSubject<List<Spiff>>();

  static void _broadcast() {
    downloadsSubject.add(_downloads);
  }

  static Future<void> load() async {
    final completer = Completer();
    final dir = await checkAppDir(_dir);
    final list = await dir.list().toList();
    await Future.forEach(list, (file) async {
      if (file.path.endsWith('.json')) {
        final spiff = await Spiff.fromFile(file);
        _downloads.add(spiff);
        SpiffCache.put(spiff);
      }
    }).whenComplete(() {
      _broadcast();
      completer.complete();
    });
    return completer.future;
  }
}
