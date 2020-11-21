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

import 'playlist.dart';

extension LocalFile on MediaItem {
  bool isLocalFile() {
    return id.startsWith(RegExp(r'^file'));
  }
}

/// This task defines logic for playing a list of podcast episodes.
class AudioPlayerTask extends BackgroundAudioTask {
  AudioPlayer _player = new AudioPlayer();
  AudioProcessingState _skipState;
  StreamSubscription<PlaybackEvent> _eventSubscription;

  List<MediaItem> queue = [];

  int get index => _player.currentIndex;

  MediaItem get mediaItem => index == null ? null : queue[index];
  ConcatenatingAudioSource _playlist;

  @override
  Future<dynamic> onCustomAction(String name, dynamic arguments) {
    if (name == 'stage') {
      _prepareQueue();
    } else if (name == 'stage+play') {
      _prepareQueue();
      if (!_player.playing) {
        _player.play();
      }
    }
    return Future.value(true);
  }

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    // We configure the audio session for speech since we're playing a podcast.
    // You can also put this in your app's initialisation if your app doesn't
    // switch between two types of audio as this example does.
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());

    // Broadcast media item changes.
    _player.currentIndexStream.listen((index) {
      if (index != null) _updateMediaItem(index);
    });

    _player.durationStream.listen((duration) {
      if (duration == null || index == null) {
        return;
      }
      // duration is known now
      queue[index] = queue[index].copyWith(duration: duration);
      AudioServiceBackground.setMediaItem(queue[index]);
    });

    // Propagate all events from the audio player to AudioService clients.
    _eventSubscription = _player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    // Special processing for state transitions.
    _player.processingStateStream.listen((state) {
      switch (state) {
        case ProcessingState.completed:
          PlaylistFacade().update(index: -1);
          break;
        case ProcessingState.ready:
        // If we just came from skipping between tracks, clear the skip
        // state now that we're ready to play.
          _skipState = null;
          break;
        default:
          break;
      }
    });
    // _prepareQueue();
  }

  void _updateMediaItem(int index) {
    AudioServiceBackground.setMediaItem(queue[index]);
    PlaylistFacade()
        .update(index: index, position: _player.position.inSeconds.toDouble());
  }

  Future<void> _prepareQueue() async {
    final mediaItemQueue = await PlaylistFacade().mediaItemQueue();
    queue = mediaItemQueue.queue;

    await AudioServiceBackground.setQueue(queue);
    await AudioServiceBackground.setMediaItem(queue[mediaItemQueue.index]);
    if (queue.length == 0) {
      // TODO stop
      return;
    }

    try {
      _playlist = ConcatenatingAudioSource(
          children: queue
              .map((item) => AudioSource.uri(Uri.parse(item.id),
              headers: item.isLocalFile() ? null : mediaItemQueue.headers))
              .toList());
      await _player.load(_playlist,
          initialIndex: mediaItemQueue.index,
          initialPosition: Duration(seconds: mediaItemQueue.position.toInt()));
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Future<void> onSkipToQueueItem(String mediaId) async {
    print('onSkipToQueueItem $mediaId');

    // Then default implementations of onSkipToNext and onSkipToPrevious will
    // delegate to this method.
    final newIndex = queue.indexWhere((item) => item.id == mediaId);
    if (newIndex == -1)
      return
        // During a skip, the player may enter the buffering state. We could just
        // propagate that state directly to AudioService clients but AudioService
        // has some more specific states we could use for skipping to next and
        // previous. This variable holds the preferred state to send instead of
        // buffering during a skip, and it is cleared as soon as the player exits
        // buffering (see the listener in onStart).
        _skipState = newIndex > index
            ? AudioProcessingState.skippingToNext
            : AudioProcessingState.skippingToPrevious;
    // This jumps to the beginning of the queue item at newIndex.
    _player.seek(Duration.zero, index: newIndex);
  }

  // @override
  // Future<void> onAddQueueItem(MediaItem mediaItem) async {
  // }

  @override
  Future<void> onPlayMediaItem(MediaItem mediaItem) async {
    int index = 0;
    for (var i in queue) {
      if (i == mediaItem) {
        _player.seek(Duration(seconds: 0), index: index);
        break;
      }
      index++;
    }
  }

  @override
  Future<void> onPlay() => _player.play();

  @override
  Future<void> onPause() => _player.pause();

  @override
  Future<void> onSeekTo(Duration position) => _player.seek(position);

  @override
  Future<void> onFastForward() => _seekRelative(fastForwardInterval);

  @override
  Future<void> onRewind() => _seekRelative(-rewindInterval);

  @override
  Future<void> onStop() async {
    await _player.pause();
    await _player.dispose();
    _eventSubscription.cancel();
    // It is important to wait for this state to be broadcast before we shut
    // down the task. If we don't, the background task will be destroyed before
    // the message gets sent to the UI.
    await _broadcastState();
    // Shut down this task
    await super.onStop();
  }

  /// Jumps away from the current position by [offset].
  Future<void> _seekRelative(Duration offset) async {
    var newPosition = _player.position + offset;
    // Make sure we don't jump out of bounds.
    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (newPosition > mediaItem.duration) newPosition = mediaItem.duration;
    // Perform the jump via a seek.
    await _player.seek(newPosition);
  }

  /// Broadcasts the current state to all clients.
  Future<void> _broadcastState() async {
    await AudioServiceBackground.setState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: [
        MediaAction.seekTo,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      ],
      androidCompactActions: [0, 1, 3],
      processingState: _getProcessingState(),
      playing: _player.playing,
      position: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
  }

  /// Maps just_audio's processing state into into audio_service's playing
  /// state. If we are in the middle of a skip, we use [_skipState] instead.
  AudioProcessingState _getProcessingState() {
    if (_skipState != null) return _skipState;
    switch (_player.processingState) {
      case ProcessingState.none:
        return AudioProcessingState.stopped;
      case ProcessingState.loading:
        return AudioProcessingState.connecting;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        throw Exception("Invalid state: ${_player.processingState}");
    }
  }
}
