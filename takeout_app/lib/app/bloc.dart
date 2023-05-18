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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nested/nested.dart';
import 'package:takeout_lib/cache/prune.dart';
import 'package:takeout_lib/context/bloc.dart';
import 'package:takeout_lib/player/player.dart';
import 'package:takeout_lib/spiff/model.dart';

import 'app.dart';
import 'context.dart';

class AppBloc extends TakeoutBloc {
  @override
  List<SingleChildWidget> blocs() {
    return List<SingleChildWidget>.from(super.blocs())
      ..add(BlocProvider(create: (_) => AppCubit()));
  }

  @override
  void onNowPlayingChange(BuildContext context, Spiff spiff, bool autoplay) {
    super.onNowPlayingChange(context, spiff, autoplay);
    // include in history and show the player
    context.history.add(spiff: Spiff.cleanup(spiff));
    context.app.showPlayer();
  }
}

mixin AppBlocState {
  StreamSubscription<PlayerProgressChange>? _considerPlayedSubscription;

  void appInitState(BuildContext context) {
    if (context.tokens.state.tokens.authenticated) {
      // restore authenticated state
      context.app.authenticated();
    }

    // keep track of position changes and update history once a track is considered played
    // TODO consider a more efficient way to do this
    //
    // TODO: not happy with this code. currently this will send history/activity event again
    // when you resume playing something that is more than 1/2 way through.

    // _considerPlayedSubscription = context.player.stream
    //     .where((state) => state is PlayerProgressChange)
    //     .cast<PlayerProgressChange>()
    //     .distinct((a, b) =>
    //         a.currentTrack?.etag == b.currentTrack?.etag &&
    //         a.considerPlayed == b.considerPlayed)
    //     .listen((state) {
    //   if (state.considerPlayed) {
    //     final currentTrack = state.currentTrack;
    //     if (currentTrack != null) {
    //       print('consider played ${state.currentTrack?.title}');
    //       // add track to history & activity
    //       context.history.add(track: currentTrack);
    //       context.clientRepository.updateActivity(
    //           Events(trackEvents: [TrackEvent.now(currentTrack.etag)]));
    //     }
    //   }
    // });

    // prune incomplete/partial downloads
    pruneCache(context.spiffCache.repository, context.trackCache.repository);
  }

  void appDispose() {
    _considerPlayedSubscription?.cancel();
  }
}
