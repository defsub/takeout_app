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

extension TakeoutMediaItem on MediaItem {
  bool isLocalFile() {
    return id.startsWith(RegExp(r'^file'));
  }
}

/// This task defines logic for playing a list of podcast episodes.
class AudioPlayerTask extends BackgroundAudioTask {
  AudioPlayer _player = new AudioPlayer();
  AudioProcessingState _skipState;
  StreamSubscription<PlaybackEvent> _eventSubscription;

  MediaState _state;

  int get index => _player.currentIndex;

  MediaItem get mediaItem => index == null ? null : _state.current;
  ConcatenatingAudioSource _playlist;

  @override
  Future<dynamic> onCustomAction(String name, dynamic arguments) {
    if (name == 'stage') {
      _loadPlaylist();
    } else if (name == 'stage+play') {
      _loadPlaylist();
      if (!_player.playing) {
        _player.play();
      }
    } else if (name == 'test') {
      _reload();
    }
    return Future.value(true);
  }

  Future<void> _loadPlaylist() async {
    _reload();
  }

  void _reload() async {
    var newState = await MediaQueue.load();
    var oldState = _state;

    bool canAppend = false;
    if (oldState != null && oldState.length > 0) {
      print('spiff old ${oldState.length} new ${newState.length}');
      if (newState.length > oldState.length) {
        for (var i = 0; i < oldState.length; i++) {
          canAppend = newState.item(i) == oldState.item(i);
          if (!canAppend) {
            break;
          }
        }
      }
    }

    // canAppend = true;

    _state = newState;
    await AudioServiceBackground.setQueue(_state.queue);
    await AudioServiceBackground.setMediaItem(_state.current);

    if (oldState != null && canAppend) {
      // append only
      for (var i = oldState.length; i < newState.length; i++) {
        final item = newState.item(i);
        print('spiff adding $i ${item}');
        await _playlist.insert(
            i,
            AudioSource.uri(Uri.parse(item.id),
                headers: item.isLocalFile() ? null : item.extras['headers']));
      }
    } else {
      // new playlist
      final wasPlaying = _player.playing;
      //await _player.pause();
      _playlist = ConcatenatingAudioSource(
          children: newState.queue
              .map((item) => AudioSource.uri(Uri.parse(item.id),
                  headers: item.isLocalFile() ? null : item.extras['headers']))
              .toList());
      print('player index ${newState.index} pos ${newState.position.toInt()}');
      await _player.setAudioSource(_playlist,
          preload: false,
          initialPosition: Duration(seconds: newState.position.toInt()),
          initialIndex: newState.index);
      if (wasPlaying) {
        _player.play();
      }
    }
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
      if (index != null) _mediaIndexChanged(index);
    });

    // Update when media duration changes.
    _player.durationStream.listen((duration) {
      if (duration == null || index == null) {
        return;
      }
      // duration is known now
      _state.current = _state.current.copyWith(duration: duration);
      AudioServiceBackground.setMediaItem(_state.current);
    });

    // Propagate all events from the audio player to AudioService clients.
    _eventSubscription = _player.playbackEventStream.listen((event) {
      // print('event is ${event.currentIndex} ${event.processingState.toString()}');
      _broadcastState();
    });
    // _player.playingStream.listen((playing) {
    //   _broadcastState();
    // });

    // Special processing for state transitions.
    _player.processingStateStream.listen((state) {
      switch (state) {
        case ProcessingState.completed:
          print("update completed");
          _state.update(0, 0);
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
  }

  void _mediaIndexChanged(int index) {
    print('update index changed $index');
    _state.update(index, _player.position.inSeconds.toDouble());
    AudioServiceBackground.setMediaItem(_state.item(index));
  }

  @override
  Future<void> onAddQueueItem(MediaItem item) {
    _loadPlaylist();
    // print('onAddQueueItem $item');
    // _state.add(item);
    // AudioServiceBackground.setQueue(_state.queue);
    // return _playlist.add(AudioSource.uri(Uri.parse(item.id),
    //     headers: item.isLocalFile() ? null : item.extras['headers']));
  }

  @override
  Future<void> onSkipToQueueItem(String mediaId) async {
    print('onSkipToQueueItem $mediaId');

    // Then default implementations of onSkipToNext and onSkipToPrevious will
    // delegate to this method.
    final newIndex = _state.findId(mediaId);
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

  @override
  Future<void> onPlayMediaItem(MediaItem item) async {
    int index = _state.findItem(item);
    if (index != -1) {
      _player.seek(Duration.zero, index: index);
    }
  }

  @override
  Future<void> onRemoveQueueItem(MediaItem item) {
    int index = _state.findItem(item);
    if (index != -1) {
      return _playlist.removeAt(index);
    }
    return Future.value();
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
      case ProcessingState.idle:
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
