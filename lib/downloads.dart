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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:takeout_app/playlist.dart';
import 'package:rxdart/rxdart.dart';

import 'client.dart';
import 'schema.dart';
import 'spiff.dart';
import 'cache.dart';
import 'cover.dart';
import 'global.dart';
import 'menu.dart';
import 'model.dart';
import 'util.dart';
import 'video.dart';
import 'main.dart';

Random _random = Random();

String _spiffCover(Spiff spiff) {
  if (isNotNullOrEmpty(spiff.playlist.image)) {
    return spiff.playlist.image!;
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
        appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.downloadsLabel),
            actions: [
              popupMenu(context, [
                PopupItem.delete(
                    context,
                    AppLocalizations.of(context)!.deleteAll,
                    (ctx) => _onDeleteAll(ctx)),
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
            title: Text(AppLocalizations.of(context)!.confirmDelete),
            content: Text(AppLocalizations.of(context)!.deleteDownloadedTracks),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    Text(MaterialLocalizations.of(context).cancelButtonLabel),
              ),
              TextButton(
                onPressed: () {
                  _onDeleteConfirmed();
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          );
        });
  }

  void _onDeleteConfirmed() {
    Downloads.downloadsSubject.value.forEach((entry) {
      if (entry is SpiffDownloadEntry) {
        _deleteSpiff(entry.spiff);
      }
    });
    Downloads.reload();
  }
}

class DownloadListWidget extends StatefulWidget {
  final int limit;
  final DownloadSortType sortType;
  final List<DownloadEntry> Function(List<DownloadEntry>)? filter;

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
      entries.sort((a, b) => a.title.compareTo(b.title));
      break;
    case DownloadSortType.size:
      entries.sort((a, b) => a.size.compareTo(b.size));
      break;
  }
}

class DownloadListState extends State<DownloadListWidget> {
  int _limit;
  DownloadSortType _sortType;
  final List<DownloadEntry> Function(List<DownloadEntry>)? _filter;

  DownloadListState(this._sortType, this._limit, this._filter);

  @override
  void initState() {
    super.initState();
    Downloads.load();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DownloadEntry>>(
        stream: Downloads.downloadsSubject,
        builder: (context, snapshot) {
          List<DownloadEntry> entries = snapshot.data ?? [];
          if (_filter != null) {
            entries = _filter!(entries);
          }
          downloadsSort(_sortType, entries);
          return Column(children: [
            ...entries
                .sublist(0,
                    _limit == -1 ? entries.length : min(_limit, entries.length))
                .map((entry) => Container(
                    child: ListTile(
                        leading: entry.leading,
                        trailing: IconButton(
                            icon: Icon(Icons.play_arrow),
                            onPressed: () => _onPlay(context, entry)),
                        onTap: () => _onTap(context, entry),
                        title: Text(entry.title),
                        subtitle: Text(entry.subtitle))))
          ]);
        });
  }

  void _onTap(BuildContext context, DownloadEntry entry) {
    if (entry is SpiffDownloadEntry) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => DownloadWidget(spiff: entry.spiff)));
    }
  }

  void _onPlay(BuildContext context, DownloadEntry entry) {
    if (entry is SpiffDownloadEntry) {
      var spiff = entry.spiff;
      if (spiff.isMusic()) {
        MediaQueue.playSpiff(entry.spiff);
        showPlayer();
      } else if (spiff.isVideo()) {
        var entry = spiff.playlist.tracks.first;
        showMovie(context, entry);
      }
    }
  }
}

class DownloadWidget extends StatefulWidget {
  final Spiff? spiff;
  final Future<Spiff> Function()? fetch;

  DownloadWidget({this.spiff, this.fetch});

  @override
  DownloadState createState() => DownloadState(spiff: spiff, fetch: fetch);
}

class DownloadState extends State<DownloadWidget> {
  Spiff? spiff;
  Future<Spiff> Function()? fetch;
  String? _coverUrl;

  DownloadState({this.spiff, this.fetch});

