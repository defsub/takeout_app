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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:takeout_lib/art/cover.dart';
import 'package:takeout_lib/empty.dart';
import 'package:takeout_lib/player/player.dart';
import 'package:takeout_lib/player/scaffold.dart';
import 'package:takeout_watch/app/context.dart';
import 'package:takeout_watch/queue.dart';

import 'button.dart';

void showPlayer(BuildContext context) {
  Scaffold.of(context).showBottomSheet<void>((context) {
    return const PlayerPage();
  });
}

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    print('player build');
    return PlayerScaffold(
      body: (backgroundColor) {
        return Stack(fit: StackFit.expand, children: [
          Center(child: playerImage(context)),
          Positioned.fill(child: playerProgress(context)),
          Positioned.fill(
              child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                playerTitle(context),
                playerArtist(context),
                const SizedBox(height: 24),
                playerControls(context),
              ]))),
          const Align(alignment: Alignment.bottomCenter, child: PlayerQueue())
        ]);
      },
    );
  }

  Widget playerImage(BuildContext context) {
    String? image;
    final media = MediaQuery.of(context);
    final width = media.size.width - 26; // progress lineWidth: 13
    return BlocBuilder<Player, PlayerState>(
        buildWhen: (_, state) => state.currentTrack?.image != image,
        builder: (context, state) {
          print('playerImage state is ${state.runtimeType.toString()}');
          if (state.currentTrack?.image != image) {
            image = state.currentTrack?.image;
            final cover = image;
            if (cover != null) {
              return GridTile(
                  child: circleCover(
                        context,
                        cover,
                        radius: width / 2,
                        height: width,
                      ) ??
                      const EmptyWidget());
            }
          }
          return const EmptyWidget();
        });
  }

  Widget playerProgress(BuildContext context) {
    final media = MediaQuery.of(context);
    return BlocBuilder<Player, PlayerState>(
        buildWhen: (_, state) => state is PlayerPositionChange,
        builder: (context, state) {
          if (state is PlayerPositionChange) {
            return CircularPercentIndicator(
              radius: media.size.width / 2,
              lineWidth: 13.0,
              animation: true,
              animateFromLastPercent: true,
              percent: state.progress,
              circularStrokeCap: CircularStrokeCap.round,
              progressColor: Colors.blueAccent,
              backgroundColor: Colors.grey.shade800,
            );
          }
          return const EmptyWidget();
        });
  }

  Widget playerTitle(BuildContext context) {
    String? title;
    return BlocBuilder<Player, PlayerState>(
        buildWhen: (_, state) => state.currentTrack?.title != title,
        builder: (context, state) {
          print('playerTitle state is ${state.runtimeType.toString()}');
          if (state.currentTrack?.title != title) {
            final currentTrack = state.currentTrack;
            if (currentTrack == null) {
              return const EmptyWidget();
            }
            title = currentTrack.title;
            return Text(currentTrack.title,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium);
          }
          return const EmptyWidget();
        });
  }

  Widget playerArtist(BuildContext context) {
    String? artist;
    return BlocBuilder<Player, PlayerState>(
        buildWhen: (_, state) => state.currentTrack?.creator != artist,
        builder: (context, state) {
          print('playerArtist state is ${state.runtimeType.toString()}');
          if (state.currentTrack?.creator != artist) {
            final currentTrack = state.currentTrack;
            if (currentTrack == null) {
              return const EmptyWidget();
            }
            artist = currentTrack.creator;
            return Text(currentTrack.creator,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall);
          }
          return const EmptyWidget();
        });
  }

  Widget playerControls(BuildContext context) {
    return BlocBuilder<Player, PlayerState>(
        buildWhen: (_, state) => state is PlayerPositionState,
        builder: (context, state) {
          print('playerControls state is ${state.runtimeType.toString()}');
          if (state.spiff.isEmpty) {
            return const EmptyWidget();
          }
          if (state is PlayerPositionState) {
            return _controlButtons(context, state);
          }
          return const EmptyWidget();
        });
  }

  Widget _controlButtons(BuildContext context, PlayerPositionState state) {
    final player = context.player;
    final isPodcast = state.spiff.isPodcast();
    final isStream = state.spiff.isStream();
    final playing = state.playing;
    final buffering = state.buffering;
    const iconSize = 24.0;
    return Container(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (!isStream)
              CircleButton(
                icon: const Icon(Icons.skip_previous),
                iconSize: iconSize,
                onPressed: state.currentIndex == 0
                    ? null
                    : () => player.skipToPrevious(),
              ),
            if (isPodcast)
              CircleButton(
                icon: const Icon(Icons.replay_10_outlined),
                iconSize: iconSize,
                onPressed: () => player.skipBackward(),
              ),
            if (buffering)
              const CircularProgressIndicator()
            else if (playing)
              CircleButton(
                icon: const Icon(Icons.pause),
                iconSize: 36,
                onPressed: () => player.pause(),
              )
            else
              CircleButton(
                icon: const Icon(Icons.play_arrow),
                iconSize: 36,
                onPressed: () => player.play(),
              ),
            if (isPodcast)
              CircleButton(
                iconSize: iconSize,
                icon: const Icon(Icons.forward_30_outlined),
                onPressed: () => player.skipForward(),
              ),
            if (!isStream)
              CircleButton(
                iconSize: iconSize,
                icon: const Icon(Icons.skip_next),
                onPressed: state.currentIndex == state.lastIndex
                    ? null
                    : () => player.skipToNext(),
              ),
          ],
        ));
  }
}

class AmbientPlayer extends StatelessWidget {
  const AmbientPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    String? title, artist;
    buildWhen(PlayerState state) =>
        state.currentTrack?.title != title ||
        state.currentTrack?.creator != artist;
    return Scaffold(
        body: BlocBuilder<Player, PlayerState>(
            buildWhen: (_, state) => buildWhen(state),
            builder: (context, state) {
              if (buildWhen(state)) {
                final currentTrack = state.currentTrack;
                print('curr is $currentTrack');
                final t = currentTrack?.title ?? 'Takeout';
                final a = currentTrack?.creator ?? '';
                print('title is $t, artist is $a');
                return Center(
                    child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                        title: Center(
                            child: Text(t, overflow: TextOverflow.ellipsis)),
                        subtitle: Center(
                            child: Text(a, overflow: TextOverflow.ellipsis))),
                  ],
                ));
              }
              return const EmptyWidget();
            }));
  }
}
