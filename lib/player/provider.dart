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

final DummyPlayerCallback = (_, __, ___) {};
final DummyStoppedCallback = (_) {};
final DummyTrackChangeCallback = (_, __, {String? title}) {};
final DummyPositionCallback = (_, __, ___, ____) {};
final DummyProgressCallback = (_, __, ___, ____) {};
final DummyIndexCallback = (_, __) {};
final DummyTrackEndCallback = (_, __, ___, ____, _____) {};

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

  void load(Spiff spiff);

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
  late TakeoutPlayerHandler handler;

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
        onPlay: onPlay ?? DummyPlayerCallback,
        onPause: onPause ?? DummyPlayerCallback,
        onStop: onStop ?? DummyStoppedCallback,
        onIndexChange: onIndexChange ?? DummyIndexCallback,
        onPositionChange: onPositionChange ?? DummyPositionCallback,
        onDurationChange: onDurationChange ?? DummyPositionCallback,
        onProgressChange: onProgressChange ?? DummyProgressCallback,
        onTrackChange: onTrackChange ?? DummyTrackChangeCallback,
        onTrackEnd: onTrackEnd ?? DummyTrackEndCallback);
  }

  void load(Spiff spiff) => handler.load(spiff);

  void play() => handler.play();

  void playIndex(int index) => handler.playIndex(index);

  void pause() => handler.pause();

  void stop() => handler.stop();

  void seek(Duration position) => handler.seek(position);

  void skipForward() => handler.fastForward();

  void skipBackward() => handler.rewind();

  void skipToIndex(int index) => handler.skipToQueueItem(index);

  void skipToNext() => handler.skipToNext();

  void skipToPrevious() => handler.skipToPrevious();
}
