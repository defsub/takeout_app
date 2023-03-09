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
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:takeout_app/app/context.dart';

import 'package:takeout_app/page/page.dart';

class LoginWidget extends ClientPage<bool> {
  final TextEditingController _hostText = TextEditingController();
  final TextEditingController _userText = TextEditingController();
  final TextEditingController _passwordText = TextEditingController();

  LoginWidget() : super(value: false);

  @override
  void load(BuildContext context, {Duration? ttl}) {
    final host = _hostText.text.trim();
    if (host.isNotEmpty) {
      context.settings.host = host;
    }

    // TODO assume host is emitted into settings repo for login below

    final user = _userText.text.trim();
    final password = _passwordText.text.trim();
    if (user.isNotEmpty && password.isNotEmpty) {
      context.client.login(user, password);
    }
  }

  @override
  Widget page(BuildContext context, bool success) {
    if (success) {
      context.app.authenticated();
      return SizedBox.shrink();
    }

    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.takeoutTitle),
        ),
        body: Padding(
            padding: EdgeInsets.all(10),
            child: ListView(
              children: <Widget>[
                Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.all(10),
                    child: Text(
                      AppLocalizations.of(context)!.hostLabel,
                      style:
                          TextStyle(fontWeight: FontWeight.w500, fontSize: 30),
                    )),
                Container(
                  padding: EdgeInsets.all(10),
                  child: TextFormField(
                    controller: _hostText,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: AppLocalizations.of(context)!.hostLabel,
                    ),
                  ),
                ),
                Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.all(10),
                    child: Text(
                      AppLocalizations.of(context)!.loginLabel,
                      style:
                          TextStyle(fontWeight: FontWeight.w500, fontSize: 30),
                    )),
                Container(
                  padding: EdgeInsets.all(10),
                  child: TextFormField(
                    controller: _userText,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: AppLocalizations.of(context)!.userLabel,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(10),
                  child: TextFormField(
                    obscureText: true,
                    controller: _passwordText,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: AppLocalizations.of(context)!.passwordLabel,
                    ),
                  ),
                ),
                Container(
                    height: 70,
                    padding: EdgeInsets.all(10),
                    child: OutlinedButton(
                      child: Text(AppLocalizations.of(context)!.loginLabel),
                      onPressed: () {
                        refreshPage(context);
                      },
                    )),
              ],
            )));
  }
}
