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
  } else if (release.artwork && isNotNullOrEmpty(release.otherArtwork)) {
    return 'https://coverartarchive.org/release/${release.reid}/${release.otherArtwork}-$size';
  }
  return null;
}

String trackCoverUrl(Track track, {int size = 250}) {
  if (track.artwork && track.frontArtwork) {
    return 'https://coverartarchive.org/release/${track.reid}/front-$size';
  } else if (track.artwork && isNotNullOrEmpty(track.otherArtwork)) {
    return 'https://coverartarchive.org/release/${track.reid}/${track.otherArtwork}-$size';
  }
  return null;
}

dynamic _cover(String url) {
  return url == null ? Icon(Icons.album_sharp, size: 40) : artwork(url);
}

dynamic artwork(String url, {double width, double height}) {
  if (url == null) {
    return null;
  }
  return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
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

final _colorCache = Map<String, Color>();

Future<Color> getImageBackgroundColor(
    {Release release,
    MediaItem mediaItem,
    Spiff spiff,
    ArtistView artist}) async {
  if (release == null && mediaItem == null && spiff == null && artist == null) {
    return null;
  }
  final url = release != null
      ? releaseCoverUrl(release)
      : spiff != null
          ? spiff.playlist.image
          : mediaItem != null
              ? mediaItem.artUri
              : artist.image;
  var color = _colorCache[url];
  if (color != null) {
    print('cover color cached size ${_colorCache.length}');
    return color;
  }
  final paletteGenerator =
      await PaletteGenerator.fromImageProvider(CachedNetworkImageProvider(url));
  color = paletteGenerator?.darkVibrantColor?.color ??
      paletteGenerator?.darkMutedColor?.color;
  _colorCache[url] = color;
  return color;
}

// TODO move below to util, global or other

String year(String date) {
  var d = DateTime.parse(date);
  return '${d.year}';
}

bool isNullOrEmpty(String s) {
  return s?.trim()?.isEmpty ?? true;
}

bool isNotNullOrEmpty(String s) {
  return s?.trim()?.isNotEmpty ?? false;
}
