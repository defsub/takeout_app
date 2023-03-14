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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:takeout_app/app/context.dart';
import 'package:takeout_app/art/cover.dart';
import 'package:takeout_app/player/scaffold.dart';
import 'package:takeout_app/tiles.dart';

import 'player.dart';
import 'seekbar.dart';

class PlayerWidget extends StatelessWidget {
  PlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final expandedHeight = screen.height / 2;
    final builder = (_) => PlayerScaffold(
            body: CustomScrollView(slivers: [
          SliverAppBar(
              automaticallyImplyLeading: false,
              expandedHeight: expandedHeight,
              actions: [],
              flexibleSpace: FlexibleSpaceBar(
                  stretchModes: [
                    StretchMode.zoomBackground,
                    StretchMode.fadeTitle
                  ],
                  background: Stack(fit: StackFit.expand, children: [
                    playerImage(context),
                  ]))),
          SliverToBoxAdapter(
              child: Container(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(children: [
                    playerTitle(context),
                    playerArtist(context),
                    playerControls(context),
                    playerSeekBar(context),
                  ]))),
          SliverToBoxAdapter(child: playerQueue(context)),
        ]));
    return Navigator(
        key: key,
        initialRoute: '/',
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute(builder: builder, settings: settings);
        });
  }

  Widget playerImage(BuildContext context) {
    return BlocBuilder<Player, PlayerState>(buildWhen: (_, state) {
      return state is PlayerLoaded || state is PlayerIndexChanged;
    }, builder: (context, state) {
      if (state is PlayerLoaded || state is PlayerIndexChanged) {
        return playerCover(context, state.currentTrack.image);
      }
      return SizedBox.shrink();
    });
  }

  Widget playerTitle(BuildContext context) {
    return BlocBuilder<Player, PlayerState>(buildWhen: (_, state) {
      return state is PlayerLoaded ||
          state is PlayerIndexChanged ||
          state is PlayerTrackChanged;
    }, builder: (context, state) {
      if (state is PlayerLoaded ||
          state is PlayerIndexChanged ||
          state is PlayerTrackChanged) {
        return GestureDetector(
            onTap: () => _onArtist(context, state.currentTrack.creator),
            child: Text(state.currentTrack.title,
                style: Theme.of(context).textTheme.headlineSmall));
      }
      return SizedBox.shrink();
    });
  }

  Widget playerArtist(BuildContext context) {
    return BlocBuilder<Player, PlayerState>(buildWhen: (_, state) {
      return state is PlayerLoaded || state is PlayerIndexChanged;
    }, builder: (context, state) {
      if (state is PlayerLoaded || state is PlayerIndexChanged) {
        return Text(state.currentTrack.creator,
            style: Theme.of(context).textTheme.titleMedium!);
      }
      return SizedBox.shrink();
    });
  }

  Widget playerControls(BuildContext context) {
    return BlocBuilder<Player, PlayerState>(buildWhen: (_, state) {
      return state is PlayerPlaying ||
          state is PlayerPaused ||
          state is PlayerIndexChanged;
    }, builder: (context, state) {
      if (state is PlayerIndexChanged) {
        return _controlButtons(context, state, state.playing);
      } else if (state is PlayerPlaying) {
        return _controlButtons(context, state, true);
      } else if (state is PlayerPaused) {
        return _controlButtons(context, state, false);
      }
      return SizedBox.shrink();
    });
  }

  Widget playerSeekBar(BuildContext context) {
    final player = context.player;
    return BlocBuilder<Player, PlayerState>(
        bloc: player,
        buildWhen: (_, state) {
          return state is PlayerIndexChanged || state is PlayerPositionState;
        },
        builder: (context, state) {
          if (state is PlayerIndexChanged) {
            return _seekBar(player, Duration.zero, Duration.zero);
          } else if (state is PlayerPositionState) {
            return _seekBar(player, state.duration, state.position);
          }
          return SizedBox.shrink();
        });
  }

  Widget playerQueue(BuildContext context) {
    final player = context.player;
    return BlocBuilder<Player, PlayerState>(
        bloc: player,
        buildWhen: (_, state) {
          return state is PlayerLoaded || state is PlayerIndexChanged;
        },
        builder: (context, state) {
          if (state is PlayerLoaded) {
            return _trackList(context, player, state);
          } else if (state is PlayerIndexChanged) {
            return _trackList(context, player, state);
          }
          return SizedBox.shrink();
        });
  }

  Widget _seekBar(Player player, Duration duration, Duration position) {
    return Container(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 16),
        child: SeekBar(
            duration: duration,
            position: position,
            onChangeEnd: (newPosition) => player.seek(newPosition)));
  }

  Widget _controlButtons(
      BuildContext context, PlayerState state, bool playing) {
    final player = context.player;
    final isPodcast = state.spiff.isPodcast();
    final isStream = state.spiff.isStream();
    return Container(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isStream)
              IconButton(
                icon: Icon(Icons.skip_previous),
                onPressed: state.currentIndex == 0
                    ? null
                    : () => player.skipToPrevious(),
              ),
            if (isPodcast)
              IconButton(
                icon: Icon(Icons.replay_10_outlined),
                iconSize: 36,
                onPressed: () => player.skipBackward(),
              ),
            if (playing)
              IconButton(
                icon: Icon(Icons.pause),
                iconSize: 64.0,
                onPressed: () => player.pause(),
              )
            else
              IconButton(
                icon: Icon(Icons.play_arrow),
                iconSize: 64.0,
                onPressed: () => player.play(),
              ),
            // stopButton(),
            if (isPodcast)
              IconButton(
                iconSize: 36,
                icon: Icon(Icons.forward_30_outlined),
                onPressed: () => player.skipForward(),
              ),
            if (!isStream)
              IconButton(
                icon: Icon(Icons.skip_next),
                onPressed: state.currentIndex == state.lastIndex
                    ? null
                    : () => player.skipToNext(),
              ),
          ],
        ));
  }

  void _onArtist(BuildContext context, String artist) {
    context.showArtist(artist);
  }

  Widget _trackList(BuildContext context, Player player, PlayerState state) {
    final tracks = state.spiff.playlist.tracks;
    final sameArtwork = tracks.every((t) => t.image == tracks.first.image);
    return Container(
        child: Column(children: [
      ...List.generate(
          tracks.length,
          (index) => CoverTrackListTile.mediaTrack(context, tracks[index],
              showCover: !sameArtwork,
              trailing: _cachedIcon(tracks[index]),
              selected: index == state.currentIndex,
              // TODO
              onTap: () => player.playIndex(index),
              onLongPress: () {
                _onArtist(context, tracks[index].creator);
              }))
    ]));
  }

  Widget _cachedIcon(dynamic foo) {
    //TODO
    // if (track.) {
    //   return IconButton(icon: Icon(IconsCached), onPressed: () => {});
    // }
    return SizedBox.shrink();
  }
}