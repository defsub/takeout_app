// Copyright (C) 2021 The Takeout Authors.
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

enum MediaType { music, video, podcast, stream }

class MediaTypes {
  static final _types = {
    MediaType.music.name: MediaType.music,
    MediaType.video.name: MediaType.video,
    MediaType.podcast.name: MediaType.podcast,
    MediaType.stream.name: MediaType.stream,
  };

  static MediaType from(String name) {
    return _types[name]!;
  }
}

abstract class MediaAlbum {
  String get creator;
  String get album;
  String get image;
  int get year;
}

abstract class MediaTrack {
  String get creator;
  String get album;
  String get image;
  int get year;

  String get title;
  int get size;

  int get number;
  int get disc;

  // 1999-07-27T00:00:00Z
  // 2022-02-03T09:21:26-08:00
  String get date;
}
