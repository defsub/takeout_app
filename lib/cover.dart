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

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import 'music.dart';
import 'spiff.dart';

String releaseCoverUrl(Release release, {int size = 250}) {
  if (release.artwork && release.frontArtwork) {
    return 'https://coverartarchive.org/release/${release.reid}/front-$size';
  } else if (release.artwork &&
      release.otherArtwork != null &&
      release.otherArtwork.length > 0) {
    return 'https://coverartarchive.org/release/${release.reid}/${release.otherArtwork}-$size';
  }
  return null;
}

String trackCoverUrl(Track track, {int size = 250}) {
  if (track.artwork && track.frontArtwork) {
    return 'https://coverartarchive.org/release/${track.reid}/front-$size';
  } else if (track.artwork &&
      track.otherArtwork != null &&
      track.otherArtwork.length > 0) {
    return 'https://coverartarchive.org/release/${track.reid}/${track.otherArtwork}-$size';
  }
  return null;
}

dynamic _cover(String url) {
  return url == null
      ? Icon(Icons.album_sharp, size: 40)
      : ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: CachedNetworkImage(
            imageUrl: url,
            placeholder: (context, url) => Icon(Icons.image_outlined, size: 40),
            errorWidget: (context, url, error) =>
                Icon(Icons.broken_image_outlined, size: 40),
          ));
}

dynamic cover(String url) {
  return _cover(url);
}

dynamic releaseCover(Release release) {
  return _cover(releaseCoverUrl(release));
}

dynamic trackCover(Track track) {
  return _cover(trackCoverUrl(track));
}

dynamic mediaItemCover(MediaItem mediaItem) {
  return _cover(mediaItem.artUri);
}

String year(Release release) {
  var d = DateTime.parse(release.date);
  return '${d.year}';
}

Future<Color> getCoverBackgroundColor(
    {Release release, MediaItem mediaItem, Spiff spiff}) async {
  if (release == null && mediaItem == null && spiff == null) {
    return null;
  }
  final PaletteGenerator paletteGenerator =
      await PaletteGenerator.fromImageProvider(
          CachedNetworkImageProvider(release != null
              ? releaseCoverUrl(release)
              : spiff != null
                  ? spiff.playlist.image
                  : mediaItem.artUri));
  return paletteGenerator?.darkVibrantColor?.color ??
      paletteGenerator?.darkMutedColor?.color;
}
