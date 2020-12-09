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
import 'style.dart';
import 'artists.dart';

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

// TODO order - recent, name, count
class DownloadListWidget extends StatefulWidget {
  final int limit;
  final DownloadSortType sortType;

  DownloadListWidget({this.sortType = DownloadSortType.name, this.limit = -1});

  @override
  DownloadListState createState() => DownloadListState(sortType, limit);
}

String _size(Spiff spiff) {
  return '${spiff.size ~/ megabyte} MB';
}

enum DownloadSortType { newest, oldest, name, size }

void _sort(DownloadSortType sortType, List<DownloadEntry> entries) {
  switch (sortType) {
    case DownloadSortType.oldest:
      entries.sort((a, b) => a.modified.compareTo(b.modified));
      break;
    case DownloadSortType.newest:
      entries.sort((a, b) => b.modified.compareTo(a.modified));
      break;
    case DownloadSortType.name:
      entries.sort(
          (a, b) => a.spiff.playlist.title.compareTo(b.spiff.playlist.title));
      break;
    case DownloadSortType.size:
      entries.sort((a, b) => a.size.compareTo(b.size));
      break;
  }
}

class DownloadListState extends State<DownloadListWidget> {
  Random _random = Random();
  int _limit;
  int _coverPick;
  DownloadSortType _sortType;

  DownloadListState(this._sortType, this._limit);

  @override
  void initState() {
    super.initState();
    Downloads.load();
  }

  String _pickCover(Spiff spiff) {
    if (spiff.playlist.image != null && spiff.playlist.image.isNotEmpty) {
      return spiff.playlist.image;
    }
    if (_coverPick == null) {
      _coverPick = _random.nextInt(spiff.playlist.tracks.length);
    }
    return spiff.playlist.tracks[_coverPick].image;
  }

  Widget _subtitle(DownloadEntry entry) {
    final creator = entry.spiff.playlist.creator ?? 'Playlist';
    return Text('$creator \u2022 ${_size(entry.spiff)}');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: Downloads.downloadsSubject,
        builder: (context, snapshot) {
          final List<DownloadEntry> entries = snapshot.data ?? [];
          _sort(_sortType, entries);
          return Column(children: [
            ...entries
                .sublist(0,
                    _limit == -1 ? entries.length : min(_limit, entries.length))
                .map((entry) => Container(
                    child: ListTile(
                        leading: cover(_pickCover(entry.spiff)),
                        trailing: IconButton(
                            icon: Icon(Icons.playlist_play),
                            onPressed: () => _onPlay(entry.spiff)),
                        onTap: () => _onTap(entry.spiff),
                        title: Text(entry.spiff.playlist.title),
                        subtitle: _subtitle(entry))))
          ]);
        });
  }

  void _onTap(Spiff spiff) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => DownloadWidget(spiff)));
  }

  void _onPlay(Spiff spiff) {
    MediaQueue.playSpiff(spiff);
  }
}

class DownloadWidget extends StatefulWidget {
  final Spiff _spiff;

  DownloadWidget(this._spiff);

  @override
  DownloadState createState() => DownloadState(_spiff);
}

class DownloadState extends State<DownloadWidget> {
  final Spiff _spiff;
  bool _isCached = false;