  @override
  void initState() {
    super.initState();
    if (spiff != null) {
      _coverUrl = _spiffCover(spiff!);
    }
    if (fetch != null) {
      _onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Color?>(
        future: getImageBackgroundColor(_coverUrl ?? ''),
        builder: (context, snapshot) => Scaffold(
            backgroundColor: snapshot.data,
            // appBar: AppBar(
            //     title: header(spiff.playlist.title),
            //     backgroundColor: snapshot?.data),
            body: spiff == null
                ? Center(child: CircularProgressIndicator())
                : fetch != null
                    ? RefreshIndicator(
                        onRefresh: () => _onRefresh(), child: body())
                    : body()));
  }

  Widget body() {
    return StreamBuilder<Set<String>>(
        stream: TrackCache.keysSubject,
        builder: (context, snapshot) {
          // cover images are 250x250 (or 500x500)
          // distort a bit to only take half the screen
          final screen = MediaQuery.of(context).size;
          final expandedHeight = screen.height / 2;
          final keys = snapshot.data ?? Set<String>();
          final isCached = TrackCache.checkAll(keys, spiff!.playlist.tracks);
          bool isRadio = spiff!.playlist.creator == 'Radio';
          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: expandedHeight,
              actions: [
                popupMenu(context, [
                  if (isCached)
                    PopupItem.delete(
                        context,
                        AppLocalizations.of(context)!.deleteItem,
                        (_) => _onDelete(context)),
                  if (fetch != null)
                    PopupItem.refresh(context, (_) => _onRefresh()),
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
                    spiffCover(_coverUrl!),
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
                        child: _playButton(context, isCached)),
                    Align(
                        alignment: Alignment.bottomRight,
                        child: _bottomRight(context, isCached))
                  ])),
            ),
            SliverToBoxAdapter(
                child: Container(
                    padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
                    child: Column(children: [
                      _title(context),
                      _subtitle(context, isRadio),
                    ]))),
            SliverToBoxAdapter(child: SpiffTrackListView(spiff!)),
          ]);
        });
  }

  Widget _bottomRight(BuildContext context, bool isCached) {
    return isCached ? _deleteButton(context) : _downloadButton(isCached);
  }

  Widget _title(BuildContext context) {
    return Text(spiff!.playlist.title,
        style: Theme.of(context).textTheme.headline5);
  }

  Widget _subtitle(BuildContext context, bool isRadio) {
    final text = '${spiff!.playlist.creator} \u2022 ${storage(spiff!.size)}';
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .subtitle1!
            .copyWith(color: Colors.white60));
  }

  Future<void> _onRefresh() async {
    Future<Spiff> Function()? fetcher = fetch;
    if (fetcher != null) {
      try {
        final result = await fetcher();
        print('got $result');
        if (mounted) {
          setState(() {
            spiff = result;
            _coverUrl = _spiffCover(spiff!);
          });
        }
      } catch (error) {
        print('refresh err $error');
      }
    }
  }

  Widget _playButton(BuildContext context, bool isCached) {
    if (isCached) {
      return IconButton(
          icon: Icon(Icons.play_arrow, size: 32), onPressed: () => _onPlay(context));
    }
    return allowStreamingIconButton(Icon(Icons.play_arrow, size: 32), () => _onPlay(context));
  }

  Widget _downloadButton(bool isCached) {
    if (isCached) {
      return IconButton(
          icon: Icon(Icons.cloud_download_outlined),
          onPressed: () => _onDownloadCheck());
    }
    return allowDownloadIconButton(
        Icon(Icons.cloud_download_outlined), _onDownloadCheck);
  }

  Widget _deleteButton(BuildContext context) {
    return IconButton(
        icon: Icon(Icons.delete), onPressed: () => _onDelete(context));
  }

  void _onDownloadCheck() {
    // TODO this assumes that fetch-able will always download a new spiff
    if (fetch != null) {
      Downloads.downloadSpiff(spiff!);
    } else {
      Downloads.downloadSpiffTracks(spiff!);
    }
  }

  // void _onArtist(BuildContext context) {
  //   showArtist(spiff!.playlist.creator!);
  // }

  void _onPlay(BuildContext context) {
    print('_onPlay $spiff');
    if (spiff!.isMusic()) {
      MediaQueue.playSpiff(spiff!);
      showPlayer();
    } else if (spiff!.isVideo()) {
      var entry = spiff!.playlist.tracks.first;
      showMovie(context, entry);
    }
  }

  void _onDelete(BuildContext context) async {
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!
                .deleteTitle(spiff!.playlist.title)),
            content:
                Text(AppLocalizations.of(context)!.deleteFree(spiff!.size)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    Text(MaterialLocalizations.of(context).cancelButtonLabel),
              ),
              TextButton(
                onPressed: () {
                  _onDeleteConfirmed();
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          );
        });
  }

  Future<void> _onDeleteConfirmed() async {
    await _deleteSpiff(spiff!);
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

  final uri = Uri.parse(spiff.playlist.location!);
  final file = File.fromUri(uri);
  print('delete $file');
  file.delete();
}

class SpiffTrackListView extends StatelessWidget {
  final Spiff _spiff;

  SpiffTrackListView(this._spiff);

