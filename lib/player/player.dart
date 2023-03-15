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

import 'package:takeout_app/model.dart';
import 'package:takeout_app/player/provider.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/client/resolver.dart';
import 'package:takeout_app/tokens/repository.dart';
import 'package:takeout_app/settings/repository.dart';
import 'package:takeout_app/cache/offset_repository.dart';

abstract class PlayerState {
  final Spiff spiff;

  PlayerState(this.spiff);

  int get currentIndex => spiff.index >= 0 ? spiff.index : 0;

  int get lastIndex => spiff.length - 1;

  MediaTrack get currentTrack => spiff.playlist.tracks[currentIndex];
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

class PlayerLoaded extends PlayerState {
  PlayerLoaded(super.spiff);
}

class PlayerInit extends PlayerState {
  PlayerInit() : super(Spiff.empty());
}

class PlayerReady extends PlayerState {
  PlayerReady() : super(Spiff.empty());
}

class PlayerPlaying extends PlayerPositionState {
  PlayerPlaying(super.spiff,
      {required super.duration, required super.position, super.playing = true});
}

class PlayerPaused extends PlayerPositionState {
  PlayerPaused(super.spiff,
      {required super.duration,
      required super.position,
      super.playing = false});
}

class PlayerStopped extends PlayerState {
  PlayerStopped(super.spiff);
}

class PlayerIndexChanged extends PlayerState {
  final bool playing;

  PlayerIndexChanged(super.spiff, this.playing);
}

class PlayerPositionChanged extends PlayerPositionState {
  PlayerPositionChanged(super.spiff,
      {required super.duration,
      required super.position,
      required super.playing});
}

class PlayerDurationChanged extends PlayerPositionState {
  PlayerDurationChanged(super.spiff,
      {required super.duration,
      required super.position,
      required super.playing});
}

class PlayerTrackChanged extends PlayerState {
  final int index;
  final String? title;

  PlayerTrackChanged(super.spiff, this.index, {this.title});
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
            onPlay: (spiff, duration, position) => emit(
                PlayerPlaying(spiff, duration: duration, position: position)),
            onPause: (spiff, duration, position) => emit(
                PlayerPaused(spiff, duration: duration, position: position)),
            onStop: (spiff) => emit(PlayerStopped(spiff)),
            onIndexChange: (spiff, playing) =>
                emit(PlayerIndexChanged(spiff, playing)),
            onPositionChange: (spiff, duration, position, playing) => emit(
                PlayerPositionChanged(spiff,
                    duration: duration, position: position, playing: playing)),
            onDurationChange: (spiff, duration, position, playing) => emit(
                PlayerDurationChanged(spiff,
                    duration: duration, position: position, playing: playing)),
            onTrackChange: (spiff, index, {String? title}) =>
                emit(PlayerTrackChanged(spiff, index, title: title)))
        .whenComplete(() => emit(PlayerReady()));
  }

  void load(Spiff spiff) {
    _provider.load(spiff);
    emit(PlayerLoaded(spiff));
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
