import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:takeout_app/app/context.dart';

import 'package:takeout_app/connectivity/connectivity.dart';

import 'style.dart';

const PlayIcon = Icon(Icons.play_arrow, size: 32);

class PlayButton extends StatelessWidget {
  final VoidCallback? onPressed;

  PlayButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
        color: overlayIconColor(context), icon: PlayIcon, onPressed: onPressed);
  }
}

abstract class _ConnectivityButton extends StatelessWidget {
  final Icon icon;
  final VoidCallback? onPressed;

  _ConnectivityButton({required this.icon, this.onPressed});

  bool _allowed(BuildContext context, ConnectivityState state);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
        builder: (context, state) {
      return IconButton(
          // color: overlayIconColor(context),
          icon: icon,
          onPressed: _allowed(context, state) ? onPressed : null);
    });
  }
}

class DownloadButton extends _ConnectivityButton {
  DownloadButton({super.icon = const Icon(IconsDownload), super.onPressed});

  bool _allowed(BuildContext context, ConnectivityState state) {
    final settings = context.settings.state;
    final allow = settings.allowMobileDownload;
    return state.mobile ? allow : true;
  }
}

class StreamingButton extends _ConnectivityButton {
  StreamingButton({super.icon = PlayIcon, super.onPressed});

  bool _allowed(BuildContext context, ConnectivityState state) {
    final settings = context.settings.state;
    final allow = settings.allowMobileStreaming;
    return state.mobile ? allow : true;
  }
}
