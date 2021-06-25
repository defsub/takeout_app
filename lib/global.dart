import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'schema.dart';
import 'artists.dart'; // TODO remove

const appName = 'Takeout';
const appVersion = '0.3.0';
const appSource = 'https://github.com/defsub/takeout_app';
const appHome = 'https://takeout.fm';

List<GlobalKey<NavigatorState>> navigatorKeys = [
  GlobalKey<NavigatorState>(),
  GlobalKey<NavigatorState>(),
  GlobalKey<NavigatorState>(),
  GlobalKey<NavigatorState>(),
  GlobalKey<NavigatorState>()
];

final bottomNavKey = new GlobalKey();

void navigate(int index) {
  BottomNavigationBar navBar = bottomNavKey.currentWidget;
  navBar.onTap(index);
}

Map<String, Artist> artistMap = {};

void loadArtistMap(List<Artist> artists) {
  artistMap.clear();
  artists.forEach((a) {
    artistMap[a.name] = a;
  });
}

void showPlayer() {
  navigate(4);
}

void showArtist(String name) async {
  Artist artist = artistMap[name];
  if (artist != null) {
    final route = MaterialPageRoute(builder: (context) => ArtistWidget(artist));
    Navigator.push(navigatorKeys[1].currentContext, route);
    await route.didPush();
    navigate(1);
  }
}

class SnackBarState {
  final Widget content;

  SnackBarState(this.content);
}

final snackBarStateSubject = PublishSubject<SnackBarState>();

void showSnackBar(String text) {
  snackBarStateSubject.add(SnackBarState(Text(text)));
}

Future<SharedPreferences> prefs = SharedPreferences.getInstance();

Future<String> prefsString(String key) async {
  return await prefs.then((p) async {
    await p.reload();
    return p.getString(key);
  });
}

void showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            child: Text("OK"),
              onPressed: () => Navigator.pop(ctx),
          )
        ],
      );
    },
  );
}

