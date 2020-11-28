import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import 'music.dart';
import 'artists.dart'; // TOOD remove

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
  artists.forEach((a) {
    artistMap[a.name] = a;
  });
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

void showDownloadSnackBar({Release release, bool isComplete = false}) {
  String text;
  if (release != null) {
    if (isComplete) {
      text = 'Finished ${release.name}';
    } else {
      text = 'Downloading ${release.name}';
    }
    showSnackBar(text);
  }
}
