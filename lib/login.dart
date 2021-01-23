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

import 'client.dart';
import 'global.dart';

class LoginWidget extends StatefulWidget {
  final Function _onSuccess;

  LoginWidget(this._onSuccess);

  @override
  State<StatefulWidget> createState() => new _LoginState(_onSuccess);
}

class _LoginState extends State<LoginWidget> {
  final Function _onSuccess;

  _LoginState(this._onSuccess);

  TextEditingController _hostText = TextEditingController();
  TextEditingController _userText = TextEditingController();
  TextEditingController _passwordText = TextEditingController();

  static const prefsHost = 'login_host';
  static const prefsUser = 'login_user';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final host = await prefsString(prefsHost);
    final user = await prefsString(prefsUser);
    setState(() {
      _hostText.text = host;
      _userText.text = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(appName),
        ),
        body: Padding(
            padding: EdgeInsets.all(10),
            child: ListView(
              children: <Widget>[
                Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.all(10),
                    child: Text(
                      'Host',
                      style:
                          TextStyle(fontWeight: FontWeight.w500, fontSize: 30),
                    )),
                Container(
                  padding: EdgeInsets.all(10),
                  child: TextFormField(
                    controller: _hostText,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Host',
                        helperText: appHome),
                  ),
                ),
                Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.all(10),
                    child: Text(
                      'Login',
                      style:
                          TextStyle(fontWeight: FontWeight.w500, fontSize: 30),
                    )),
                Container(
                  padding: EdgeInsets.all(10),
                  child: TextFormField(
                    controller: _userText,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'User',
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
                      labelText: 'Password',
                    ),
                  ),
                ),
                Container(
                    height: 70,
                    padding: EdgeInsets.all(10),
                    child: OutlinedButton(
                      child: Text('Login'),
                      onPressed: () async {
                        print(_hostText.text);
                        print(_userText.text);
                        print(_passwordText.text);
                        final client = Client();
                        await client.setEndpoint(_hostText.text);
                        client
                            .login(_userText.text, _passwordText.text)
                            .then((result) {
                          if (result['Status'] == 200) {
                            prefs.then((p) {
                              p.setString(prefsHost, _hostText.text);
                              p.setString(prefsUser, _userText.text);
                            });
                            _onSuccess();
                          }
                        });
                      },
                    )),
              ],
            )));
  }
}
