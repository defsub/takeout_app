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

import 'package:takeout_lib/api/model.dart';
import 'package:takeout_lib/client/repository.dart';

class ArtistRepository {
  final ArtistProvider _provider;

  ArtistRepository(
      {required ClientRepository clientRepository, ArtistProvider? provider})
      : _provider = provider ?? DefaultArtistProvider(clientRepository);

  Iterable<String> findByName(String query) {
    return _provider.findByName(query);
  }

  void reload() {
    _provider.reload();
  }
}

abstract class ArtistProvider {
  Iterable<String> findByName(String query);

  void reload();
}

class DefaultArtistProvider extends ArtistProvider {
  final ClientRepository clientRepository;
  final artists = <Artist>[];
  final names = <String>[];
  final genres = <String, List<Artist>>{};
  final countries = <String, List<Artist>>{};

  DefaultArtistProvider(this.clientRepository) {
    _load();
  }

  @override
  void reload() {
    _load(ttl: Duration.zero);
  }

  void _load({Duration? ttl}) {
    clientRepository.artists(ttl: ttl).then((view) {
      artists.clear();
      names.clear();
      genres.clear();
      countries.clear();
      for (var artist in view.artists) {
        artists.add(artist);
        names.add(artist.name);
        _updateMap(artist.genre, genres, artist);
        _updateMap(artist.country, countries, artist);
      }
    }).onError((error, stackTrace) {
      Future.delayed(const Duration(minutes: 3), () => _load());
    });
  }

  void _updateMap(String? key, Map<String, List<Artist>> map, Artist artist) {
    if (key != null) {
      if (map.containsKey(key) == false) {
        map[key] = <Artist>[];
      }
      map[key]?.add(artist);
    }
  }

  @override
  Iterable<String> findByName(String query) {
    final result = <String>[];
    query = query.toLowerCase();
    result.addAll(names.where((name) => name.toLowerCase().contains(query)));
    return result;
  }
}
