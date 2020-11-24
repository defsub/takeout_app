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
import 'package:takeout_app/main.dart';

import 'music.dart';

Widget header(String text) {
  return Container(
      child: Text(text,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 19)),
      padding: EdgeInsets.fromLTRB(0, 11, 0, 11));
}

Widget heading(String text) {
  return Container(
      child: Text(text,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 17)),
      padding: EdgeInsets.fromLTRB(5, 11, 0, 11));
}

void snackBar(String text) {
  snackBarStateSubject.add(SnackBarState(Text(text)));
}

void snackBarDownload({Release release, bool complete = false}) {
  String text;
  if (release != null) {
    if (complete) {
      text = 'Finished ${release.name}';
    } else {
      text = 'Downloading ${release.name}';
    }
    snackBar(text);
  }
}
//
// void okDialog(BuildContext context, String title, String text) {
//   showDialog(
//       context: context,
//       builder: (buildContext) => new AlertDialog(
//         title: Text(title),
//         content: Text(text),
//         actions: <Widget>[
//           OutlinedButton(
//             child: Text('Close'),
//             onPressed: () {
//               Navigator.pop(buildContext);
//             },
//           )
//         ],
//       ));
// }
