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
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import 'cover.dart';
import 'global.dart';
import 'player_task.dart';

// NOTE: Your entry point MUST be a top-level function.
void _audioPlayerTaskEntryPoint() async {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

class _PlayState {
  final QueueState queueState;
  final bool playing;

  _PlayState(this.queueState, this.playing);
}

final _backgroundColorSubject = BehaviorSubject<Color>();
StreamSubscription<MediaItem> _mediaItemSubscription;

class PlayerWidget extends StatelessWidget {
  static void doStart(Map<String, dynamic> params) async {
    await AudioService.start(
      params: params,
      backgroundTaskEntrypoint: _audioPlayerTaskEntryPoint,
      androidNotificationChannelName: 'Takeout',
      // Enable this if you want the Android service to exit the foreground state on pause.
      //androidStopForegroundOnPause: true,
      androidNotificationColor: 0xFF2196f3,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidEnableQueue: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mediaItemSubscription == null) {
      // change background color when mediaItem changes
      _mediaItemSubscription =
          AudioService.currentMediaItemStream.distinct().listen((item) {
        if (item == null) {
          return;
        }
        getImageBackgroundColor(mediaItem: item).then((color) {
          _backgroundColorSubject.add(color);
        });
      });
    }

    return StreamBuilder<Color>(
        stream: _backgroundColorSubject,
        builder: (context, snapshot) {
          final backgroundColor = snapshot?.data;
          return Scaffold(
              backgroundColor: backgroundColor,
              body: Center(
                child: StreamBuilder<bool>(
                  stream: AudioService.runningStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.active) {
                      // Don't show anything until we've ascertained whether or not the
                      // service is running, since we want to show a different UI in
                      // each case.
                      return SizedBox();
                    }
                    final running = snapshot.data ?? false;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!running) ...[
                          // UI to show when we're not running, i.e. a menu.
                          audioPlayerButton(),
                        ] else ...[
                          // UI to show when we're running, i.e. player state/controls.
                          StreamBuilder<_PlayState>(
                              stream: Rx.combineLatest2(
                                  _queueStateStream,
                                  AudioService.playbackStateStream
                                      .map((state) => state.playing)
                                      .distinct(),
                                  (a, b) => _PlayState(a, b)),
                              builder: (context, snapshot) {
                                final playing = snapshot.data?.playing;
                                final queueState = snapshot.data?.queueState;
                                final queue = queueState?.queue ?? [];
                                final mediaItem = queueState?.mediaItem;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (mediaItem != null)
                                      cover(mediaItem.artUri),
                                    if (mediaItem?.title != null)
                                      Container(
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(mediaItem?.title,
                                                    style: Theme.of(context).textTheme.headline6),
                                                if (mediaItem?.isLocalFile())
                                                  Container(
                                                      padding:
                                                          EdgeInsets.fromLTRB(
                                                              13, 0, 0, 0),
                                                      child: Icon(
                                                          Icons
                                                              .cloud_done_outlined,
                                                          size: 20))
                                              ]),
                                          padding:
                                              EdgeInsets.fromLTRB(0, 11, 0, 11)),
                                    if (mediaItem?.artist != null)
                                      OutlinedButton.icon(
                                          icon: Icon(Icons.people),
                                          onPressed: () =>
                                              _onArtist(mediaItem.artist),
                                          label: Text(mediaItem?.artist)),
                                    if (queue != null && queue.isNotEmpty)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.skip_previous),
                                            // iconSize: 64.0,
                                            onPressed: mediaItem == queue.first
                                                ? null
                                                : AudioService.skipToPrevious,
                                          ),
                                          if (playing)
                                            pauseButton()
                                          else
                                            playButton(),
                                          // stopButton(),
                                          IconButton(
                                            icon: Icon(Icons.skip_next),
                                            // iconSize: 64.0,
                                            onPressed: mediaItem == queue.last
                                                ? null
                                                : AudioService.skipToNext,
                                          ),
                                        ],
                                      ),
                                  ],
                                );
                              }),
                          // A seek bar.
                          StreamBuilder<MediaState>(
                            stream: _mediaStateStream,
                            builder: (context, snapshot) {
                              final mediaState = snapshot.data;
                              return SeekBar(
                                duration: mediaState?.mediaItem?.duration ??
                                    Duration.zero,
                                position: mediaState?.position ?? Duration.zero,
                                onChangeEnd: (newPosition) {
                                  AudioService.seekTo(newPosition);
                                },
                              );
                            },
                          ),
                          Container(
                              child: IconButton(
                                  icon: Icon(Icons.arrow_drop_up, size: 32),
                                  onPressed: () => showQueue(context))),
                        ],
                      ],
                    );
                  },
                ),
              ));
        });
  }

  void _onArtist(String artist) {
    showArtist(artist);
  }

  /// A stream reporting the combined state of the current media item and its
  /// current position.
  Stream<MediaState> get _mediaStateStream =>
      Rx.combineLatest2<MediaItem, Duration, MediaState>(
          AudioService.currentMediaItemStream,
          AudioService.positionStream,
          (mediaItem, position) => MediaState(mediaItem, position));

  /// A stream reporting the combined state of the current queue and the current
  /// media item within that queue.
  Stream<QueueState> get _queueStateStream =>
      Rx.combineLatest2<List<MediaItem>, MediaItem, QueueState>(
          AudioService.queueStream,
          AudioService.currentMediaItemStream,
          (queue, mediaItem) => QueueState(queue, mediaItem));

  RaisedButton audioPlayerButton() => startButton(
        'AudioPlayer',
        () {
          PlayerWidget.doStart({}); //fixme
        },
      );

  RaisedButton startButton(String label, VoidCallback onPressed) =>
      RaisedButton(
        child: Text(label),
        onPressed: onPressed,
      );

  IconButton playButton() => IconButton(
        icon: Icon(Icons.play_arrow),
        iconSize: 64.0,
        onPressed: AudioService.play,
      );

  IconButton pauseButton() => IconButton(
        icon: Icon(Icons.pause),
        iconSize: 64.0,
        onPressed: AudioService.pause,
      );

  IconButton stopButton() => IconButton(
        icon: Icon(Icons.stop),
        iconSize: 64.0,
        onPressed: AudioService.stop,
      );

  void showQueue(BuildContext context) {
    showBottomSheet<void>(
        context: context,
        builder: (context) {
          return StreamBuilder<QueueState>(
              stream: _queueStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                if (state == null) {
                  return Text('');
                }
                final List<MediaItem> mediaItems = state.queue ?? [];
                if (mediaItems != null) {
                  return Container(
                      height: MediaQuery.of(context).size.height * 0.66,
                      child: Column(children: [
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        Expanded(
                            child: SingleChildScrollView(
                                child: Column(children: [
                          ...mediaItems.map((t) => ListTile(
                              leading: mediaItemCover(t),
                              selected: t == state.mediaItem,
                              onTap: () {
                                AudioService.playMediaItem(t);
                              },
                              subtitle: Text('${t.artist} \u2022 ${t.album}'),
                              title: Text(t.title)))
                        ])))
                      ]));
                }
                return Text('');
              });
        });
  }
}

