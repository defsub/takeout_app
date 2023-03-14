import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:takeout_app/app/context.dart';
import 'model.dart';
import 'settings.dart';

class SettingsWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, Settings>(builder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: Text(context.strings.settingsLabel)),
        body: Column(
          children: [
            _switchTile(
                Icons.cloud_outlined, context.strings.settingStreamingTitle,
                context.strings.settingStreamingSubtitle,
                state.allowMobileStreaming, (value) {
              context.settings.allowStreaming = value;
            }),
            _switchTile(
                Icons.cloud_download_outlined, context.strings.settingDownloadsTitle,
                context.strings.settingDownloadsSubtitle,
                state.allowMobileDownload, (value) {
              context.settings.allowDownload = value;
            }),
            _switchTile(
                Icons.image_outlined, context.strings.settingArtworkTitle,
                context.strings.settingArtworkSubtitle,
                state.allowMobileArtistArtwork, (value) {
              context.settings.allowArtistArtwork = value;
            }),
          ],
        ),
      );
    });
  }

  Widget _switchTile(IconData icon, String title, String subtitle, bool value,
      ValueChanged<bool> onChanged) {
    return ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch(value: value, onChanged: onChanged));
  }
}
