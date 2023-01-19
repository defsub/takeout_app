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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:rxdart/rxdart.dart';
import 'package:logging/logging.dart';

import 'model.dart';
import 'style.dart';

const settingAllowStreaming = 'allow_streaming';
const settingAllowDownload = 'allow_download';
const settingAllowArtistArtwork = 'allow_artist_artwork';
const settingHomeGridType = 'home_grid_type';
const settingMediaType = 'home_media_type';
const settingLiveMode = 'live_mode';

MediaType settingsMediaType({MediaType type = MediaType.music}) {
  final v =
      Settings.getValue<int>(settingMediaType, defaultValue: type.index) ??
          type.index;
  return MediaType.values[v];
}

Future<void> changeMediaType(MediaType mediaType) async {
  settingsChangeSubject.add(settingMediaType);
  return Settings.setValue(settingMediaType, mediaType.index);
}

enum LiveType { none, share, follow }

enum GridType { mix, downloads, released, added }

GridType settingsGridType(String key, GridType def) {
  final v = Settings.getValue<int>(key, defaultValue: def.index) ?? def.index;
  return GridType.values[v];
}

LiveType settingsLiveType([LiveType def = LiveType.none]) {
  final v =
      Settings.getValue(settingLiveMode, defaultValue: def.index) ?? def.index;
  return LiveType.values[v];
}

final settingsChangeSubject =
    BehaviorSubject<String>.seeded(settingMediaType); // TODO seems ok

class AppSettings extends StatelessWidget {
  static final log = Logger('AppSettingsState');

  @override
  Widget build(BuildContext context) {
    return Container(
      child: SettingsScreen(
        title: AppLocalizations.of(context)!.settingsLabel,
        children: [
          SettingsGroup(
              title: AppLocalizations.of(context)!.homeSettingsTitle,
              children: <Widget>[
                DropDownSettingsTile<int>(
                  settingKey: settingHomeGridType,
                  title: AppLocalizations.of(context)!.settingHomeGridTitle,
                  subtitle:
                      AppLocalizations.of(context)!.settingHomeGridSubtitle,
                  values: <int, String>{
                    GridType.mix.index:
                        AppLocalizations.of(context)!.settingHomeGridMix,
                    GridType.downloads.index:
                        AppLocalizations.of(context)!.settingHomeGridDownloads,
                    GridType.added.index:
                        AppLocalizations.of(context)!.settingHomeGridAdded,
                    GridType.released.index:
                        AppLocalizations.of(context)!.settingHomeGridReleased,
                  },
                  selected: Settings.getValue<int>(settingHomeGridType,
                          defaultValue: GridType.mix.index) ??
                      GridType.mix.index,
                  onChange: (value) {
                    settingsChangeSubject.add(settingHomeGridType);
                  },
                ),
              ]),
          SettingsGroup(
            title: AppLocalizations.of(context)!.networkSettingsTitle,
            children: <Widget>[
              SwitchSettingsTile(
                settingKey: settingAllowStreaming,
                title: AppLocalizations.of(context)!.settingStreamingTitle,
                subtitle:
                    AppLocalizations.of(context)!.settingStreamingSubtitle,
                enabledLabel: AppLocalizations.of(context)!.settingEnabled,
                disabledLabel: AppLocalizations.of(context)!.settingDisabled,
                leading: Icon(Icons.cloud_outlined),
                onChange: (value) {
                  log.finer('streaming: $value');
                },
              ),
              SwitchSettingsTile(
                settingKey: settingAllowDownload,
                title: AppLocalizations.of(context)!.settingDownloadsTitle,
                subtitle:
                    AppLocalizations.of(context)!.settingDownloadsSubtitle,
                enabledLabel: AppLocalizations.of(context)!.settingEnabled,
                disabledLabel: AppLocalizations.of(context)!.settingDisabled,
                leading: Icon(IconsDownload),
                onChange: (value) {
                  log.finer('downloads: $value');
                },
              ),
              SwitchSettingsTile(
                settingKey: settingAllowArtistArtwork,
                title: AppLocalizations.of(context)!.settingArtworkTitle,
                subtitle: AppLocalizations.of(context)!.settingArtworkSubtitle,
                enabledLabel: AppLocalizations.of(context)!.settingEnabled,
                disabledLabel: AppLocalizations.of(context)!.settingDisabled,
                leading: Icon(Icons.image_outlined),
                onChange: (value) {
                  log.finer('artwork: $value');
                },
              ),
            ],
          ),
          SettingsGroup(
              title: AppLocalizations.of(context)!.settingLive,
              children: <Widget>[
                DropDownSettingsTile<int>(
                    title: AppLocalizations.of(context)!.settingLiveMode,
                    settingKey: settingLiveMode,
                    values: <int, String>{
                      LiveType.none.index:
                          AppLocalizations.of(context)!.settingLiveNone,
                      LiveType.share.index:
                          AppLocalizations.of(context)!.settingLiveShare,
                      LiveType.follow.index:
                          AppLocalizations.of(context)!.settingLiveFollow,
                    },
                    selected: Settings.getValue<int>(settingLiveMode,
                            defaultValue: LiveType.none.index) ??
                        LiveType.none.index,
                    onChange: (value) {
                      settingsChangeSubject.add(settingLiveMode);
                    })
              ]),
        ],
      ),
    );
  }
}
