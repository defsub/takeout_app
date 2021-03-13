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

import 'package:path/path.dart';
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
import 'menu.dart';
import 'model.dart';
import 'util.dart';

Random _random = Random();

String _spiffCover(Spiff spiff) {
  if (isNotNullOrEmpty(spiff.playlist.image)) {
    return spiff.playlist.image;
  }
  for (var i = 0; i < spiff.playlist.tracks.length; i++) {
    final pick = _random.nextInt(spiff.playlist.tracks.length);
    if (isNotNullOrEmpty(spiff.playlist.tracks[pick].image)) {
      return spiff.playlist.tracks[pick].image;
    }
  }
  return ''; // TODO what to return?
}

class DownloadsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Downloads'), actions: [
          popupMenu(context, [
            PopupItem.delete('Delete all', (ctx) => _onDeleteAll(ctx)),
          ])
        ]),
        body: SingleChildScrollView(
            child: Column(
          children: [
            Container(child: DownloadListWidget()),
          ],
        )));
  }

  void _onDeleteAll(BuildContext context) {
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text('Really delete?'),
            content: Text('This will delete all downloaded tracks.'),
            actions: [
              FlatButton(
                onPressed: () => Navigator.pop(ctx),
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

  void _onDeleteConfirmed() {
    Downloads.downloadsSubject.value.forEach((entry) {
      _deleteSpiff(entry.spiff);
    });
    Downloads.reload();
  }
}

class DownloadListWidget extends StatefulWidget {
  final int limit;
  final DownloadSortType sortType;
  final List<DownloadEntry> Function(List<DownloadEntry>) filter;

  DownloadListWidget(
      {this.sortType = DownloadSortType.name, this.limit = -1, this.filter});

  @override
  DownloadListState createState() => DownloadListState(sortType, limit, filter);
}

enum DownloadSortType { newest, oldest, name, size }

void downloadsSort(DownloadSortType sortType, List<DownloadEntry> entries) {
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
  int _limit;
  DownloadSortType _sortType;
  final List<DownloadEntry> Function(List<DownloadEntry>) _filter;

  DownloadListState(this._sortType, this._limit, this._filter);

  @override
  void initState() {
    super.initState();
    Downloads.load();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: Downloads.downloadsSubject,
        builder: (context, snapshot) {
          List<DownloadEntry> entries = snapshot.data ?? [];
          if (_filter != null) {
            entries = _filter(entries);
          }
          downloadsSort(_sortType, entries);
          return Column(children: [
            ...entries
                .sublist(0,
                    _limit == -1 ? entries.length : min(_limit, entries.length))
                .map((entry) => Container(
                    child: ListTile(
                        leading: tileCover(_spiffCover(entry.spiff)),
                        trailing: IconButton(
                            icon: Icon(Icons.playlist_play),
                            onPressed: () => _onPlay(entry.spiff)),
                        onTap: () => _onTap(context, entry.spiff),
                        title: Text(entry.spiff.playlist.title),
                        subtitle: Text(entry.footer()))))
          ]);
        });
  }

  void _onTap(BuildContext context, Spiff spiff) {
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
  String _coverUrl;

  DownloadState(this._spiff);

  @override
  void initState() {
    super.initState();
    _coverUrl = _spiffCover(_spiff);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: getImageBackgroundColor(_coverUrl),
        builder: (context, snapshot) => Scaffold(
            backgroundColor: snapshot?.data,
            // appBar: AppBar(
            //     title: header(_spiff.playlist.title),
            //     backgroundColor: snapshot?.data),
            body: StreamBuilder(
                stream: TrackCache.keysSubject,
                builder: (context, snapshot) {
                  final keys = snapshot.data ?? Set<String>();
                  final isCached =
                      TrackCache.checkAll(keys, _spiff.playlist.tracks);
                  bool isRadio = _spiff.playlist.creator == 'Radio';
                  return CustomScrollView(slivers: [
                    SliverAppBar(
                      // floating: true,
                      // snap: false,
                      expandedHeight: 300.0,
                      actions: [
                        popupMenu(context, [
                          // PopupItem.link('MusicBrainz Release',
                          //         (_) => launch(releaseUrl)),
                          // PopupItem.link('MusicBrainz Release Group',
                          //         (_) => launch(releaseGroupUrl)),
                          // PopupItem.refresh((_) => _onRefresh()),
                        ]),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                          // centerTitle: true,
                          // title: Text(release.name, style: TextStyle(fontSize: 15)),
                          stretchModes: [
                            StretchMode.zoomBackground,
                            StretchMode.fadeTitle
                          ],
                          background: Stack(fit: StackFit.expand, children: [
                            spiffCover(_coverUrl),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(0.0, 0.75),
                                  end: Alignment(0.0, 0.0),
                                  colors: <Color>[
                                    Color(0x60000000),
                                    Color(0x00000000),
                                  ],
                                ),
                              ),
                            ),
                            Align(
                                alignment: Alignment.bottomLeft,
                                child: _playButton(isCached)),
                            if (!isRadio)
                              Align(
                                  alignment: Alignment.bottomCenter,
                                  child: TextButton.icon(
                                      icon: Icon(Icons.people),
                                      label: Text(_spiff.playlist.creator),
                                      onPressed: () => _onArtist(context))),
                            if (isCached)
                              Align(
                                  alignment: Alignment.bottomRight,
                                  child: _deleteButton(context)),
                            if (!isCached)
                              Align(
                                  alignment: Alignment.bottomRight,
                                  child: _downloadButton()),
                          ])),
                    ),
                    SliverToBoxAdapter(
                        child: Column(children: [
                      _title(),
                      // _subtitle(),
                    ])),
                    SliverToBoxAdapter(child: SpiffTrackListView(_spiff)),
                  ]);
                })));
  }

  Widget _title() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      Expanded(child: heading(_spiff.playlist.title)),
      Padding(child: Text(storage(_spiff.size)), padding: EdgeInsets.all(11))
    ]);
  }

  Widget _playButton(bool isCached) {
    return IconButton(
        icon: Icon(Icons.play_arrow),
        onPressed: isCached == true ? () => _onPlay() : null);
  }

  Widget _downloadButton() {
    return IconButton(
        icon: Icon(Icons.cloud_download_outlined),
        onPressed: () => _onDownloadCheck());
  }

  Widget _deleteButton(BuildContext context) {
    return IconButton(
        icon: Icon(Icons.delete),
        onPressed: () => _onDelete(context));
  }

  void _onDownloadCheck() {
    Downloads.downloadSpiffTracks(_spiff);
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
            content: Text('This will free ${storage(_spiff.size)} of space.'),
            actions: [
              FlatButton(
                onPressed: () => Navigator.pop(ctx),
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
    await _deleteSpiff(_spiff);
    Downloads.reload();
  }
}

Future<void> _deleteSpiff(Spiff spiff) async {
  final cache = TrackCache();
  spiff.playlist.tracks.forEach((e) async {
    final result = await cache.get(e);
    if (result is File) {
      print('delete $result');
      result.delete();
      cache.remove(e);
    }
  });

  final uri = Uri.parse(spiff.playlist.location);
  final file = File.fromUri(uri);
  print('delete $file');
  file.delete();
}

class SpiffTrackListView extends StatelessWidget {
  final Spiff _spiff;

  SpiffTrackListView(this._spiff);

  void _onTrack(int index) {
    MediaQueue.playSpiff(_spiff, index: index);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: TrackCache.keysSubject,
        builder: (context, snapshot) {
          final keys = snapshot.data ?? Set<String>();
          final children = <Widget>[];
          for (var i = 0; i < _spiff.playlist.tracks.length; i++) {
            final e = _spiff.playlist.tracks[i];
            children.add(ListTile(
                onTap: () => _onTrack(i),
                onLongPress: () => showArtist(e.creator),
                leading: tileCover(e.image),
                trailing: Icon(
                    keys.contains(e.key) ? Icons.download_done_sharp : null),
                subtitle: Text('${e.creator} \u2022 ${storage(e.size)}'),
                title: Text(e.title)));
          }
          return Column(children: children);
        });
  }
}

