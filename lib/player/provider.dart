import 'package:takeout_app/client/resolver.dart';
import 'package:takeout_app/tokens/repository.dart';
import 'package:takeout_app/model.dart';
import 'package:takeout_app/settings/repository.dart';
import 'package:takeout_app/cache/offset_repository.dart';
import 'package:takeout_app/spiff/model.dart';

import 'handler.dart';

final DummyPlayerCallback = (_, __, ___) {};
final DummyStoppedCallback = (_) {};
final DummyTrackCallback = (_, __) {};
final DummyPositionCallback = (_, __, ___) {};
final DummyIndexCallback = (_, __) {};

typedef PlayerCallback = void Function(Spiff, Duration, Duration);
typedef IndexCallback = void Function(Spiff, bool);
typedef PositionCallback = void Function(Spiff, Duration, Duration);
typedef StoppedCallback = void Function(Spiff);
typedef TrackCallback = void Function(Spiff, MediaTrack);

abstract class PlayerProvider {
  Future init(
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
      TrackCallback? onMediaTrackChange});

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

  Future init(
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
      TrackCallback? onMediaTrackChange}) async {
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
        onMediaTrackChange: onMediaTrackChange ?? DummyTrackCallback);
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
