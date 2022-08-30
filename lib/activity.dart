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

import 'client.dart';
import 'schema.dart';

class Activity {
  static Future<int> sendTrackEvent(String etag) async {
    final client = Client();
    final events = Events(trackEvents: [TrackEvent.now(etag)]);
    return client.updateActivity(events);
  }

  static Future<int> sendMovieEvent(String etag) async {
    final client = Client();
    final events = Events(movieEvents: [MovieEvent.now(etag)]);
    return client.updateActivity(events);
  }

  static Future<int> sendReleaseEvent(Release release) async {
    final client = Client();
    final events = Events(releaseEvents: [ReleaseEvent.now(release)]);
    return client.updateActivity(events);
  }
}
