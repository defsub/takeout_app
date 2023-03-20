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

import 'package:bloc/bloc.dart';
import 'package:takeout_app/cache/offset_repository.dart';
import 'package:takeout_app/client/resolver.dart';
import 'package:takeout_app/model.dart';
import 'package:takeout_app/player/provider.dart';
import 'package:takeout_app/settings/repository.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/tokens/repository.dart';

abstract class PlayerState {
  final Spiff spiff;

  PlayerState(this.spiff);

  int get currentIndex => spiff.index >= 0 ? spiff.index : 0;

  int get lastIndex => spiff.length - 1;

  MediaTrack? get currentTrack => spiff.playlist.tracks.length > 0
      ? spiff.playlist.tracks[currentIndex]
      : null;
}

abstract class PlayerPositionState extends PlayerState {
  final Duration duration;
  final Duration position;
  final bool playing;

  PlayerPositionState(super.spiff,
      {required this.duration, required this.position, required this.playing});

  bool get considerPlayed {
    final d = duration * 0.5;
    return duration > Duration.zero && position > d;
  }

  bool get considerComplete {
    final d = duration * 0.95;
    return duration > Duration.zero && position > d;
  }

  double get progress {
    final pos = position.inSeconds.toDouble();
    return duration > Duration.zero ? pos / duration.inSeconds.toDouble() : 0.0;
  }
}

class PlayerLoad extends PlayerState {
  PlayerLoad(super.spiff);
}

class PlayerInit extends PlayerState {
  PlayerInit() : super(Spiff.empty());
}

class PlayerReady extends PlayerState {
  PlayerReady() : super(Spiff.empty());
}

class PlayerPlay extends PlayerPositionState {
  PlayerPlay(super.spiff,
      {required super.duration, required super.position, super.playing = true});
}

class PlayerPause extends PlayerPositionState {
  PlayerPause(super.spiff,
      {required super.duration,
      required super.position,
      super.playing = false});
}

class PlayerStop extends PlayerState {
  PlayerStop(super.spiff);
}

class PlayerIndexChange extends PlayerState {
  final bool playing;

  PlayerIndexChange(super.spiff, this.playing);
}

class PlayerPositionChange extends PlayerPositionState {
  PlayerPositionChange(super.spiff,
      {required super.duration,
      required super.position,
      required super.playing});
}

class PlayerDurationChange extends PlayerPositionState {
  PlayerDurationChange(super.spiff,
      {required super.duration,
      required super.position,
      required super.playing});
}

class PlayerTrackChange extends PlayerState {
  final int index;
  final String? title;

  PlayerTrackChange(super.spiff, this.index, {this.title});
}

class PlayerTrackEnd extends PlayerState {
  final int index;
  final Duration duration;
  final Duration position;

  PlayerTrackEnd(super.spiff, this.index,
      {required this.duration, required this.position});
}

class Player extends Cubit<PlayerState> {
  final PlayerProvider _provider;
  final MediaTrackResolver trackResolver;
  final TokenRepository tokenRepository;
  final SettingsRepository settingsRepository;
  final OffsetCacheRepository offsetRepository;

  Player(
      {required this.trackResolver,
      required this.tokenRepository,
      required this.settingsRepository,
      required this.offsetRepository,
      PlayerProvider? provider})
      : _provider = provider ?? DefaultPlayerProvider(),
        super(PlayerInit()) {
    _provider
        .init(
            tokenRepository: tokenRepository,
            settingsRepository: settingsRepository,
            trackResolver: trackResolver,
            offsetRepository: offsetRepository,
            onPlay: (spiff, duration, position) =>
                emit(PlayerPlay(spiff, duration: duration, position: position)),
            onPause: (spiff, duration, position) => emit(
                PlayerPause(spiff, duration: duration, position: position)),
            onStop: (spiff) => emit(PlayerStop(spiff)),
            onIndexChange: (spiff, playing) =>
                emit(PlayerIndexChange(spiff, playing)),
            onPositionChange: (spiff, duration, position, playing) => emit(
                PlayerPositionChange(spiff,
                    duration: duration, position: position, playing: playing)),
            onDurationChange: (spiff, duration, position, playing) => emit(
                PlayerDurationChange(spiff,
                    duration: duration, position: position, playing: playing)),
            onTrackChange: (spiff, index, {String? title}) =>
                emit(PlayerTrackChange(spiff, index, title: title)),
            onTrackEnd: (spiff, index, duration, position) => emit(
                PlayerTrackEnd(spiff, index,
                    duration: duration, position: position)))
        .whenComplete(() => emit(PlayerReady()));
  }

  void load(Spiff spiff) {
    _provider.load(spiff);
    emit(PlayerLoad(spiff));
  }

  void play() => _provider.play();

  void playIndex(int index) => _provider.playIndex(index);

  void pause() => _provider.pause();

  void stop() => _provider.stop();

  void seek(Duration position) => _provider.seek(position);

  void skipForward() => _provider.skipForward();

  void skipBackward() => _provider.skipBackward();

  void skipToIndex(int index) => _provider.skipToIndex(index);

  void skipToNext() => _provider.skipToNext();

  void skipToPrevious() => _provider.skipToPrevious();
}
