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

// This file is heavily based on the audio_service example app located here:
// https://github.com/ryanheise/audio_service

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:logging/logging.dart';
import 'package:takeout_app/settings.dart';

import 'model.dart';
import 'playlist.dart';
import 'progress.dart';

extension TakeoutMediaItem on MediaItem {
  Map<String, String>? headers() {
    return isLocalFile() ? null : extras?[ExtraHeaders];
  }

  IndexedAudioSource toAudioSource() {
    return AudioSource.uri(Uri.parse(id), headers: headers());
  }

  bool isLocalFile() {
    return id.startsWith(RegExp(r'^file'));
  }

  bool isRemote() {
    return id.startsWith(RegExp(r'^http'));
  }

  bool isPodcast() {
    return _isMediaType(MediaType.podcast);
  }

  bool isStream() {
    return _isMediaType(MediaType.stream);
  }

  bool isMusic() {
    return _isMediaType(MediaType.music);
  }

  bool _isMediaType(MediaType type) {
    return (extras?[ExtraMediaType] ?? '') == type.name;
  }

  // EndZone is considered the "end" at which progress is complete.
  // Currently this is the last 5% of the media.
  Duration? get endZone {
    final end = duration;
    return end == null ? null : end * 0.95;
  }

  bool trackProgress() {
    // don't track songs or radio streams
    return isPodcast();
  }

  String get etag => extras?[ExtraETag] ?? '';
}

class AudioPlayerHandler extends BaseAudioHandler with QueueHandler {
  static final log = Logger('AudioPlayerHandler');

  AudioPlayer _player = new AudioPlayer();

  final BehaviorSubject<List<MediaItem>> _recentSubject =
      BehaviorSubject.seeded(<MediaItem>[]);

  MediaState? _state;

  int? get index => _player.currentIndex;

  MediaItem? get currentItem => index == null ? null : _state?.current;

  MediaState? get currentState => _state;

  MediaItem? itemAt(int index) {
    return _state?.queue.elementAt(index);
  }

  AudioPlayerHandler() {
    _init();
  }

