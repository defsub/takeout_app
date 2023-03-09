import 'package:flutter/material.dart';
import 'builder.dart';

Widget scaffold(BuildContext context, {String? image, Widget? body}) {
  return FutureBuilder<Color?>(
      future: image != null ? getImageBackgroundColor(context, image) : null,
      builder: (context, snapshot) {
        return Scaffold(backgroundColor: snapshot.data, body: body);
      });
}
