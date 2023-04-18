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

import 'builder.dart';

typedef ScaffoldBodyFunc = Widget? Function(Color?);

Widget scaffold(BuildContext context, {String? image, ScaffoldBodyFunc? body}) {
  return FutureBuilder<Color?>(
      future: image != null ? getImageBackgroundColor(context, image) : null,
      builder: (context, snapshot) {
        return Scaffold(
            backgroundColor: snapshot.data, body: body?.call(snapshot.data));
      });
}
