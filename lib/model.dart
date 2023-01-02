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

class Reference {
  final String reference;
  final MediaType type;

  Reference(this.reference, this.type);
}

abstract class Referencable {
  Reference get reference;
}

abstract class Media {
  String get creator;

  String get album;

  String get title;

  String get image;

  String get etag;
}

class MediaAdapter implements Media {
  final String creator;
  final String album;
  final String title;
  final String image;
  final String etag;

  MediaAdapter(
      {required this.creator,
      required this.album,
      required this.title,
      required this.image,
      required this.etag});
}

abstract class MediaAlbum {
  String get creator;

  String get album;

  String get image;

  int get year;
}

abstract class MediaTrack implements Media {
  int get year;

  int get size;

  int get number;

  int get disc;

  // 1999-07-27T00:00:00Z
  // 2022-02-03T09:21:26-08:00
  String get date;
}
