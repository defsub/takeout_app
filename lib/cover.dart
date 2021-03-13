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

dynamic radiusCover(String url, {double width, double height, BoxFit fit}) {
  if (url == null) {
    return null;
  }
  return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: cachedImage(url, width: width, height: height, fit: fit));
}

dynamic cachedImage(String url, {double width, double height, BoxFit fit}) {
  if (url == null) {
    return null;
  }
  return CachedNetworkImage(
    imageUrl: url,
    width: width,
    height: height,
    fit: fit,
    placeholder: (context, url) => Icon(Icons.image_outlined, size: 40),
    errorWidget: (context, url, error) =>
        Icon(Icons.broken_image_outlined, size: 40),
  );
}

dynamic tileCover(String url) {
  return url == null ? Icon(Icons.album_sharp, size: 40) : radiusCover(url);
}

dynamic artistBackground(ArtistView view) {
  return cachedImage(view.background,
      width: 1920, height: 1080, fit: BoxFit.fill);
}

dynamic releaseLargeCover(String url) {
  return _hero(cachedImage(url, width: 500, height: 500, fit: BoxFit.fill), url);
}

dynamic releaseSmallCover(String url) {
  return _hero(cachedImage(url, width: 250, height: 250, fit: BoxFit.fill), url);
}

dynamic spiffCover(String url) {
  return _hero(cachedImage(url, width: 250, height: 250, fit: BoxFit.fill), url);
}

dynamic gridCover(String url) {
  if (url == null) {
    return Icon(Icons.album_sharp, size: 40);
  }
  return _hero(cachedImage(url, width: 250, height: 250, fit: BoxFit.fill), url);
}

dynamic playerCover(String url) {
  return _hero(cachedImage(url, width: 250, height: 250, fit: BoxFit.fill), url);
}

dynamic _hero(dynamic cover, String tag) {
  return tag != null ? Hero(tag: tag, child: cover) : cover;
}

final _colorCache = Map<String, Color>();

Future<Color> getImageBackgroundColor(url) async {
  var color = _colorCache[url];
  if (color != null) {
    return color;
  }
  final paletteGenerator = await PaletteGenerator.fromImageProvider(
      CachedNetworkImageProvider(url));
  color = paletteGenerator?.darkVibrantColor?.color ??
      paletteGenerator?.darkMutedColor?.color;
  _colorCache[url] = color;
  return color;
}

// TODO move below to util, global or other

String year(String date) {
  var d = DateTime.parse(date);
  // year 1 is a Go zero value date
  return d.year == 1 ? '' : '${d.year}';
}
//
// bool isNullOrEmpty(String s) => s?.trim()?.isEmpty ?? true;
//
// bool isNotNullOrEmpty(String s) => s?.trim()?.isNotEmpty ?? false;
