import 'package:flutter/material.dart';

import 'package:takeout_app/spiff/widget.dart';

void push(BuildContext context, {required WidgetBuilder builder}) {
  Navigator.push(context, MaterialPageRoute(builder: builder));
}

void pushSpiff(BuildContext context, FetchSpiff fetch) {
  push(context, builder: (_) => SpiffWidget(fetch: fetch));
}
