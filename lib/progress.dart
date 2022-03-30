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

import 'package:takeout_app/cache.dart';

import 'cache.dart';
import 'client.dart';
import 'schema.dart';

class Progress {
  static Future sync({Client? client}) async {
    client = client ?? Client();
    return OffsetCache.merge(client);
  }

  static Future<Duration> position(String etag) async {
    final offset = await OffsetCache.get(etag);
    return offset?.position() ?? Duration.zero;
  }

  static void update(String etag, Duration position, Duration duration) {
    final client = Client();
    final offset = Offset.now(etag: etag, duration: duration, offset: position);
    // async update for local & remote
    OffsetCache.put(offset).then((_) => client.updateProgress(offset));
  }

  static void remove(String etag) {
    OffsetCache.remove(etag);
  }
}
