import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:takeout_app/cache/track_repository.dart';
import 'package:takeout_app/spiff/model.dart';

import 'repository.dart';

abstract class DownloadIdentifier extends Equatable implements TrackIdentifier {
  @override
  List<Object> get props => [key];

// String get etag;
}

class Download extends Equatable {
  final DownloadIdentifier id;
  final Uri uri;
  final int size;
  final File file;
  final DownloadProgress? progress;

  Download(this.id, this.uri, this.size, this.file,
      {DownloadProgress? this.progress});

  Download copyWith({DownloadProgress? progress}) =>
      Download(this.id, this.uri, this.size, this.file, progress: progress);

  @override
  List<Object> get props => [id];

  bool get downloading => progress != null && progress?.error != null;
}

class DownloadProgress {
  final int offset;
  final int size;
  final Object? error;

  DownloadProgress(this.offset, this.size, {this.error});

  DownloadProgress copyWith({int? offset, Object? error}) =>
      DownloadProgress(offset ?? this.offset, this.size,
          error: error ?? this.error);

  // Value used for progress display.
  double get value {
    return offset.toDouble() / size;
  }
}

class DownloadState {
  final Map<DownloadIdentifier, Download> downloads;
  final Map<DownloadIdentifier, Object?> failed;

  DownloadState(Map<DownloadIdentifier, Download> map,
      Map<DownloadIdentifier, Object?> errors)
      : downloads = Map<DownloadIdentifier, Download>.unmodifiable(map),
        failed = Map<DownloadIdentifier, Object?>.unmodifiable(errors);

  factory DownloadState.empty() => DownloadState({}, {});

  DownloadState add(Download download) {
    final map = Map<DownloadIdentifier, Download>.from(downloads);
    map[download.id] = download;

    final errors = Map<DownloadIdentifier, Object?>.from(failed);
    errors.remove(download.id);

    return DownloadState(map, errors);
  }

  DownloadState update(DownloadIdentifier id, int offset) {
    final download = downloads[id];
    if (download != null) {
      return add(
          download.copyWith(progress: DownloadProgress(offset, download.size)));
    } else {
      return this;
    }
  }

  DownloadState error(DownloadIdentifier id, Object? error) {
    final map = Map<DownloadIdentifier, Download>.from(downloads);
    map.remove(id);

    final errors = Map<DownloadIdentifier, Object?>.from(failed);
    errors[id] = error;

    return DownloadState(map, errors);
  }

  DownloadState complete(DownloadIdentifier id) {
    final download = downloads[id];
    if (download != null) {
      return add(download.copyWith(progress: null));
    }
    return this;
  }

  Download? get(DownloadIdentifier id) => downloads[id];

  DownloadProgress? progress(DownloadIdentifier id) => downloads[id]?.progress;

  bool contains(DownloadIdentifier id) => downloads.containsKey(id);

  bool containsAll(Iterable<DownloadIdentifier> ids) {
    final keys = Set<DownloadIdentifier>.from(downloads.keys);
    return keys.containsAll(ids);
  }
}

class _ProgressSink implements Sink<int> {
  final void Function(int) update;
  int _offset = 0;

  _ProgressSink(this.update);

  @override
  void add(int chunk) {
    _offset += chunk;
    update(_offset);
  }

  @override
  void close() {}
}

class DownloadEvent {
  final DownloadIdentifier id;
  final Uri uri;
  final int size;

  DownloadEvent(this.id, this.uri, this.size);
}

class DownloadCubit extends Cubit<DownloadState> {
  final TrackCacheRepository trackCacheRepository;
  final ClientRepository clientRepository;

  DownloadCubit(
      {required this.trackCacheRepository, required this.clientRepository})
      : super(DownloadState.empty());

  Future add(DownloadEvent event) async {
    if (state.contains(event.id)) {
      return Future.error("already downloaded or in progress");
    }

    final file = trackCacheRepository.create(event.id);
    final download = Download(event.id, event.uri, event.size, file,
        progress: DownloadProgress(0, event.size));

    emit(state.add(download));

    return clientRepository
        .download(event.uri, file, event.size,
            progress: _ProgressSink((offset) => _update(event.id, offset)))
        .then((_) => _complete(event.id))
        .onError((error, stackTrace) => _error(event.id, error));
  }

  Future addSpiff(Spiff spiff) {
    return Future.error('');
  }

  void download(DownloadIdentifier id, Uri uri, int size) {
    add(DownloadEvent(id, uri, size));
  }

  void _update(DownloadIdentifier id, int offset) {
    emit(state.update(id, offset));
  }

  void _complete(DownloadIdentifier id) {
    final download = state.get(id);
    if (download != null) {
      trackCacheRepository.put(id, download.file);
    }
    emit(state.complete(id));
  }

  Object? _error(DownloadIdentifier id, Object? error) {
    emit(state.error(id, error));
    return error;
  }
}
