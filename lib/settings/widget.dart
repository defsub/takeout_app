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
