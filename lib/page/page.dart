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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:takeout_app/app/context.dart';
import 'package:takeout_app/client/client.dart';
import 'package:takeout_app/empty.dart';
import 'package:takeout_app/global.dart';

abstract class ClientPageBuilder<T> {
  WidgetBuilder builder(BuildContext context, {T? value}) {
    final builder = (context) => BlocProvider(
        create: (context) => ClientCubit(context.clientRepository),
        child: BlocBuilder<ClientCubit, ClientState>(builder: (context, state) {
          if (state is ClientReady) {
            if (value != null) {
              return page(context, value);
            } else {
              load(context);
            }
          } else if (state is ClientLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ClientResult<T>) {
            return page(context, state.result);
          } else if (state is ClientError) {
            return errorPage(context, state);
          }
          return EmptyWidget();
        }));
    return builder;
  }

  Widget page(BuildContext context, T state);

  Widget errorPage(BuildContext context, ClientError error) {
    return Center(
        child: TextButton(
            child: Text('Try Again (${error.error})'),
            onPressed: () => reloadPage(context)));
  }

  Future<void> reloadPage(BuildContext context) async {
    reload(context);
  }

  void load(BuildContext context, {Duration? ttl});

  void reload(BuildContext context) {
    load(context, ttl: Duration.zero);
  }
}

abstract class ClientPage<T> extends StatelessWidget with ClientPageBuilder<T> {
  final T? value;

  ClientPage({super.key, this.value});

  @override
  Widget build(BuildContext context) {
    return builder(context, value: value)(context);
  }
}

abstract class NavigatorClientPage<T> extends ClientPage<T> {
  NavigatorClientPage({super.key, super.value});

  @override
  Widget build(BuildContext context) {
    return Navigator(
        key: key,
        initialRoute: '/',
        observers: [heroController()],
        onGenerateRoute: (RouteSettings settings) {
          return MaterialPageRoute(
              builder: builder(context, value: value), settings: settings);
        });
  }
}
