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
import 'package:takeout_watch/app/app.dart';
import 'package:takeout_watch/app/context.dart';
import 'package:takeout_watch/platform.dart';

import 'list.dart';

class AboutEntry {
  final String title;
  final List<String>? subtitle;

  AboutEntry(this.title, {this.subtitle});
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: FutureBuilder<Map<String, dynamic>>(
            future: deviceInfo(),
            builder: (context, snapshot) {
              final data = snapshot.data ?? {};
              //data.forEach((key, value) { print('$key => $value'); });
              final entries = [
                AboutEntry(context.strings.takeoutTitle, subtitle: [appVersion]),
                AboutEntry('Copyleft \u00a9 2023',
                    subtitle: ['The Takeout Authors']),
                if (data.isNotEmpty)
                  AboutEntry(context.strings.deviceInfo, subtitle: [
                    '${data["brand"]} ${data["model"]}',
                    'Android ${data["version"]["release"]}',
                    'API ${data["version"]["sdkInt"]}',
                    'Display ${data["displayMetrics"]["widthPx"]} x ${data["displayMetrics"]["heightPx"]}',
                    'Security ${data["version"]["securityPatch"]}',
                  ]),
              ];
              return RotaryList<AboutEntry>(entries, tileBuilder: aboutTile);
            }));
  }

  Widget aboutTile(BuildContext context, AboutEntry entry) {
    final subtitle = entry.subtitle;
    return ListTile(
      title: Center(child: Text(entry.title)),
      subtitle: subtitle != null
          ? Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.from(subtitle.map((e) => Text(e)))))
          : null,
    );
  }
}
