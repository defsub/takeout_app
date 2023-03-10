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
import 'package:logging/logging.dart';

import 'package:takeout_app/client/resolver.dart';
import 'package:takeout_app/tokens/repository.dart';
import 'package:takeout_app/settings/repository.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/cache/offset_repository.dart';
import 'package:takeout_app/model.dart';

import 'provider.dart';

const ExtraHeaders = 'headers';
const ExtraMediaTrack = 'mediaTrack';

extension TakeoutMediaItem on MediaItem {
  Map<String, String>? headers() =>
      _isLocalFile() ? null : extras?[ExtraHeaders];

  IndexedAudioSource toAudioSource() =>
      AudioSource.uri(Uri.parse(id), headers: headers());

  bool _isLocalFile() => id.startsWith(RegExp(r'^file'));

  bool _isRemote() => id.startsWith(RegExp(r'^http'));

  MediaTrack? _mediaTrack() => extras?[ExtraMediaTrack];

//
// bool monitorProgress() => isPodcast();
//
// String get etag => _mediaTrack()?.etag ?? '';
//
// // FIXME progress is using key not etag!
// String get key => etag;
}

class _MediaTrack implements MediaTrack {
  final MediaItem item;

  _MediaTrack(this.item);

  String get creator => item.artist ?? '';

  String get album => item.album ?? '';

  String get image => item.artUri?.toString() ?? '';

  int get year => item._mediaTrack()?.year ?? 0;

  String get title => item.title;

  String get etag => item._mediaTrack()?.etag ?? '';

  int get size => item._mediaTrack()?.size ?? 0;

  int get number => item._mediaTrack()?.number ?? 0;

  int get disc => item._mediaTrack()?.disc ?? 0;

  String get date => item._mediaTrack()?.date ?? '';

  String get location => item._mediaTrack()?.location ?? '';
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
  final TrackCallback onMediaTrackChange;

  final List<StreamSubscription> _subscriptions = [];

  Spiff _spiff = Spiff.empty();
  final _queue = <MediaItem>[];
  final _source = ConcatenatingAudioSource(children: []);

  final Duration _skipBeginningInterval;

  TakeoutPlayerHandler._(
      {required this.onPlay,
      required this.onPause,
      required this.onStop,
      required this.onIndexChange,
      required this.onPositionChange,
      required this.onDurationChange,
      required this.onMediaTrackChange,
      required this.trackResolver,
      required this.tokenRepository,
      required this.settingsRepository,
      required this.offsetRepository,
      Duration? skipBeginningInterval})
      : _skipBeginningInterval =
            skipBeginningInterval ?? Duration(seconds: 10) {
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
      required TrackCallback onMediaTrackChange,
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
            onMediaTrackChange: onMediaTrackChange,
            trackResolver: trackResolver,
            tokenRepository: tokenRepository,
            settingsRepository: settingsRepository,
            offsetRepository: offsetRepository,
            skipBeginningInterval: skipBeginningInterval),
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

  AudioPlayer get player => _player;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());

    // index changes
    _subscriptions.add(_player.currentIndexStream.listen((index) {
      if (index != null) {
        _spiff = _spiff.copyWith(index: index);
        onIndexChange(_spiff, _player.playing);
      }
    }));

    // media duration changes
    _subscriptions.add(_player.durationStream.listen((duration) {
      final item = mediaItem.valueOrNull;
      if (item != null && duration != null) {
        mediaItem.add(item.copyWith(duration: duration));
        onDurationChange(
            _spiff, _player.duration ?? Duration.zero, _player.position);
      }
    }));

    // player position changes
    _subscriptions.add(_player.positionStream.listen((position) {
      onPositionChange(
          _spiff, _player.duration ?? Duration.zero, _player.position);
    }));

    // icy metadata changes
    _subscriptions.add(_player.icyMetadataStream.listen((event) {
      final item = mediaItem.valueOrNull;
      if (item != null && event != null) {
        final title = event.info?.title ?? item.title;
        mediaItem.add(item.copyWith(title: title));
        onMediaTrackChange(_spiff, _MediaTrack(item));
      }
    }));

    // send state from the audio player to AudioService clients.
    _subscriptions.add(_player.playbackEventStream.listen((state) {
      _broadcastState(state, mediaItem.valueOrNull);
    }));

    // automatically go to the beginning of queue & stop.
    _subscriptions.add(_player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToQueueItem(0).whenComplete(() => stop());
        onStop(_spiff);
      }
    }));

    // player state changes (playing/paused)
    _subscriptions.add(_player.playerStateStream.listen((state) {
      if (state.playing == false) {
        onPause(_spiff, _player.duration ?? Duration.zero, _player.position);
      } else {
        onPlay(_spiff, _player.duration ?? Duration.zero, _player.position);
      }
    }));
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
    final headers = tokenRepository.addMediaToken(<String, String>{});
    return MediaItem(
      id: id,
      album: entry.album,
      title: entry.title,
      artist: entry.creator,
      artUri: Uri.parse(image),
      extras: {
        ExtraHeaders: headers,
        // ExtraMediaTrack: entry,
      },
    );
  }

  Future<List<MediaItem>> _mapAll(List<Entry> tracks) async {
    final list = <MediaItem>[];
    await Future.forEach<Entry>(tracks, (entry) async {
      list.add(await _map(entry));
    });
    return list;
  }

  void load(Spiff spiff) async {
    this._spiff = spiff;

    // build a new MediaItem queue
    _queue.clear();
    final items = await _mapAll(_spiff.playlist.tracks);
    _queue.addAll(items);
    queue.add(_queue);

    // build audio sources from the queue
    final sources = _queue.map((item) => item.toAudioSource()).toList();
    _source.clear();
    _source.addAll(sources);
    _player.setAudioSource(_source);

    skipToQueueItem(_spiff.index >= 0 ? _spiff.index : 0);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0) {
      return;
    }

    final currentIndex = _player.currentIndex;
    if (currentIndex != null && index == currentIndex - 1) {
      if (_player.position > _skipBeginningInterval) {
        // skip to beginning before going to previous
        index = currentIndex;
      }
    }

    // keep the spiff updated
    // TODO remove this?
    _spiff = _spiff.copyWith(index: index);

    final offset = await offsetRepository.get(_spiff.playlist.tracks[index]);
    return _player.seek(offset?.position() ?? Duration.zero, index: index);
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

    // TODO what does this do?
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
  void _broadcastState(PlaybackEvent event, MediaItem? item) {
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
