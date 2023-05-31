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

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:takeout_lib/cache/track.dart';
import 'package:takeout_lib/connectivity/connectivity.dart';
import 'package:takeout_lib/util.dart';
import 'package:takeout_watch/app/app.dart';
import 'package:takeout_watch/app/context.dart';
import 'package:takeout_watch/platform.dart';

import 'list.dart';

class AboutEntry {
  final String title;
  final String? subtitle;
  final void Function()? onTap;

  AboutEntry(this.title, {this.subtitle, this.onTap});
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<ConnectivityCubit>();
    context.watch<TrackCacheCubit>();
    return Scaffold(
        body: FutureBuilder<Map<String, dynamic>>(
            future: deviceInfo(),
            builder: (context, snapshot) {
              final data = snapshot.data ?? {};
              //data.forEach((key, value) { print('$key => $value'); });
              final entries = [
                AboutEntry(context.strings.takeoutTitle, subtitle: appVersion),
                AboutEntry('Copyleft \u00a9 2023',
                    subtitle: 'The Takeout Authors'),
                AboutEntry(context.strings.connectivityLabel,
                    subtitle: context.connectivity.state.type.name,
                    onTap: () => context.connectivity.check()),
                AboutEntry(
                  context.strings.downloadsLabel,
                  subtitle: downloadsSize(context),
                ),
                AboutEntry('Dart', subtitle: Platform.version),
                if (data.isNotEmpty)
                  AboutEntry(context.strings.deviceLabel,
                      subtitle: '${data["model"]} (${data["brand"]})'),
                if (data.isNotEmpty)
                  AboutEntry('Android ${data["version"]["release"]}',
                      subtitle: 'API ${data["version"]["sdkInt"]}'),
                if (data.isNotEmpty)
                  AboutEntry(context.strings.displayLabel,
                      subtitle:
                          '${data["displayMetrics"]["widthPx"]} x ${data["displayMetrics"]["heightPx"]}'),
                if (data.isNotEmpty)
                  AboutEntry('Security Patch',
                      subtitle: '${data["version"]["securityPatch"]}'),
              ];
              return RotaryList<AboutEntry>(entries, tileBuilder: aboutTile);
            }));
  }

  Widget aboutTile(BuildContext context, AboutEntry entry) {
    final subtitle = entry.subtitle;
    return ListTile(
      onTap: entry.onTap,
      title: Center(child: Text(entry.title)),
      subtitle: subtitle != null
          ? Center(child: Text(subtitle, textAlign: TextAlign.center))
          : null,
    );
  }

  String? downloadsSize(BuildContext context) {
    // caller watches state
    final size = context.trackCache.repository.cacheSize();
    return size > 0 ? storage(size) : null;
  }
}
