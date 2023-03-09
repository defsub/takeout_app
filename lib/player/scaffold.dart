import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:takeout_app/art/scaffold.dart';

import 'player.dart';

class PlayerScaffold extends StatelessWidget {
  final Widget? body;

  PlayerScaffold({this.body});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<Player, PlayerState>(buildWhen: (context, state) {
      return state is PlayerLoaded || state is PlayerIndexChanged;
    }, builder: (context, state) {
      String? image;
      if (state is PlayerLoaded || state is PlayerIndexChanged) {
        image = state.currentTrack.image;
      }
      return scaffold(context, image: image, body: body);
    });
  }
}
