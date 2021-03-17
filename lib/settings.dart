// Copyright (C) 2021 The Takeout Authors.
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
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:rxdart/rxdart.dart';

const settingAllowStreaming = 'allow_streaming';
const settingAllowDownload = 'allow_download';
const settingAllowArtistArtwork = 'allow_artist_artwork';
const settingHomeGridType = 'home_grid_type';

enum GridType { mix, downloads, released, added }

GridType settingsGridType(String key, GridType def) {
  final v = Settings.getValue(key, def.index);
  return GridType.values[v];
}

final settingsChangeSubject = PublishSubject<String>();

class AppSettings extends StatefulWidget {
  @override
  _AppSettingsState createState() => _AppSettingsState();
}

class _AppSettingsState extends State<AppSettings> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: SettingsScreen(
        title: 'Settings',
        children: [
          SettingsGroup(title: 'Home Settings', children: <Widget>[
            DropDownSettingsTile<int>(
              settingKey: settingHomeGridType,
              title: 'Home Grid',
              subtitle: 'What to show on the home page',
              values: <int, String>{
                GridType.mix.index: 'Downloads + Added',
                GridType.downloads.index: 'Downloads Only',
                GridType.added.index: 'Recently Added',
                GridType.released.index: 'Recently Released',
              },
              selected:
                  Settings.getValue(settingHomeGridType, GridType.mix.index),
              onChange: (value) {
                settingsChangeSubject.add(settingHomeGridType);
              },
            ),
          ]),
          SettingsGroup(
            title: 'Network Settings',
            children: <Widget>[
              SwitchSettingsTile(
                settingKey: settingAllowStreaming,
                title: 'Streaming',
                subtitle: 'Allow streaming on mobile networks',
                enabledLabel: 'Enabled',
                disabledLabel: 'Disabled',
                leading: Icon(Icons.cloud_outlined),
                onChange: (value) {
                  debugPrint('streaming: $value');
                },
              ),
              SwitchSettingsTile(
                settingKey: settingAllowDownload,
                title: 'Downloads',
                subtitle: 'Allow downloads on mobile networks',
                enabledLabel: 'Enabled',
                disabledLabel: 'Disabled',
                leading: Icon(Icons.cloud_download_outlined),
                onChange: (value) {
                  debugPrint('downloads: $value');
                },
              ),
              SwitchSettingsTile(
                settingKey: settingAllowArtistArtwork,
                title: 'Artist Artwork',
                subtitle: 'Allow artist artwork on mobile networks',
                enabledLabel: 'Enabled',
                disabledLabel: 'Disabled',
                leading: Icon(Icons.image_outlined),
                onChange: (value) {
                  debugPrint('artwork: $value');
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
