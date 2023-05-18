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
import 'package:takeout_lib/art/scaffold.dart';

import 'player.dart';

class PlayerScaffold extends StatelessWidget {
  final ScaffoldBodyFunc? body;
  final Widget? drawer;
  final Widget? bottomSheet;

  const PlayerScaffold({super.key, this.body, this.drawer, this.bottomSheet});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<Player, PlayerState>(buildWhen: (context, state) {
      return state is PlayerLoad || state is PlayerIndexChange;
    }, builder: (context, state) {
      String? image;
      if (state is PlayerLoad || state is PlayerIndexChange) {
        image = state.currentTrack?.image;
      }
      return scaffold(
        context,
        image: image,
        body: body,
        drawer: drawer,
        bottomSheet: bottomSheet,
      );
    });
  }
}