  DownloadState(this._spiff);

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: getCoverBackgroundColor(spiff: _spiff),
        builder: (context, snapshot) => Scaffold(
            backgroundColor: snapshot?.data,
            appBar: AppBar(
                title: header(_spiff.playlist.title),
                backgroundColor: snapshot?.data),
            body: Builder(
                builder: (context) => SingleChildScrollView(
                      child: Column(children: [
                        header('Downloaded'),
                        Container(
                            padding: EdgeInsets.fromLTRB(0, 11, 0, 0),
                            child: GestureDetector(
                                onTap: () => _onPlay(),
                                child: cover(_spiff.playlist.image))),
                        Container(
                            padding: EdgeInsets.fromLTRB(0, 11, 0, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                    icon: Icon(Icons.playlist_play),
                                    onPressed: () => _onPlay()),
                                IconButton(
                                    icon: Icon(Icons.delete),
                                    onPressed: () => _onDelete(context)),
                                IconButton(

                                    icon: Icon(_isCached
                                        ? Icons.cloud_done_sharp
                                        : Icons.cloud_download_sharp),
                                    onPressed: () => {}),
                              ],
                            )),
                        if (_spiff.playlist.creator != null)
                          OutlinedButton(
                              onPressed: () => _onArtist(context),
                              child: Text(_spiff.playlist.creator,
                                  style: TextStyle(fontSize: 15))),
                        Divider(),
                        SpiffTrackListView(_spiff)
                      ]),
                    ))));
  }

  void _onArtist(BuildContext context) {
    Artist artist = artistMap[_spiff.playlist.creator];
    if (artist != null) {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => ArtistWidget(artist)));
    }
  }

  void _onPlay() {
    MediaQueue.playSpiff(_spiff);
  }

  void _onDelete(BuildContext context) async {
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('Really delete ${_spiff.playlist.title}?'),
            content: Text('This free ${_size(_spiff)} of space.'),
            actions: [
              FlatButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: Text('NO'),
              ),
              FlatButton(
                onPressed: () {
                  _onDeleteConfirmed();
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text('YES'),
              ),
            ],
          );
        });
  }

  Future<void> _onDeleteConfirmed() async {
    final cache = TrackCache();
    _spiff.playlist.tracks.forEach((e) async {
      final result = await cache.get(e);
      if (result is File) {
        print('delete $result');
        result.delete();
      }
    });

    final uri = Uri.parse(_spiff.playlist.location);
    final file = File.fromUri(uri);
    print('delete $file');
    file.delete();

    Downloads.reload();
  }

  Future<bool> _allTracksCached() async {
    return TrackCache().contains(_spiff.playlist.tracks);
  }

  void _checkCache() async {
    final result = await _allTracksCached();
    setState(() {
      _isCached = result;
    });
  }
}

class SpiffTrackListView extends StatelessWidget {
  final Spiff _spiff;

  SpiffTrackListView(this._spiff);

  @override
  Widget build(BuildContext context) {
    var children = List<Widget>();
    final cache = TrackCache();
    _spiff.playlist.tracks.forEach((e) {
      children.add(ListTile(
          onTap: () => {},
          leading: cover(e.image),
          trailing: FutureBuilder(
              future: cache.exists(e),
              builder: (context, snapshot) {
                final cached = snapshot.data ?? false;
                return Icon(
                    cached ? Icons.download_done_sharp : null);
              }),
          subtitle: Text('${e.creator} \u2022 ${e.size ~/ megabyte} MB'),
          title: Text(e.title)));
    });
    return Column(children: children);
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
        _saveAs(spiff, file).then((_) {
          SpiffCache.put(spiff); // TODO needed?
          _downloads.add(DownloadEntry.create(file, spiff));
          _broadcast();
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
    return _download(client, () => client.station(station.id, ttl: Duration.zero))
        .whenComplete(() => showSnackBar('Finished ${station.name}'));
  }

  static Future<bool> downloadSpiff(Spiff spiff) async {
    final client = Client();
    showSnackBar('Downloading ${spiff.playlist.title}');
    return _download(client, () => Future.value(spiff))
        .whenComplete(() => showSnackBar('Finished ${spiff.playlist.title}'));
  }

  static final List<DownloadEntry> _downloads = [];
  static final downloadsSubject = BehaviorSubject<List<DownloadEntry>>();

  static void _broadcast() {
    downloadsSubject.add(_downloads);
  }

  static bool get isNotEmpty => _downloads.isNotEmpty;

  static Future<void> reload() async {
    _downloads.length = 0;
    return load();
  }

  static Future<void> load() async {
    if (_downloads.isNotEmpty) {
      return;
    }
    final completer = Completer();
    final dir = await checkAppDir(_dir);
    final list = await dir.list().toList();
    await Future.forEach(list, (file) async {
      if (file.path.endsWith('.json')) {
        final spiff = await Spiff.fromFile(file);
        _downloads.add(DownloadEntry.create(file, spiff));
        SpiffCache.put(spiff);
      }
    }).whenComplete(() {
      _broadcast();
      completer.complete();
    });
    return completer.future;
  }
}

class DownloadEntry {
  final File file;
  final Spiff spiff;
  final DateTime modified;
  final int size;

  DownloadEntry(this.file, this.spiff, this.modified, this.size);

  static DownloadEntry create(File file, Spiff spiff) {
    FileStat stat = file.statSync();
    return DownloadEntry(file, spiff, stat.modified, stat.size);
  }
}
