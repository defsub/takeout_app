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
import 'package:logging/logging.dart';
import 'package:takeout_app/app/context.dart';

import 'style.dart';

const settingAllowStreaming = 'allow_streaming';
const settingAllowDownload = 'allow_download';
const settingAllowArtistArtwork = 'allow_artist_artwork';
const settingHomeGridType = 'home_grid_type';
const settingLiveMode = 'live_mode';

enum LiveType { none, share, follow }

enum GridType { mix, downloads, released, added }

class AppSettings extends StatelessWidget {
  static final log = Logger('AppSettingsState');

  @override
  Widget build(BuildContext context) {
    return Container(
      child: SettingsScreen(
        title: context.strings.settingsLabel,
        children: [
          SettingsGroup(
              title: context.strings.homeSettingsTitle,
              children: <Widget>[
                DropDownSettingsTile<int>(
                  settingKey: settingHomeGridType,
                  title: context.strings.settingHomeGridTitle,
                  subtitle:
                      context.strings.settingHomeGridSubtitle,
                  values: <int, String>{
                    GridType.mix.index:
                        context.strings.settingHomeGridMix,
                    GridType.downloads.index:
                        context.strings.settingHomeGridDownloads,
                    GridType.added.index:
                        context.strings.settingHomeGridAdded,
                    GridType.released.index:
                        context.strings.settingHomeGridReleased,
                  },
                  selected: Settings.getValue<int>(settingHomeGridType,
                          defaultValue: GridType.mix.index) ??
                      GridType.mix.index,
                  onChange: (value) {
                    // settingsChangeSubject.add(settingHomeGridType);
                  },
                ),
              ]),
          SettingsGroup(
            title: context.strings.networkSettingsTitle,
            children: <Widget>[
              SwitchSettingsTile(
                settingKey: settingAllowStreaming,
                title: context.strings.settingStreamingTitle,
                subtitle:
                    context.strings.settingStreamingSubtitle,
                enabledLabel: context.strings.settingEnabled,
                disabledLabel: context.strings.settingDisabled,
                leading: Icon(Icons.cloud_outlined),
                onChange: (value) {
                  log.finer('streaming: $value');
                },
              ),
              SwitchSettingsTile(
                settingKey: settingAllowDownload,
                title: context.strings.settingDownloadsTitle,
                subtitle:
                    context.strings.settingDownloadsSubtitle,
                enabledLabel: context.strings.settingEnabled,
                disabledLabel: context.strings.settingDisabled,
                leading: Icon(IconsDownload),
                onChange: (value) {
                  log.finer('downloads: $value');
                },
              ),
              SwitchSettingsTile(
                settingKey: settingAllowArtistArtwork,
                title: context.strings.settingArtworkTitle,
                subtitle: context.strings.settingArtworkSubtitle,
                enabledLabel: context.strings.settingEnabled,
                disabledLabel: context.strings.settingDisabled,
                leading: Icon(Icons.image_outlined),
                onChange: (value) {
                  log.finer('artwork: $value');
                },
              ),
            ],
          ),
          SettingsGroup(
              title: context.strings.settingLive,
              children: <Widget>[
                DropDownSettingsTile<int>(
                    title: context.strings.settingLiveMode,
                    settingKey: settingLiveMode,
                    values: <int, String>{
                      LiveType.none.index:
                          context.strings.settingLiveNone,
                      LiveType.share.index:
                          context.strings.settingLiveShare,
                      LiveType.follow.index:
                          context.strings.settingLiveFollow,
                    },
                    selected: Settings.getValue<int>(settingLiveMode,
                            defaultValue: LiveType.none.index) ??
                        LiveType.none.index,
                    onChange: (value) {
                      // settingsChangeSubject.add(settingLiveMode);
                    })
              ]),
        ],
      ),
    );
  }
}
