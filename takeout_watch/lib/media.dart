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
import 'package:takeout_lib/art/cover.dart';
import 'package:takeout_lib/model.dart';

typedef MediaEntryCallback = void Function(BuildContext, MediaEntry);

class MediaPage extends StatelessWidget {
  final List<MediaEntry> entries;
  final MediaEntryCallback onTap;
  final MediaEntryCallback? onLongPress;

  const MediaPage(this.entries,
      {required this.onTap, this.onLongPress, super.key});

  @override
  Widget build(BuildContext context) {
    return MediaGrid(entries, onTap: onTap, onLongPress: onLongPress);
  }
}

class MediaGrid extends StatelessWidget {
  final List<MediaEntry> entries;
  final MediaEntryCallback onTap;
  final MediaEntryCallback? onLongPress;

  const MediaGrid(this.entries,
      {required this.onTap, this.onLongPress, super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return MediaGridTile(entries[index],
            onTap: onTap, onLongPress: onLongPress);
      },
    );
  }
}

class MediaGridTile extends StatelessWidget {
  final MediaEntry entry;
  final MediaEntryCallback onTap;
  final MediaEntryCallback? onLongPress;

  const MediaGridTile(this.entry,
      {required this.onTap, this.onLongPress, super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return GestureDetector(
        onTap: () => onTap(context, entry),
        onLongPress: () => onLongPress?.call(context, entry),
        child: GridTile(
            footer: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                child: GridTileBar(
                  backgroundColor: Colors.black26,
                  title: Center(
                      child:
                          Text(entry.album, overflow: TextOverflow.ellipsis)),
                  subtitle: Center(
                      child:
                          Text(entry.creator, overflow: TextOverflow.ellipsis)),
                )),
            child:
                circleCover(context, entry.image, radius: media.size.width) ??
                    const SizedBox.shrink()));
  }
}