class Downloads {
  static const _dir = 'downloads';

  static String _downloadFileName(Spiff spiff) {
    var title = spiff.playlist.title ?? 'download';
    title = title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    var creator = spiff.playlist.creator ?? 'playlist';
    creator = creator.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return '${creator}_$title.json';
  }

  static Future<File> _downloadFile(String fileName) async {
    return await checkAppDir(_dir).then((dir) {
      File file = File('${dir.path}/$fileName');
      for (var n = 1; file.existsSync(); n++) {
        var ext = extension(fileName);
        var name = '${basenameWithoutExtension(fileName)}_$n$ext';
        // foo.json -> foo-1.json, foo-2.json, etc.
        file = File('${dir.path}/$name');
      }
      return file;
    });
  }

  static Future<void> _saveAs(Spiff spiff, File file) {
    final completer = Completer<void>();
    final data = utf8.encode(jsonEncode(spiff.toJson()));
    file
        .writeAsBytes(data)
        .then((f) => completer.complete())
        .catchError((e) => completer.completeError(e));
    return completer.future;
  }

  static Future<bool> downloadSpiffTracks(Spiff spiff) async {
    final client = Client();
    return await _downloadTracks(client, spiff);
  }

  static Future<bool> _downloadTracks(Client client, Spiff spiff) async {
    return await client.downloadSpiffTracks(spiff).then((result) {
      return result.length == spiff.playlist.tracks.length &&
          !result.any((e) => e == false);
    });
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
        _saveAs(spiff, file).then((_) async {
          _add(DownloadEntry.create(file, spiff));
          _broadcast();
          try {
            completer.complete(await _downloadTracks(client, spiff));
          } catch (e) {
            completer.completeError(e);
          }
        }).catchError(((error) => completer.completeError(error)));
      }).catchError((error) => completer.completeError(error));
    });
    return completer.future;
  }

  static Future<bool> downloadRelease(Release release) async {
    final client = Client();
    showSnackBar('Downloading ${release.name}');
    return _download(client,
            () => client.releasePlaylist(release.id, ttl: Duration.zero))
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
    return _download(
            client, () => client.station(station.id, ttl: Duration.zero))
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
    // TODO clone _downloads?
    downloadsSubject.add(_downloads);
  }

  static void _add(DownloadEntry entry) {
    final entries = _downloads.where((e) => e.file.path == entry.file.path);
    if (entries.isEmpty) {
      _downloads.add(entry);
    }
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
        _add(DownloadEntry.create(file, spiff));
      }
    }).whenComplete(() {
      _broadcast();
      completer.complete();
    });
    return completer.future;
  }
}

class DownloadEntry implements MusicAlbum {
  final File file;
  final Spiff spiff;
  final DateTime modified;

  DownloadEntry(this.file, this.spiff, this.modified);

  // Widget image() {
  //   return cover(_spiffCover(spiff));
  // }

  String footer() {
    final creator = subtitle();
    return '$creator \u2022 ${storage(size)}';
  }

  String subtitle() {
    return spiff.playlist.creator ?? 'Playlist';
  }

  static DownloadEntry create(File file, Spiff spiff) {
    FileStat stat = file.statSync();
    return DownloadEntry(file, spiff, stat.modified);
  }

  @override
  String get album => spiff.playlist.title;

  @override
  String get creator => spiff.playlist.creator;

  @override
  String get image => _spiffCover(spiff);

  @override
  int get year => 0;

  @override
  int get size => spiff.size;
}