  AudioPlayer get player => _player;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());

    // For Android 11, record the most recent item so it can be resumed.
    mediaItem
        .whereType<MediaItem>()
        .listen((item) => _recentSubject.add([item]));

    // Broadcast media item changes.
    _player.currentIndexStream.listen((index) {
      if (index != null) onMediaIndexChanged(index);
    });

    // Update when media duration changes.
    _player.durationStream.listen((duration) {
      if (duration == null || index == null) {
        return;
      }
      log.fine('duration known $duration for ${currentState?.current.title}');
      // duration is known now
      final state = currentState;
      if (state != null) {
        state.current = state.current.copyWith(duration: duration);
        mediaItem.add(state.current);
      }
    });

    _player.icyMetadataStream.listen((event) {
      var current = currentItem;
      if (currentItem != null) {
        final title = event?.info?.title ?? current?.title ?? '';
        current = current!.copyWith(title: title);
        mediaItem.add(current);
      }
    });

    // Propagate all events from the audio player to AudioService clients.
    _player.playbackEventStream.listen((state) {
      _broadcastState(state);
    });

    // Special processing for state transitions.
    _player.processingStateStream.listen((state) {
      /// FIXME TODO commented out for simple testing
      // if (state == ProcessingState.completed) {
      //   skipToQueueItem(0).whenComplete(() => stop());
      // }
    });

    _player.playerStateStream.listen((state) {
      if (state.playing == false) {
        _savePosition();
      }
    });

    // This will auto-remove progress at the "end" of the media.
    // Not sure if this is desired right now so commented.
    //
    // _player.positionStream.listen((pos) {
    //   final item = mediaItem.value;
    //   if (item != null) {
    //     final endZone = item.endZone;
    //     if (endZone != null && pos > endZone) {
    //       Progress.remove(item.etag);
    //     }
    //   }
    // });
  }

  Stream<Duration> positionStream() {
    return _player.positionStream;
  }

  bool get playing => _player.playing;

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) {
    log.info('onCustomAction $name / $extras');
    if (name == 'stage') {
      _loadPlaylist(extras!['spiff'] as String);
    } else if (name == 'doit') {
      _loadPlaylist(extras!['spiff'] as String, startPlayback: true);
      // if (!_player.playing) {
      //   _player.play();
      // }
    }
    return Future.value(true);
  }

  Future<void> _loadPlaylist(String location, {bool startPlayback = false}) async {
    _reload(Uri.parse(location), startPlayback);
  }

  GapfulAudioSource? gapfulAudioSource;

  void _reload(Uri uri, bool startPlayback) async {
    final newState = await MediaQueue.load(uri);
    queue.add(newState.queue);
    _state = newState;

    if (_player.playing) {
      startPlayback = true;
    }
    // final wasPlaying = _player.playing;

    final tracks = newState.queue.map((item) => item.toAudioSource()).toList();

    if (settingsLiveType() == LiveType.none) {
      final source = ConcatenatingAudioSource(children: tracks);
      final pos = await getSavedPosition(newState.current);
      await _player.setAudioSource(source,
          preload: false, initialPosition: pos, initialIndex: newState.index);
      if (startPlayback) {
        _player.play();
      }
    } else {
      log.fine('gapful audiosource ${tracks.length}');
      gapfulAudioSource?.dispose();
      gapfulAudioSource = GapfulAudioSource(this, tracks);
      await gapfulAudioSource?.preparePlayer(startPlayback);
    }
  }

  void onMediaIndexChanged(int index) {
    log.fine('onMediaIndexChanged to $index');
    final state = currentState;
    if (state != null) {
      final item = state.item(index);
      if (item != null) {
        mediaItem.add(item);
        _restorePosition();
        state.update(index, _player.position.inSeconds.toDouble());
      }
    }
  }

  @override
  Future<void> addQueueItem(MediaItem item) {
    final state = currentState;
    if (state != null) {
      state.add(item);
      queue.add(state.queue);
    }

    AudioSource? source = _player.audioSource;
    if (source is ConcatenatingAudioSource) {
      log.fine('adding ConcatenatingAudioSource item');
      return source.add(item.toAudioSource());
    } else if (source is ProgressiveAudioSource && gapfulAudioSource != null) {
      log.fine('adding GapfulAudioSource item');
      gapfulAudioSource?.add(item.toAudioSource());
      return Future.value();
    }
    log.warning('bummer cannot addQueueItem $source');
    return Future.value();
  }

  // TODO
  // @override
  // Future<List<MediaItem>> getChildren(String parentMediaId,
  //     [Map<String, dynamic>? options]) async {
  //   switch (parentMediaId) {
  //     case AudioService.recentRootId:
  //       // When the user resumes a media session, tell the system what the most
  //       // recently played item was.
  //       return _recentSubject.value];
  //     default:
  //       // Allow client to browse the media library.
  //       return [_state!.findId(parentMediaId)];
  //   }
  // }
  //
  // @override
  // ValueStream<Map<String, dynamic>> subscribeToChildren(String parentMediaId) {
  //   switch (parentMediaId) {
  //     case AudioService.recentRootId:
  //       return _recentSubject.map((_) => <String, dynamic>{});
  //     default:
  //       return Stream.value(_mediaLibrary.items[parentMediaId])
  //           .map((_) => <String, dynamic>{})
  //           .shareValue();
  //   }
  // }

  @override
  Future<void> skipToQueueItem(int index) async {
    log.fine('skipToQueueItem $index');
    // Then default implementations of onSkipToNext and onSkipToPrevious will
    // delegate to this method.
    final state = currentState;
    if (state == null) {
      return;
    }
    var newIndex = index; //state.findId(mediaId);
    if (newIndex == -1) {
      //final currentIndex = index;
      // During a skip, the player may enter the buffering state. We could just
      // propagate that state directly to AudioService clients but AudioService
      // has some more specific states we could use for skipping to next and
      // previous. This variable holds the preferred state to send instead of
      // buffering during a skip, and it is cleared as soon as the player exits
      // buffering (see the listener in onStart).

      // FIXME
      // _skipState = newIndex > currentIndex
      //     ? AudioProcessingState.skippingToNext
      //     : AudioProcessingState.skippingToPrevious;
      return;
    }

    if (newIndex == state.index - 1) {
      // skipping to previous
      if (_player.position.inSeconds > 10) {
        // skip to beginning before going to previous
        newIndex = state.index;
      }
    }

    log.fine('skip seek to $newIndex');

    AudioSource? source = _player.audioSource;
    if (source is ConcatenatingAudioSource) {
      // This jumps to the beginning of the queue item at newIndex.
      return _player.seek(Duration.zero, index: newIndex);
    } else if (gapfulAudioSource != null) {
      gapfulAudioSource?.skipToIndex(newIndex);
    }
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    int? index = currentState?.findItem(item);
    if (index != null && index != -1) {
      _player.seek(Duration.zero, index: index);
    }
  }

  @override
  Future<void> removeQueueItem(MediaItem item) {
    int? index = currentState?.findItem(item);
    if (index != null && index != -1) {
      AudioSource? source = _player.audioSource;
      if (source is ConcatenatingAudioSource) {
        return source.removeAt(index);
      }
    }
    return Future.value();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) =>
      _player.seek(position); // TODO _savePosition?

  @override
  Future<void> fastForward() => _player.seek(
      _seekCheck(_player.position + AudioService.config.fastForwardInterval));

  @override
  Future<void> rewind() => _player
      .seek(_seekCheck(_player.position - AudioService.config.rewindInterval));

  @override
  Future<void> stop() async {
    await _player.stop();
    await playbackState.firstWhere(
        (state) => state.processingState == AudioProcessingState.idle);
  }

  Duration _seekCheck(Duration pos) {
    if (pos < Duration.zero) {
      return Duration.zero;
    }
    final end = currentItem?.duration;
    if (end != null && pos > end) {
      pos = end;
    }
    return pos;
  }

  /// Broadcasts the current state to all clients.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    var controls = <MediaControl>[];
    var compactControls = <int>[];
    final isPodcast = currentItem?.isPodcast() ?? false;
    final isStream = currentItem?.isStream() ?? false;

    if (isPodcast) {
      controls = [
        MediaControl.rewind,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
      ];
      compactControls = const [0, 1, 2];
    } else if (isStream) {
      controls = [
        if (playing) MediaControl.pause else MediaControl.play,
      ];
      compactControls = const [0];
    } else {
      controls = [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ];
      compactControls = const [0, 1, 2];
    }

    playbackState.add(playbackState.value.copyWith(
      controls: controls,
      systemActions: const {
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
        MediaAction.stop,
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: compactControls,
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  Future<Duration> getSavedPosition(MediaItem item) async {
    return item.trackProgress()
        ? Progress.position(item.etag)
        : Future.value(Duration.zero);
  }

  void _restorePosition() {
    final item = mediaItem.value;
    if (item != null && item.trackProgress()) {
      Progress.position(item.etag).then((pos) {
        seek(pos);
      });
    }
  }

  void _savePosition() {
    final pos = _player.position;

    // save the spiff state
    MediaQueue.savePosition(pos);

    // save progress
    final item = mediaItem.value;
    if (item != null && item.trackProgress()) {
      Progress.update(item.etag, pos, _player.duration ?? Duration.zero);
    }
  }
}

class GapfulAudioSource extends AudioSource {
  static final Logger log = Logger('GapfulAudioSource');
  static const gapDuration = Duration(seconds: 5);

  StreamSubscription? stateStreamSubscription;
  final AudioPlayerHandler _audioPlayerHandler;
  final List<IndexedAudioSource> tracks;
  int _index;
  bool _disposed = false;

  GapfulAudioSource(this._audioPlayerHandler, this.tracks, [int? index])
      : _index = index ?? 0;

  @override
  List<IndexedAudioSource> get sequence => tracks;

  @override
  List<int> get shuffleIndices => [0]; // TODO

  void dispose() {
    _disposed = true;
    stateStreamSubscription?.cancel();
    stateStreamSubscription = null;
  }

  Future<void> preparePlayer(bool startPlayback) async {
    if (_audioPlayerHandler.playing) {
      _audioPlayerHandler.pause();
    }

    stateStreamSubscription?.cancel();
    stateStreamSubscription = null;

    final item = _audioPlayerHandler.itemAt(index)!;
    log.fine('preparePlayer for $index ${item.title}');
    // final pos = await _audioPlayerHandler.getSavedPosition(item);
    final pos = Duration(seconds: 0);
    // _audioPlayerHandler.mediaItem.add(item);
    await _audioPlayerHandler.player.setAudioSource(currentTrack,
        preload: true, initialPosition: pos, initialIndex: 0);

    stateStreamSubscription = _audioPlayerHandler.player.processingStateStream
        .distinct()
        .listen((state) async {
      if (_disposed) {
        stateStreamSubscription?.cancel();
        return;
      }
      if (state == ProcessingState.completed) {
        log.fine('gapful state is $state');
        if (hasNext) {
          // add a gap and play the next track
          // log.fine('waiting $gapDuration seconds');
          // await Future.delayed(gapDuration);
          log.fine('skipToNext $index');
          skipToNext();
          // log.fine('after skipToNext $index');
          // _audioPlayerHandler.onMediaIndexChanged(index);
          // preparePlayer(_audioPlayerHandler.playing);
        } else {
          // all done
          stateStreamSubscription?.cancel();
          _audioPlayerHandler.stop();
        }
      }
    });

    if (startPlayback) {
      log.fine('waiting $gapDuration');
      await Future.delayed(gapDuration);
      _audioPlayerHandler.play();
    }
  }

  void add(IndexedAudioSource audioSource) {
    tracks.add(audioSource);
  }

  bool removeAt(int i) {
    if (i >= 0 && i < tracks.length) {
      tracks.removeAt(i);
      return true;
    }
    return false;
  }

  bool get hasNext {
    return _index + 1 < tracks.length;
  }

  bool skipToIndex(int i) {
    if (i >= 0 && i < tracks.length) {
      _index = i;
      _audioPlayerHandler.onMediaIndexChanged(_index);
      preparePlayer(_audioPlayerHandler.playing);
      return true;
    }
    return false;
  }

  bool skipToNext() {
    return skipToIndex(_index + 1);
  }

  int get index => _index;

  IndexedAudioSource get currentTrack => tracks[_index];

  IndexedAudioSource? get nextTrack => hasNext ? tracks[_index + 1] : null;
}