class QueueState {
  final List<MediaItem> queue;
  final MediaItem mediaItem;

  QueueState(this.queue, this.mediaItem);
}

class MediaState {
  final MediaItem mediaItem;
  final Duration position;

  MediaState(this.mediaItem, this.position);
}

class SeekBar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final ValueChanged<Duration> onChanged;
  final ValueChanged<Duration> onChangeEnd;

  SeekBar({
    @required this.duration,
    @required this.position,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  _SeekBarState createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double _dragValue;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final value = min(_dragValue ?? widget.position?.inMilliseconds?.toDouble(),
        widget.duration.inMilliseconds.toDouble());
    if (_dragValue != null && !_dragging) {
      _dragValue = null;
    }
    return Stack(
      children: [
        Slider(
          min: 0.0,
          max: widget.duration.inMilliseconds.toDouble(),
          value: value,
          onChanged: (value) {
            if (!_dragging) {
              _dragging = true;
            }
            setState(() {
              _dragValue = value;
            });
            if (widget.onChanged != null) {
              widget.onChanged(Duration(milliseconds: value.round()));
            }
          },
          onChangeEnd: (value) {
            if (widget.onChangeEnd != null) {
              widget.onChangeEnd(Duration(milliseconds: value.round()));
            }
            _dragging = false;
          },
        ),
        Positioned(
          right: 16.0,
          bottom: 0.0,
          child: Text(
              RegExp(r'((^0*[1-9]\d*:)?\d{2}:\d{2})\.\d+$')
                      .firstMatch("$_remaining")
                      ?.group(1) ??
                  '$_remaining',
              style: Theme.of(context).textTheme.caption),
        ),
      ],
    );
  }

  Duration get _remaining => widget.duration - widget.position;
}
