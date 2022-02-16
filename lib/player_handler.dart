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
import 'package:takeout_app/model.dart';

import 'playlist.dart';

extension TakeoutMediaItem on MediaItem {
  bool isLocalFile() {
    return id.startsWith(RegExp(r'^file'));
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
}

class AudioPlayerHandler extends BaseAudioHandler with QueueHandler {
  AudioPlayer _player = new AudioPlayer();

  final BehaviorSubject<List<MediaItem>> _recentSubject =
      BehaviorSubject.seeded(<MediaItem>[]);

  MediaState? _state;

  int? get index => _player.currentIndex;

  MediaItem? get currentItem => index == null ? null : _state?.current;
  ConcatenatingAudioSource? _playlist;

  MediaState? get currentState => _state;

  AudioPlayerHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());

    // For Android 11, record the most recent item so it can be resumed.
    mediaItem
        .whereType<MediaItem>()
        .listen((item) => _recentSubject.add([item]));

    // Broadcast media item changes.
    _player.currentIndexStream.listen((index) {
      if (index != null) _mediaIndexChanged(index);
    });

    // Update when media duration changes.
    _player.durationStream.listen((duration) {
      if (duration == null || index == null) {
        return;
      }
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
    _player.playbackEventStream.listen(_broadcastState);

    // Special processing for state transitions.
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        currentState?.update(0, 0);
        stop();
      }
    });
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) {
    print('onCustomAction $name / $extras');
    if (name == 'stage') {
      _loadPlaylist(extras!['spiff'] as String);
    } else if (name == 'doit') {
      _loadPlaylist(extras!['spiff'] as String);
      if (!_player.playing) {
        _player.play();
      }
    }
    return Future.value(true);
  }

  Future<void> _loadPlaylist(String location) async {
    _reload(Uri.parse(location));
  }

  void _reload(Uri uri) async {
    var newState = await MediaQueue.load(uri);

    //await AudioServiceBackground.setQueue(newState.queue);
    //await AudioServiceBackground.setMediaItem(newState.current);
    queue.add(newState.queue);

    _state = newState;

    // new playlist
    final wasPlaying = _player.playing;
    final source = ConcatenatingAudioSource(
        children: newState.queue
            .map((item) => AudioSource.uri(Uri.parse(item.id),
                headers:
                    item.isLocalFile() ? null : item.extras?[ExtraHeaders]))
            .toList());
    _playlist = source;
    final pos = Duration(seconds: newState.position.toInt());
    print('player index ${newState.index} pos $pos');
    await _player.setAudioSource(source,
        preload: false,
        initialPosition: pos,
        initialIndex: newState.index);
    if (wasPlaying) {
      _player.play();
    }
  }

  void _mediaIndexChanged(int index) {
    print('update index changed $index');
    final state = currentState;
    if (state != null) {
      final item = state.item(index);
      if (item != null) {
        state.update(index, _player.position.inSeconds.toDouble());
        mediaItem.add(item);
      }
    }
  }

  @override
  Future<void> addQueueItem(MediaItem item) {
    // TODO is this used?
    //return _loadPlaylist(Client.getDefaultPlaylistUrl());
    print('XXX add queue item $item');
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
  //       print("### get recent children: ${_recentSubject.value}:");
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
    print('onSkipToQueueItem $index');

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

    // This jumps to the beginning of the queue item at newIndex.
    _player.seek(Duration.zero, index: newIndex);
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
      return _playlist!.removeAt(index);
    }
    return Future.value();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

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
        if (playing) MediaControl.pause else
          MediaControl.play,
        MediaControl.fastForward,
      ];
      compactControls = const [0, 1, 2];
    } else if (isStream) {
      controls = [
        if (playing) MediaControl.pause else
          MediaControl.play,
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
}
