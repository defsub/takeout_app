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

typedef MenuCallback = void Function(BuildContext);

class PopupItem {
  Icon icon;
  String title;
  MenuCallback onSelected;
  bool _divider = false;

  bool get isDivider => _divider;

  PopupItem.divider() {
    _divider = true;
  }

  PopupItem(this.icon, this.title, this.onSelected);

  PopupItem.downloads(MenuCallback onSelected)
      : this(Icon(Icons.cloud_download_outlined), 'Downloads', onSelected);

  PopupItem.refresh(MenuCallback onSelected)
      : this(Icon(Icons.refresh_sharp), 'Refresh', onSelected);

  PopupItem.logout(MenuCallback onSelected)
      : this(Icon(Icons.logout), 'Logout', onSelected);

  PopupItem.link(String text, MenuCallback onSelected)
      : this(Icon(Icons.link), text, onSelected);

  PopupItem.about(MenuCallback onSelected)
      : this(Icon(Icons.info_outline), 'About', onSelected);

  PopupItem.settings(MenuCallback onSelected)
      : this(Icon(Icons.settings), 'Settings', onSelected);

  PopupItem.delete(String text, MenuCallback onSelected)
      : this(Icon(Icons.delete), text, onSelected);
}

Widget popupMenu(BuildContext context, List<PopupItem> items) {
  return PopupMenuButton<int>(
      icon: Icon(Icons.more_vert),
      itemBuilder: (_) {
        List<PopupMenuEntry<int>> entries = [];
        for (var index = 0; index < items.length; index++) {
          entries.add(items[index].isDivider
              ? PopupMenuDivider()
              : PopupMenuItem<int>(
                  value: index,
                  child: ListTile(
                      leading: items[index].icon,
                      title: Text(items[index].title),
                      minLeadingWidth: 10)));
        }
        return entries;
      },
      onSelected: (index) {
        items[index].onSelected(context);
      });
}
