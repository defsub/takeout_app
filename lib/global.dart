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
import 'package:shared_preferences/shared_preferences.dart';

const textSeparator = ' \u2022 ';

final homeKey = GlobalKey<NavigatorState>();
final artistsKey = GlobalKey<NavigatorState>();
final historyKey = GlobalKey<NavigatorState>();
final radioKey = GlobalKey<NavigatorState>();
final playerKey = GlobalKey<NavigatorState>();
final searchKey = GlobalKey<NavigatorState>();

final bottomNavKey = new GlobalKey();

// class SnackBarState {
//   final Widget content;
//
//   SnackBarState(this.content);
// }
//
// final snackBarStateSubject = PublishSubject<SnackBarState>();
//
// void showSnackBar(String text) {
//   snackBarStateSubject.add(SnackBarState(Text(text)));
// }

Future<SharedPreferences> prefs = SharedPreferences.getInstance();

Future<String?> prefsString(String key) async {
  return await prefs.then((p) async {
    await p.reload();
    var val = p.getString(key);
    if (val == 'null') {
      // TODO why did this happen?
      val = null;
    }
    return val;
  });
}

void showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: Text(MaterialLocalizations.of(context).alertDialogLabel),
        content: Text(message),
        actions: [
          TextButton(
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
            onPressed: () => Navigator.pop(ctx),
          )
        ],
      );
    },
  );
}

NavigatorObserver heroController() {
  return HeroController(
      createRectTween: (begin, end) =>
          MaterialRectArcTween(begin: begin, end: end));
}

typedef VoidContextCallback = void Function(BuildContext);
