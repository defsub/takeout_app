import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:takeout_app/app/context.dart';
import 'package:takeout_app/client/client.dart';
import 'package:takeout_app/global.dart';

abstract class ClientPageBuilder<T> {
  WidgetBuilder builder(BuildContext context, {T? value}) {
    final builder = (_) => BlocConsumer<ClientCubit, ClientState>(
        bloc: ClientCubit(context.clientRepository),
        listenWhen: (context, state) => false,
        listener: (context, state) {},
        buildWhen: (context, state) => true,
        builder: (context, state) {
          print('got state $state');
          if (state is ClientReady) {
            if (value != null) {
              return page(context, value);
            } else {
              load(context);
            }
          } else if (state is ClientLoading) {
            return Center(child: CircularProgressIndicator());
          } else if (state is ClientResult<T>) {
            return page(context, state.result);
          } else if (state is ClientError) {
            return errorPage(context, state);
          }
          return SizedBox.shrink();
        });
    return builder;
  }

  Widget page(BuildContext context, T state);

  Widget errorPage(BuildContext context, ClientError error) {
    return Center(
        child: TextButton(
            child: Text('Try Again (${error.error})'),
            onPressed: () => refreshPage(context)));
  }

  Future<void> refreshPage(BuildContext context) async {
    reload(context);
  }

  void load(BuildContext context, {Duration? ttl});

  void reload(BuildContext context) {
    load(context, ttl: Duration.zero);
  }
}

abstract class ClientPage<T> extends StatelessWidget with ClientPageBuilder<T> {
  final T? value;

  ClientPage({this.value});

  @override
  Widget build(BuildContext context) {
    return builder(context, value: value)(context);
  }
}

abstract class NavigatorClientPage<T> extends ClientPage<T> {
  final Key key;

  NavigatorClientPage(this.key, {T? super.value});

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