  void _onTrack(BuildContext context, int index) {
    if (_spiff.isMusic()) {
      MediaQueue.playSpiff(_spiff, index: index);
    } else if (_spiff.isVideo()) {
      showMovie(context, _spiff.playlist.tracks[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
        stream: TrackCache.keysSubject,
        builder: (context, snapshot) {
          final keys = snapshot.data ?? Set<String>();
          final children = <Widget>[];
          for (var i = 0; i < _spiff.playlist.tracks.length; i++) {
            final e = _spiff.playlist.tracks[i];
            children.add(ListTile(
                onTap: () => _onTrack(context, i),
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
    var title = spiff.playlist.title;
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
          _add(SpiffDownloadEntry.create(file, spiff));
          _broadcast();
          try {
            completer.complete(await _downloadTracks(client, spiff));
          } catch (e) {
            completer.completeError(e);
          }
        }).catchError(((error) {
          completer.completeError(error);
        }));
      }).catchError((error) {
        completer.completeError(error);
      });
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
    return _download(
            client, () => client.artistPlaylist(artist.id, ttl: Duration.zero))
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

  static Future<bool> downloadMovie(Movie movie) async {
    final client = Client();
    showSnackBar('Downloading ${movie.title}');
    return _download(
            client, () => client.moviePlaylist(movie.id, ttl: Duration.zero))
        .whenComplete(() => showSnackBar('Finished ${movie.title}'));
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
    await Future.forEach<FileSystemEntity>(list, (file) async {
      if (file.path.endsWith('.json')) {
        final spiff = await Spiff.fromFile(file as File);
        _add(SpiffDownloadEntry.create(file, spiff));
      }
    }).whenComplete(() {
      _broadcast();
      completer.complete();
    });
    return completer.future;
  }

  // check all spiff tracks are cached
  // incomplete downloads would have the wrong size
  static Future<void> _checkSpiffCached(Spiff spiff) async {
    final cache = TrackCache();
    return Future.forEach<Entry>(spiff.playlist.tracks, (e) async {
      final result = await cache.get(e);
      if (result is File) {
        print('checking $result');
        if (result.statSync().size != e.size) {
          print('deleting $result; incorrect size');
          result.deleteSync();
          cache.remove(e);
        }
      }
    });
  }

  static Future<void> check() async {
    final dir = await checkAppDir(_dir);
    final list = dir.listSync().toList();
    return Future.forEach<FileSystemEntity>(list, (file) async {
      if (file.path.endsWith('.json')) {
        final spiff = await Spiff.fromFile(file as File);
        await _checkSpiffCached(spiff);
      }
    });
  }
}

abstract class DownloadEntry {
  File get file;

  Widget get leading;

  String get title;

  String get subtitle;

  DateTime get modified;

  int get size;
}

class SpiffDownloadEntry extends DownloadEntry with MediaAlbum {
  final File _file;
  final Spiff _spiff;
  final DateTime _modified;

  SpiffDownloadEntry(this._file, this._spiff, this._modified);

  static SpiffDownloadEntry create(File file, Spiff spiff) {
    FileStat stat = file.statSync();
    return SpiffDownloadEntry(file, spiff, stat.modified);
  }

  Spiff get spiff => _spiff;

  String _footer() {
    final creator = _subtitle();
    return '$creator \u2022 ${storage(size)}';
  }

  String _subtitle() {
    return _spiff.playlist.creator ?? 'Playlist';
  }

  @override
  File get file => _file;

  @override
  Widget get leading => tileCover(_spiffCover(_spiff));

  @override
  String get title => _spiff.playlist.title;

  @override
  String get subtitle => _footer();

  @override
  DateTime get modified => _modified;

  @override
  int get size => _spiff.size;

  @override
  String get album => spiff.playlist.title;

  @override
  String get creator => spiff.playlist.creator!;

  @override
  String get image => _spiffCover(spiff);

  @override
  int get year => 0;
}

//
// class Movie\\\DownloadEntry extends SpiffDownloadEntry with MediaAlbum {
//   MovieDownloadEntry(File file, Spiff spiff, DateTime modified)
//       : super(file, spiff, modified);
//
//   static MovieDownloadEntry create(File file, Spiff spiff) {
//     FileStat stat = file.statSync();
//     return MovieDownloadEntry(file, spiff, stat.modified);
//   }
//
//   @override
//   String get album => spiff.playlist.title;
//
//   @override
//   String get creator => spiff.playlist.creator!;
//
//   @override
//   String get image => _spiffCover(spiff);
//
//   @override
//   int get year => 0;
// }
//
// class MusicDownloadEntry extends SpiffDownloadEntry with MediaAlbum {
//
//   MusicDownloadEntry(File file, Spiff spiff, DateTime modified)
//       : super(file, spiff, modified);
//
//   static MusicDownloadEntry create(File file, Spiff spiff) {
//     FileStat stat = file.statSync();
//     return MusicDownloadEntry(file, spiff, stat.modified);
//   }
//
//   @override
//   String get album => spiff.playlist.title;
//
//   @override
//   String get creator => spiff.playlist.creator!;
//
//   @override
//   String get image => _spiffCover(spiff);
//
//   @override
//   int get year => 0;
// }
