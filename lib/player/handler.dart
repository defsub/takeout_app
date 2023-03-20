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

// This file is based on the audio_service example app located here:
// https://github.com/ryanheise/audio_service

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:takeout_app/cache/offset_repository.dart';
import 'package:takeout_app/client/resolver.dart';
import 'package:takeout_app/settings/repository.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/tokens/repository.dart';

import 'provider.dart';

extension TakeoutMediaItem on MediaItem {
  bool isLocalFile() => id.startsWith(RegExp(r'^file'));

  bool isRemote() => id.startsWith(RegExp(r'^http'));
}

class TakeoutPlayerHandler extends BaseAudioHandler with QueueHandler {
  static final log = Logger('AudioPlayerHandler');

  final MediaTrackResolver trackResolver;
  final TokenRepository tokenRepository;
  final SettingsRepository settingsRepository;
  final OffsetCacheRepository offsetRepository;

  final AudioPlayer _player = new AudioPlayer();
  final PlayerCallback onPlay;
  final PlayerCallback onPause;
  final StoppedCallback onStop;
  final IndexCallback onIndexChange;
  final PositionCallback onPositionChange;
  final PositionCallback onDurationChange;
  final TrackChangeCallback onTrackChange;
  final TrackEndCallback onTrackEnd;

  final _subscriptions = <StreamSubscription>[];

  Spiff _spiff = Spiff.empty();
  final _queue = <MediaItem>[];

  final Duration _skipToBeginningInterval;

  TakeoutPlayerHandler._(
      {required this.onPlay,
      required this.onPause,
      required this.onStop,
      required this.onIndexChange,
      required this.onPositionChange,
      required this.onDurationChange,
      required this.onTrackChange,
      required this.onTrackEnd,
      required this.trackResolver,
      required this.tokenRepository,
      required this.settingsRepository,
      required this.offsetRepository,
      Duration? skipToBeginningInterval})
      : _skipToBeginningInterval =
            skipToBeginningInterval ?? Duration(seconds: 10) {
    _init();
  }

  static Future<TakeoutPlayerHandler> create(
      {required MediaTrackResolver trackResolver,
      required TokenRepository tokenRepository,
      required SettingsRepository settingsRepository,
      required OffsetCacheRepository offsetRepository,
      required PlayerCallback onPlay,
      required PlayerCallback onPause,
      required StoppedCallback onStop,
      required IndexCallback onIndexChange,
      required PositionCallback onPositionChange,
      required PositionCallback onDurationChange,
      required TrackChangeCallback onTrackChange,
      required TrackEndCallback onTrackEnd,
      Duration? skipBeginningInterval,
      Duration? fastForwardInterval,
      Duration? rewindInterval}) async {
    return await AudioService.init(
        builder: () => TakeoutPlayerHandler._(
            onPlay: onPlay,
            onPause: onPause,
            onStop: onStop,
            onIndexChange: onIndexChange,
            onPositionChange: onPositionChange,
            onDurationChange: onDurationChange,
            onTrackChange: onTrackChange,
            onTrackEnd: onTrackEnd,
            trackResolver: trackResolver,
            tokenRepository: tokenRepository,
            settingsRepository: settingsRepository,
            offsetRepository: offsetRepository,
            skipToBeginningInterval: skipBeginningInterval),
        config: AudioServiceConfig(
          androidNotificationIcon: 'drawable/ic_stat_name',
          androidNotificationChannelId: 'com.defsub.takeout.channel.audio',
          androidNotificationChannelName: 'Audio playback',
          androidNotificationOngoing: true,
          fastForwardInterval:
              fastForwardInterval ?? const Duration(seconds: 30),
          rewindInterval: rewindInterval ?? const Duration(seconds: 10),
        ));
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());

    // index changes
    _subscriptions.add(_player.currentIndexStream.listen((index) {
      if (index == null) {
        // player sends index as null at startup
        return;
      }
      if (index >= 0 && index < _spiff.length) {
        print(
            'index change $index ${_spiff.playlist.tracks.length}  ${_queue.length}');
        _spiff = _spiff.copyWith(index: index);
        onIndexChange(_spiff, _player.playing);
        mediaItem.add(_queue[index]);
      } else {
        print(
            'bad index change $index ${_spiff.playlist.tracks.length}  ${_queue.length}');
      }
    }));

    // media duration changes
    _subscriptions.add(_player.durationStream.listen((duration) {
      final item = mediaItem.valueOrNull;
      if (item != null && duration != null) {
        mediaItem.add(item.copyWith(duration: duration));
        onDurationChange(_spiff, _player.duration ?? Duration.zero,
            _player.position, _player.playing);
      }
    }));

    // player position changes
    // TODO consider reducing position update frequency
    _subscriptions.add(_player.positionStream.listen((position) {
      if (_player.currentIndex == null) {
        return;
      }
      onPositionChange(_spiff, _player.duration ?? Duration.zero,
          _player.position, _player.playing);
    }));

    _player.positionDiscontinuityStream.listen((discontinuity) {
      if (discontinuity.reason == PositionDiscontinuityReason.autoAdvance) {
        final previousIndex = discontinuity.previousEvent.currentIndex;
        final duration = discontinuity.previousEvent.duration ?? Duration.zero;
        final position = discontinuity.previousEvent.updatePosition;
        if (previousIndex != null) {
          onTrackEnd(
              _spiff, previousIndex, duration, position, _player.playing);
        }
      }
    });

