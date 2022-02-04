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
import 'style.dart';
import 'widget.dart';

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
        _deleteSpiff(entry);
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
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => DownloadWidget(entry)));
    }
  }

  void _onPlay(BuildContext context, DownloadEntry entry) {
    if (entry is SpiffDownloadEntry) {
      var spiff = entry.spiff;
      if (spiff.isMusic() || spiff.isPodcast()) {
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
  final SpiffDownloadEntry entry;

  DownloadWidget(this.entry);

  @override
  DownloadState createState() => DownloadState(entry);
}

class DownloadState extends State<DownloadWidget> with SpiffWidgetBuilder {
  SpiffDownloadEntry entry;
  late String _cover;

  DownloadState(this.entry);

  @override
  void initState() {
    super.initState();
    _cover = pickCover(entry.spiff);
  }

  Spiff? get spiff => entry.spiff;

  String? get coverUrl => _cover;

  Future<Spiff> Function()? get fetch => () {
        return Client()
            .spiff(entry.spiff.playlist.location!, ttl: Duration.zero);
      };

  Future<void> onRefresh() async {
    Future<Spiff> Function()? fetcher = fetch;
    if (fetcher != null) {
      try {
        final result = await fetcher();
        print('got $result');
        // TODO !!! at this point tracks *may* get orphaned in the cache
        Downloads.refreshSpiff(entry, result).then((freshEntry) {
          entry = freshEntry;
        }).whenComplete(() {
          if (mounted) {
            setState(() {
              _cover = pickCover(entry.spiff);
            });
          }
        });
      } catch (error) {
        print('refresh err $error');
      }
    }
  }

  List<Widget>? actions(BuildContext context) {
    return [
      popupMenu(context, [
        PopupItem.delete(context, AppLocalizations.of(context)!.deleteItem,
            (_) => _onDelete(context)),
        if (fetch != null) PopupItem.refresh(context, (_) => onRefresh()),
      ]),
    ];
  }

  Widget bottomRight(BuildContext context, bool isCached) {
    return isCached ? deleteButton(context) : downloadButton(isCached);
  }

  Widget deleteButton(BuildContext context) {
    return IconButton(
        icon: Icon(Icons.delete), onPressed: () => _onDelete(context));
  }

  Widget subtitle(BuildContext context) {
    final text =
        '${spiff!.playlist.creator} \u2022 ${relativeDate(spiff!.playlist.date ?? '')} \u2022 ${storage(spiff!.size)}';
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .subtitle1!
            .copyWith(color: Colors.white60));
  }

  Widget downloadButton(bool isCached) {
    if (isCached) {
      return IconButton(
          icon: Icon(IconsDownload), onPressed: () => _onDownloadCheck());
    }
    return allowDownloadIconButton(Icon(IconsDownload), _onDownloadCheck);
  }

  void _onDownloadCheck() {
    // TODO this assumes that fetch-able will always download a new spiff
    if (fetch != null) {
      Downloads.downloadSpiff(spiff!);
    } else {
      Downloads.downloadSpiffTracks(spiff!);
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
    await _deleteSpiff(entry);
    Downloads.reload();
  }
}

Future<void> _deleteSpiff(SpiffDownloadEntry entry) async {
  final cache = TrackCache();
  entry.spiff.playlist.tracks.forEach((e) async {
    await _deleteLocatable(cache, e);
  });

  // final uri = Uri.parse(spiff.playlist.location!);
  // final file = File.fromUri(uri);
  final file = entry.file;
  print('delete $file');
  file.deleteSync();
}

Future _deleteLocatable(TrackCache cache, Locatable l) async {
  print('delete $l');
  final entry = await cache.get(l);
  if (entry is File) {
    entry.deleteSync();
    cache.remove(l);
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
        final ext = extension(fileName);
        final name = '${basenameWithoutExtension(fileName)}_$n$ext';
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
        .writeAsBytes(data) // truncates if exists
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

  static Future<File> _spiffFile(Spiff spiff) async =>
      _downloadFile(_downloadFileName(spiff));

  static Future<bool> _download(
      Client client, Future<Spiff> Function() fetchSpiff,
      {Future<File> Function(Spiff) spiffFile = _spiffFile,
      bool includeTracks = true}) async {
    final completer = Completer<bool>();
    fetchSpiff().then((spiff) {
      spiffFile(spiff).then((file) {
        print('download to $file');
        _saveAs(spiff, file).then((_) async {
          _add(SpiffDownloadEntry.create(file, spiff));
          _broadcast();
          if (includeTracks) {
            try {
              completer.complete(await _downloadTracks(client, spiff));
            } catch (e) {
              completer.completeError(e);
            }
          } else {
            // just the spiff
            completer.complete(true);
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

  static Future<SpiffDownloadEntry> refreshSpiff(
      SpiffDownloadEntry entry, Spiff spiff) async {
    final client = Client();
    await _download(client, () => Future.value(spiff),
        spiffFile: (_) => Future.value(entry.file), includeTracks: false);
    return Future.value(entry.copyWith(spiff: spiff));
  }

  static Future<bool> downloadSpiff(Spiff spiff,
      {bool includeTracks = true}) async {
    final client = Client();
    showSnackBar('Downloading ${spiff.playlist.title}');
    return _download(client, () => Future.value(spiff),
            includeTracks: includeTracks)
        .whenComplete(() => showSnackBar('Finished ${spiff.playlist.title}'));
  }

  static Future<bool> downloadMovie(Movie movie) async {
    final client = Client();
    showSnackBar('Downloading ${movie.title}');
    return _download(
            client, () => client.moviePlaylist(movie.id, ttl: Duration.zero))
        .whenComplete(() => showSnackBar('Finished ${movie.title}'));
  }

  static Future<bool> downloadSeries(Series series) async {
    final client = Client();
    showSnackBar('Series ${series.title}');
    return _download(
            client, () => client.seriesPlaylist(series.id, ttl: Duration.zero))
        .whenComplete(() => showSnackBar('Finished ${series.title}'));
  }

  static Future downloadSeriesEpisode(Series series, Episode episode) async {
    final client = Client();
    showSnackBar('Downloading ${episode.title}');
    final success = await _download(
        client, () => client.seriesPlaylist(series.id, ttl: Duration.zero),
        includeTracks: false); // just one track
    if (success) {
      return client
          .download(episode)
          .whenComplete(() => showSnackBar('Finished ${episode.title}'));
    } else {
      showSnackBar('Failed ${episode.title}');
    }
  }

  static Future deleteEpisode(Episode episode) async {
    final cache = TrackCache();
    return _deleteLocatable(cache, episode);
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
  final String _cover;

  SpiffDownloadEntry(this._file, this._spiff, this._modified, this._cover);

  static SpiffDownloadEntry create(File file, Spiff spiff) {
    FileStat stat = file.statSync();
    return SpiffDownloadEntry(file, spiff, stat.modified, pickCover(spiff));
  }

  SpiffDownloadEntry copyWith({
    File? file,
    Spiff? spiff,
    DateTime? modified,
    String? cover,
  }) =>
      SpiffDownloadEntry(file ?? this._file, spiff ?? this._spiff,
          modified ?? this._modified, cover ?? this._cover);

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
  Widget get leading => tileCover(_cover);

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
  String get image => _cover;

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
