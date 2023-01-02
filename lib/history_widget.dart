// Copyright (C) 2022 The Takeout Authors.
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
import 'package:takeout_app/cover.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'history.dart';
import 'widget.dart';
import 'style.dart';
import 'global.dart';
import 'menu.dart';

class HistoryListWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    History.instance; // TODO start load
    final builder = (_) => StreamBuilder<History>(
        stream: History.stream,
        builder: (context, snapshot) {
          final history = snapshot.data;
          final spiffs = history != null ? history.spiffs : [];
          spiffs.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          return Scaffold(
              appBar: AppBar(
                title: header(AppLocalizations.of(context)!.historyLabel),
                actions: [
                  popupMenu(context, [
                    PopupItem.delete(
                        context,
                        AppLocalizations.of(context)!.deleteAll,
                        (ctx) => _onDelete(ctx)),
                  ])
                ],
              ),
              body: Column(children: [
                Expanded(
                    child: ListView.builder(
                        itemCount: spiffs.length,
                        itemBuilder: (buildContext, index) {
                          return SpiffHistoryWidget(spiffs[index]);
                        }))
              ]));
        });
    return Navigator(
        key: historyKey,
        initialRoute: '/',
        observers: [heroController()],
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute(builder: builder, settings: settings);
        });
  }

  void _onDelete(BuildContext context) {
    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.confirmDelete),
            content: Text(AppLocalizations.of(context)!.deleteHistory),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child:
                    Text(MaterialLocalizations.of(context).cancelButtonLabel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _onDeleteConfirmed();
                },
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          );
        });
  }

  void _onDeleteConfirmed() async {
    final history = await History.instance;
    history.delete();
  }
}

class SpiffHistoryWidget extends StatelessWidget {
  final SpiffHistory spiffHistory;
  final String _cover;

  SpiffHistoryWidget(this.spiffHistory) : _cover = spiffHistory.spiff.cover;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(spiffHistory.spiff.playlist.creator ?? 'no creator',
          overflow: TextOverflow.ellipsis),
      RelativeDateWidget(spiffHistory.dateTime)
    ]);

    return ListTile(
        selected: false,
        isThreeLine: true,
        onTap: () => _onTap(context, spiffHistory),
        onLongPress: null,
        leading: tileCover(_cover),
        trailing: null,
        subtitle: subtitle,
        title: Text(spiffHistory.spiff.playlist.title,
            overflow: TextOverflow.ellipsis));
  }

  void _onTap(BuildContext context, SpiffHistory spiffHistory) {
    Navigator.push(
        context,
        MaterialPageRoute(
            // TODO consider making spiff refreshable. Need original reference or uri.
            builder: (_) => SpiffWidget(spiff: spiffHistory.spiff)));
  }
}
