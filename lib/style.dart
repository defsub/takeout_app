
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

const IconsDownload = Icons.cloud_download_outlined;
const IconsDownloadDone = Icons.cloud_done_outlined;
const IconsCached = Icons.download_done_outlined;

Widget header(String text) {
  return Container(
      child: Text(text.toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      padding: EdgeInsets.fromLTRB(0, 11, 0, 11));
}

Widget heading(String text) {
  return SizedBox(
      width: double.infinity,
      child: Container(
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text(text.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15))),
          padding: EdgeInsets.fromLTRB(11, 22, 0, 11)));
}

Widget headingButton(String text, VoidCallback onPressed) {
  return SizedBox(
      width: double.infinity,
      child: TextButton(
        child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(text.toUpperCase(),
                    textAlign: TextAlign.justify,
                    style:
                        TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                Icon(Icons.chevron_right)
              ],
            )),
        onPressed: onPressed,
      ));
}

Widget smallHeading(BuildContext context, String text) {
  return SizedBox(
      width: double.infinity,
      child: Container(
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text(text, style: Theme.of(context).textTheme.caption)),
          // style: TextStyle(fontWeight: FontWeight.w300, fontSize: 12))),
          padding: EdgeInsets.fromLTRB(17, 11, 0, 11)));
}

Color overlayIconColor(BuildContext context) {
  // Theme.of(context).colorScheme.onBackground
  return Colors.white;
}