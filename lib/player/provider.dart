// Copyright (C) 2023 The Takeout Authors.
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

import 'package:takeout_app/cache/offset_repository.dart';
import 'package:takeout_app/client/resolver.dart';
import 'package:takeout_app/settings/repository.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/tokens/repository.dart';

import 'handler.dart';

final dummyPlayerCallback = (_, __, ___) {};
final dummyStoppedCallback = (_) {};
final dummyTrackChangeCallback = (_, __, {String? title}) {};
final dummyPositionCallback = (_, __, ___, ____) {};
final dummyProgressCallback = (_, __, ___, ____) {};
final dummyIndexCallback = (_, __) {};
final dummyTrackEndCallback = (_, __, ___, ____, _____) {};

typedef PlayerCallback = void Function(Spiff, Duration, Duration);
typedef IndexCallback = void Function(Spiff, bool);
typedef PositionCallback = void Function(Spiff, Duration, Duration, bool);
typedef ProgressCallback = void Function(Spiff, Duration, Duration, bool);
typedef StoppedCallback = void Function(Spiff);
typedef TrackChangeCallback = void Function(Spiff, int index, {String? title});
typedef TrackEndCallback = void Function(
    Spiff, int index, Duration, Duration, bool);

abstract class PlayerProvider {
  Future<void> init(
      {required MediaTrackResolver trackResolver,
      required TokenRepository tokenRepository,
      required SettingsRepository settingsRepository,
      required OffsetCacheRepository offsetRepository,
      PlayerCallback? onPlay,
      PlayerCallback? onPause,
      StoppedCallback? onStop,
      IndexCallback? onIndexChange,
      PositionCallback? onPositionChange,
      PositionCallback? onDurationChange,
      ProgressCallback? onProgressChange,
      TrackChangeCallback? onTrackChange,
      TrackEndCallback? onTrackEnd});

  Future<void> load(Spiff spiff);

  void play();

  void playIndex(int index);

  void pause();

  void stop();

  void seek(Duration position);

  void skipForward();

  void skipBackward();

  void skipToIndex(int index);

  void skipToNext();

  void skipToPrevious();
}

class DefaultPlayerProvider implements PlayerProvider {
  late final TakeoutPlayerHandler handler;

  @override
  Future<void> init(
      {required MediaTrackResolver trackResolver,
      required TokenRepository tokenRepository,
      required SettingsRepository settingsRepository,
      required OffsetCacheRepository offsetRepository,
      PlayerCallback? onPlay,
      PlayerCallback? onPause,
      StoppedCallback? onStop,
      IndexCallback? onIndexChange,
      PositionCallback? onPositionChange,
      PositionCallback? onDurationChange,
      ProgressCallback? onProgressChange,
      TrackChangeCallback? onTrackChange,
      TrackEndCallback? onTrackEnd}) async {
    handler = await TakeoutPlayerHandler.create(
        trackResolver: trackResolver,
        tokenRepository: tokenRepository,
        settingsRepository: settingsRepository,
        offsetRepository: offsetRepository,
        onPlay: onPlay ?? dummyPlayerCallback,
        onPause: onPause ?? dummyPlayerCallback,
        onStop: onStop ?? dummyStoppedCallback,
        onIndexChange: onIndexChange ?? dummyIndexCallback,
        onPositionChange: onPositionChange ?? dummyPositionCallback,
        onDurationChange: onDurationChange ?? dummyPositionCallback,
        onProgressChange: onProgressChange ?? dummyProgressCallback,
        onTrackChange: onTrackChange ?? dummyTrackChangeCallback,
        onTrackEnd: onTrackEnd ?? dummyTrackEndCallback);
  }

  @override
  Future<void> load(Spiff spiff) => handler.load(spiff);

  @override
  void play() => handler.play();

  @override
  void playIndex(int index) => handler.playIndex(index);

  @override
  void pause() => handler.pause();

  @override
  void stop() => handler.stop();

  @override
  void seek(Duration position) => handler.seek(position);

  @override
  void skipForward() => handler.fastForward();

  @override
  void skipBackward() => handler.rewind();

  @override
  void skipToIndex(int index) => handler.skipToQueueItem(index);

  @override
  void skipToNext() => handler.skipToNext();

  @override
  void skipToPrevious() => handler.skipToPrevious();
}
