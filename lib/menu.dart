// Copyright (C) 2020 The Takeout Authors.
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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'style.dart';

typedef MenuCallback = void Function(BuildContext);

class PopupItem {
  Icon? icon;
  String? title;
  MenuCallback? onSelected;
  bool _divider = false;

  bool get isDivider => _divider;

  PopupItem.divider() {
    _divider = true;
  }

  PopupItem(this.icon, this.title, this.onSelected);

  PopupItem.music(BuildContext context, MenuCallback onSelected) :
      this(Icon(Icons.music_note), AppLocalizations.of(context)!.musicSwitchLabel, onSelected);

  PopupItem.video(BuildContext context, MenuCallback onSelected) :
        this(Icon(Icons.movie), AppLocalizations.of(context)!.videoSwitchLabel, onSelected);

  PopupItem.podcasts(BuildContext context, MenuCallback onSelected) :
        this(Icon(Icons.podcasts), AppLocalizations.of(context)!.podcastsSwitchLabel, onSelected);

  PopupItem.downloads(BuildContext context, MenuCallback onSelected)
      : this(Icon(IconsDownload),
            AppLocalizations.of(context)!.downloadsLabel, onSelected);

  PopupItem.download(BuildContext context, MenuCallback onSelected)
      : this(Icon(IconsDownload),
            AppLocalizations.of(context)!.downloadsLabel, onSelected);

  PopupItem.play(BuildContext context, MenuCallback onSelected)
      : this(Icon(Icons.play_arrow), AppLocalizations.of(context)!.playLabel,
            onSelected);

  PopupItem.refresh(BuildContext context, MenuCallback onSelected)
      : this(Icon(Icons.refresh_sharp),
            AppLocalizations.of(context)!.refreshLabel, onSelected);

  PopupItem.logout(BuildContext context, MenuCallback onSelected)
      : this(Icon(Icons.logout), AppLocalizations.of(context)!.logoutLabel,
            onSelected);

  PopupItem.link(BuildContext context, String text, MenuCallback onSelected)
      : this(Icon(Icons.link), text, onSelected);

  PopupItem.about(BuildContext context, MenuCallback onSelected)
      : this(Icon(Icons.info_outline), AppLocalizations.of(context)!.aboutLabel,
            onSelected);

  PopupItem.settings(BuildContext context, MenuCallback onSelected)
      : this(Icon(Icons.settings), AppLocalizations.of(context)!.settingsLabel,
            onSelected);

  PopupItem.delete(BuildContext context, String text, MenuCallback onSelected)
      : this(Icon(Icons.delete), text, onSelected);

  PopupItem.singles(BuildContext context, MenuCallback onSelected)
      : this(Icon(Icons.audiotrack_outlined),
            AppLocalizations.of(context)!.singlesLabel, onSelected);

  PopupItem.popular(BuildContext context, MenuCallback onSelected)
      : this(Icon(Icons.audiotrack_outlined),
            AppLocalizations.of(context)!.popularLabel, onSelected);

  PopupItem.genre(BuildContext context, String genre, MenuCallback onSelected)
      : this(Icon(Icons.people), genre, onSelected);

  PopupItem.area(BuildContext context, String area, MenuCallback onSelected)
      : this(Icon(Icons.location_pin), area, onSelected);

  PopupItem.artist(BuildContext context, String name, MenuCallback onSelected)
      : this(Icon(Icons.people), name, onSelected);

  PopupItem.shuffle(BuildContext context, MenuCallback onSelected)
      : this(Icon(Icons.shuffle_sharp),
            AppLocalizations.of(context)!.shuffleLabel, onSelected);

  PopupItem.radio(BuildContext context, MenuCallback onSelected)
      : this(Icon(Icons.radio), AppLocalizations.of(context)!.radioLabel,
            onSelected);

  PopupItem.playlist(BuildContext context, MenuCallback onSelected)
      : this(Icon(Icons.playlist_play_sharp),
      AppLocalizations.of(context)!.recentlyPlayed, onSelected);
}

Widget popupMenu(BuildContext context, List<PopupItem> items) {
  return PopupMenuButton<dynamic>(
      icon: Icon(Icons.more_vert),
      itemBuilder: (_) {
        List<PopupMenuEntry<dynamic>> entries = [];
        for (var index = 0; index < items.length; index++) {
          if (items[index].isDivider) {
            entries.add(PopupMenuDivider());
          } else {
            entries.add(PopupMenuItem<int>(
                value: index,
                child: ListTile(
                    leading: items[index].icon,
                    title: Text(items[index].title ?? 'no title'),
                    minLeadingWidth: 10)));
          }
        }
        return entries;
      },
      onSelected: (index) {
        items[index].onSelected!(context);
      });
}
