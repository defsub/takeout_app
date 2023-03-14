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

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:rxdart/rxdart.dart';
import 'package:logging/logging.dart';
import 'package:octo_image/octo_image.dart';

import 'package:takeout_app/app/context.dart';
import 'package:takeout_app/client/repository.dart';
import 'package:takeout_app/util.dart';
import 'artwork.dart';

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

  Widget _cachedImage(BuildContext context, Artwork artwork) {
    if (ARTWORK_ERRORS.contains(artwork.url)) {
      // TODO not needed due to pick?
      return errorIcon;
    }
    urlStream.add(artwork.url);
    final imageProvider = _imageProvider(context, artwork.url);
    //CachedNetworkImage.logLevel = CacheManagerLogLevel.verbose;
    final image = OctoImage(
        image: imageProvider,
        width: artwork.width,
        height: artwork.height,
        fit: artwork.fit,
        placeholderBuilder: (_) => artwork.placeholder ?? placeholder,
        errorBuilder: (context, error, stack) {
          log.warning(error);
          ARTWORK_ERRORS.add(imageProvider.url);
          if (imageProvider.url == primary?.url && secondary != null) {
            // primary failed, forget it and use secondary
            _artwork = secondary!;
            return _cachedImage(context, secondary!);
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

  Widget build(BuildContext context) {
    final a = _artwork;
    if (a == null) {
      return placeholder;
    }
    return isNullOrEmpty(a.url)
        ? a.placeholder ?? placeholder
        : _cachedImage(context, a);
  }

  Future<Color?> getBackgroundColor(BuildContext context) async {
    final imageProvider = _provider;
    if (imageProvider == null) {
      return null;
    }
    return _backgroundColor(context, imageProvider);
  }
}


// redo of DefaultCacheManager to use the takeout client
class _CoverCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'libCachedImageData'; // same as DefaultCacheManager

  // static final _CoverCacheManager _instance = _CoverCacheManager._();
  static _CoverCacheManager? _instance;

  factory _CoverCacheManager(BuildContext context) {
    if (_instance == null) {
      final clientRepository = context.clientRepository;
      _instance = _CoverCacheManager._(clientRepository);
    }
    return _instance!;
  }

  _CoverCacheManager._(ClientRepository clientRepository)
      : super(Config(key,
      fileService: HttpFileService(httpClient: clientRepository.client)));
}

// TODO consider putting this provider and cache in the context; fullUrl
CachedNetworkImageProvider _imageProvider(BuildContext context, String url) {
  return CachedNetworkImageProvider(fullUrl(context, url), cacheManager: _CoverCacheManager(context));
}

String fullUrl(BuildContext context, String url) {
  final endpoint = context.settings.state.endpoint;
  if (url.startsWith('/img/')) {
    return '$endpoint$url';
  }
  return url;
}

final _colorCache = Map<String, Color>();

Future<Color> getImageBackgroundColor(BuildContext context, String url) async {
  var color = _colorCache[url];
  if (color != null) {
    return color;
  }
  final provider = _imageProvider(context, url);
  color = await _backgroundColor(context, provider);
  _colorCache[url] = color;
  return color;
}

Future<Color> _backgroundColor(BuildContext context, ImageProvider imageProvider) async {
  final paletteGenerator =
      await PaletteGenerator.fromImageProvider(imageProvider);
  final brightness = MediaQuery.of(context).platformBrightness;
  if (brightness == Brightness.dark) {
    return paletteGenerator.darkVibrantColor?.color ??
        paletteGenerator.darkMutedColor?.color ??
        Theme.of(context).colorScheme.background;
  } else {
    return paletteGenerator.lightVibrantColor?.color ??
        paletteGenerator.lightMutedColor?.color ??
        Theme.of(context).colorScheme.background;
  }
}