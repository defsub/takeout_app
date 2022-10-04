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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:rxdart/rxdart.dart';
import 'package:logging/logging.dart';
import 'package:octo_image/octo_image.dart';
import 'util.dart';
import 'client.dart';

const coverAspectRatio = 1.0;
const coverGridWidth = 250.0;
const coverGridHeight = 250.0;

const posterAspectRatio = 0.6667;
const posterGridWidth = 166.75;
const posterGridHeight = 250.0;

const seriesAspectRatio = 1.0;
const seriesGridWidth = 250.0;
const seriesGridHeight = 250.0;

class Artwork {
  static late String endpoint;

  final String _url;
  final double? width, height, aspectRatio;
  final BoxFit? fit;
  final BorderRadius? borderRadius;
  final Icon? placeholder;

  String get url {
    if (_url.startsWith('/img/')) {
      return '$endpoint$_url';
    }
    return _url;
  }

  Artwork(this._url, this.width, this.height, this.fit,
      {this.aspectRatio = 1.0, this.borderRadius, this.placeholder});

  factory Artwork.artist(String url) =>
      Artwork(url, 1000, 1000, BoxFit.fitHeight,
          placeholder: const Icon(Icons.people));

  factory Artwork.cover(String url) =>
      Artwork(url, coverGridWidth, coverGridHeight, BoxFit.fitHeight,
          placeholder: const Icon(Icons.album));

  factory Artwork.tileCover(String url) => Artwork(url, null, null, null,
      borderRadius: BorderRadius.circular(4),
      placeholder: const Icon(Icons.album));

  factory Artwork.tilePoster(String url) => Artwork(url, null, null, null,
      borderRadius: BorderRadius.circular(4),
      placeholder: const Icon(Icons.movie));

  factory Artwork.background(String url) =>
      Artwork(url, 1920, 1080, BoxFit.cover);

  factory Artwork.coverGrid(String url) =>
      Artwork(url, coverGridWidth, coverGridHeight, BoxFit.fill,
          aspectRatio: coverAspectRatio, placeholder: const Icon(Icons.album));

  factory Artwork.posterGrid(String url) =>
      Artwork(url, posterGridWidth, posterGridHeight, BoxFit.fill,
          aspectRatio: posterAspectRatio, placeholder: const Icon(Icons.movie));

  factory Artwork.seriesGrid(String url) =>
      Artwork(url, posterGridWidth, posterGridHeight, BoxFit.fill,
          aspectRatio: seriesAspectRatio,
          placeholder: const Icon(Icons.podcasts));

  String get tag => url;
}

class ArtworkBuilder {
  static final log = Logger('ArtworkBuilder');

  final Artwork? primary;
  final Artwork? secondary;
  final Icon placeholder;
  final Icon errorIcon;
  final urlStream = BehaviorSubject<String?>();
  final bool hero;
  Artwork? _artwork;
  ImageProvider? _provider;

  static final ARTWORK_ERRORS = ExpiringSet<String>(Duration(hours: 1));

  static Artwork? _pick(Artwork? primary, Artwork? secondary) {
    if (primary != null) {
      return ARTWORK_ERRORS.contains(primary.url) ? secondary : primary;
    }
    return secondary;
  }

  ArtworkBuilder(this.primary,
      {this.secondary,
      this.placeholder = const Icon(Icons.image_outlined, size: 40),
      this.errorIcon = const Icon(Icons.broken_image_outlined, size: 40),
      this.hero = false})
      : _artwork = _pick(primary, secondary);

  factory ArtworkBuilder.artist(String? artistUrl, String? coverUrl) =>
      ArtworkBuilder(artistUrl != null ? Artwork.artist(artistUrl) : null,
          secondary: coverUrl != null ? Artwork.cover(coverUrl) : null);