    // icy metadata changes
    // TODO icy events are happening for regular media and out of sync
    _subscriptions.add(_player.icyMetadataStream.listen((event) {
      // final item = mediaItem.valueOrNull;
      // print('icy event $event');
      // if (item != null && event != null) {
      //   final title = event.info?.title ?? item.title;
      //   mediaItem.add(item.copyWith(title: title));
      //
      //   _spiff.playlist.tracks[_spiff.index] =
      //       _spiff.playlist.tracks[_spiff.index].copyWith(title: title);
      //
      //   onTrackChange(_spiff, _spiff.index, title: event.info?.title);
      // }
    }));

    // send state from the audio player to AudioService clients.
    _subscriptions.add(_player.playbackEventStream.listen((state) {
      _broadcastState(state);
    }));

    // automatically go to the beginning of queue & stop.
    _subscriptions.add(_player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToQueueItem(0).whenComplete(() => stop());
        onStop(_spiff);
      }
    }));

    // player state changes (playing/paused)
    _subscriptions.add(_player.playerStateStream.distinct().listen((state) {
      if (_player.currentIndex == null) {
        return null;
      }
      if (state.playing == false &&
          state.processingState == ProcessingState.ready) {
        onPause(_spiff, _player.duration ?? Duration.zero, _player.position);
      } else {
        onPlay(_spiff, _player.duration ?? Duration.zero, _player.position);
      }
    }));

    // keep track of position changes and update history once a track is considered played
    // 180 = 18 secs
    // _subscriptions.add(_player.createPositionStream(steps: 10,
    //     minPeriod: const Duration(seconds: 1),
    //     maxPeriod: const Duration(seconds: 10)).listen((position) {
    // }));
  }

  void dispose() {
    _subscriptions.forEach((subscription) => subscription.cancel());
  }

  Future<MediaItem> _map(Entry entry) async {
    String image = entry.image;
    if (image.startsWith('/img/')) {
      image = '${settingsRepository.settings?.endpoint}$image';
    }
    final uri = await trackResolver.resolve(entry);
    String id = uri.toString();
    if (id.startsWith('/api/')) {
      id = '${settingsRepository.settings?.endpoint}$id';
    }
    return MediaItem(
        id: id,
        album: entry.album,
        title: entry.title,
        artist: entry.creator,
        artUri: Uri.parse(image));
  }

  Future<List<MediaItem>> _mapAll(List<Entry> tracks) async {
    final list = <MediaItem>[];
    await Future.forEach<Entry>(tracks, (entry) async {
      list.add(await _map(entry));
    });
    return list;
  }

  IndexedAudioSource toAudioSource(MediaItem item,
      {Map<String, String>? headers}) {
    return AudioSource.uri(Uri.parse(item.id), headers: headers);
  }

  Future<void> load(Spiff spiff) async {
    this._spiff = spiff;
    final index = _spiff.index < 0 ? 0 : _spiff.index;

    // build a new MediaItem queue
    _queue.clear();
    _queue.addAll(await _mapAll(_spiff.playlist.tracks));

    // broadcast queue state
    queue.add(_queue);

    // build audio sources from the queue
    final headers = tokenRepository.addMediaToken();
    final sources = _queue
        .map((item) =>
            toAudioSource(item, headers: item.isRemote() ? headers : null))
        .toList();
    final source = ConcatenatingAudioSource(children: []);
    source.addAll(sources);

    final offset = await offsetRepository.get(_spiff.playlist.tracks[index]);
    final position = offset?.position() ?? Duration.zero;

    // this sends events so use the correct index and position even though
    // skipToQueueItem does the same thing later
    await _player.setAudioSource(source,
        initialIndex: index, initialPosition: position);

    return skipToQueueItem(index);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final offset = await offsetRepository.get(_spiff.playlist.tracks[index]);
    var position = offset?.position() ?? Duration.zero;

    final currentIndex = _player.currentIndex;
    if (currentIndex != null && index == currentIndex - 1) {
      if (_player.position > _skipToBeginningInterval) {
        // skip to beginning before going to previous
        index = currentIndex;
        position = Duration.zero;
      }
    }

    // keep the spiff updated
    _spiff = _spiff.copyWith(index: index);
    onIndexChange(_spiff, _player.playing);

    // update the current media item
    mediaItem.add(_queue[index]);
    playbackState.add(playbackState.value.copyWith(queueIndex: index));

    // onPositionChange(_spiff, _player.duration ?? Duration.zero, position, _player.playing);

    return _player.seek(position, index: index);
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    final index = _queue.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      skipToQueueItem(index);
    }
  }

  @override
  Future<void> play() => _player.play();

  Future<void> playIndex(int index) {
    return skipToQueueItem(index).whenComplete(() {
      if (_player.playing == false) {
        _player.play();
      }
    });
  }

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

    // wait for `idle`
    await playbackState.firstWhere(
        (state) => state.processingState == AudioProcessingState.idle);

    // Set the audio_service state to `idle` to deactivate the notification.
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
    ));
  }

  Duration _seekCheck(Duration pos) {
    if (pos < Duration.zero) {
      return Duration.zero;
    }

    final currentItem = mediaItem.valueOrNull;
    final end = currentItem?.duration;
    if (end != null && pos > end) {
      pos = end;
    }
    return pos;
  }

  /// Broadcasts the current state to all clients.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    List<MediaControl> controls;
    List<int> compactControls;

    final isPodcast = _spiff.isPodcast();
    final isStream = _spiff.isStream();

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
}