  Widget _cachedImage(Artwork artwork) {
    if (ARTWORK_ERRORS.contains(artwork.url)) {
      // TODO not needed due to pick?
      return errorIcon;
    }
    urlStream.add(artwork.url);
    final imageProvider = _imageProvider(artwork.url);
    //CachedNetworkImage.logLevel = CacheManagerLogLevel.verbose;
    final image = OctoImage(
        image: imageProvider,
        width: artwork.width,
        height: artwork.height,
        fit: artwork.fit,
        placeholderBuilder: (context) => artwork.placeholder ?? placeholder,
        errorBuilder: (context, error, stack) {
          log.warning(error);
          ARTWORK_ERRORS.add(imageProvider.url);
          if (imageProvider.url == primary?.url && secondary != null) {
            // primary failed, forget it and use secondary
            _artwork = secondary!;
            return _cachedImage(secondary!);
          }
          urlStream.add(null);
          return errorIcon;
        });
    _provider = imageProvider;
    return artwork.borderRadius != null
        ? ClipRRect(
            borderRadius: artwork.borderRadius,
            child: _hero(image, artwork.tag))
        : _hero(image, artwork.tag);
  }

  Widget _hero(Widget image, String tag) {
    return hero ? Hero(tag: tag, child: image) : image;
  }

  String? get url => _artwork?.url ?? null;

  Widget build() {
    final a = _artwork;
    if (a == null) {
      return placeholder;
    }
    return isNullOrEmpty(a.url)
        ? a.placeholder ?? placeholder
        : _cachedImage(a);
  }

  Future<Color?> getBackgroundColor(BuildContext context) async {
    final imageProvider = _provider;
    if (imageProvider == null) {
      return null;
    }
    final paletteGenerator =
        await PaletteGenerator.fromImageProvider(imageProvider);
    final brightness = MediaQuery.of(context).platformBrightness;
    if (brightness == Brightness.dark) {
      return paletteGenerator.darkVibrantColor?.color ??
          paletteGenerator.darkMutedColor?.color ??
          Theme.of(context).backgroundColor;
    } else {
      return paletteGenerator.lightVibrantColor?.color ??
          paletteGenerator.lightMutedColor?.color ??
          Theme.of(context).backgroundColor;
    }
  }
}

Widget? tileCover(String url) {
  return ArtworkBuilder(Artwork.tileCover(url)).build();
}

Widget? tilePoster(String url) {
  return ArtworkBuilder(Artwork.tilePoster(url)).build();
}

Widget releaseSmallCover(String url) {
  return ArtworkBuilder(Artwork.cover(url), hero: true).build();
}

Widget spiffCover(String url) {
  return ArtworkBuilder(Artwork.cover(url), hero: true).build();
}

Widget gridCover(String url) {
  return ArtworkBuilder(Artwork.coverGrid(url), hero: true).build();
}

Widget gridPoster(String url) {
  return ArtworkBuilder(Artwork.posterGrid(url), hero: true).build();
}

Widget playerCover(String url) {
  return ArtworkBuilder(Artwork.cover(url), hero: true).build();
}

final _colorCache = Map<String, Color>();

Future<Color> getImageBackgroundColor(BuildContext context, String url) async {
  var color = _colorCache[url];
  if (color != null) {
    return color;
  }
  final paletteGenerator =
      await PaletteGenerator.fromImageProvider(_imageProvider(url));
  final brightness = MediaQuery.of(context).platformBrightness;
  if (brightness == Brightness.dark) {
    color = paletteGenerator.darkVibrantColor?.color ??
        paletteGenerator.darkMutedColor?.color ??
        Theme.of(context).backgroundColor;
  } else {
    color = paletteGenerator.lightVibrantColor?.color ??
        paletteGenerator.lightMutedColor?.color ??
        Theme.of(context).backgroundColor;
  }
  _colorCache[url] = color;
  return color;
}

CachedNetworkImageProvider _imageProvider(String url) {
  return CachedNetworkImageProvider(url, cacheManager: _CoverCacheManager());
}

// redo of DefaultCacheManager to use the takeout client
class _CoverCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'libCachedImageData'; // same as DefaultCacheManager

  static final _CoverCacheManager _instance = _CoverCacheManager._();

  factory _CoverCacheManager() {
    return _instance;
  }

  _CoverCacheManager._()
      : super(Config(key,
            fileService: HttpFileService(httpClient: Client.client)));
}
