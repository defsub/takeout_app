import 'package:takeout_app/api/model.dart';
import 'package:takeout_app/client/repository.dart';

class ArtistRepository {
  final ArtistProvider _provider;

  ArtistRepository(
      {required ClientRepository clientRepository, ArtistProvider? provider})
      : _provider = provider ?? DefaultArtistProvider(clientRepository);

  Iterable<String> findByName(String query) {
    return _provider.findByName(query);
  }
}

abstract class ArtistProvider {
  Iterable<String> findByName(String query);
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

  void reload() {
    _load(ttl: Duration.zero);
  }

  void _load({Duration? ttl}) {
    clientRepository.artists(ttl: ttl).then((view) {
      artists.clear();
      names.clear();
      genres.clear();
      countries.clear();
      view.artists.forEach((artist) {
        artists.add(artist);
        names.add(artist.name);
        _updateMap(artist.genre, genres, artist);
        _updateMap(artist.country, countries, artist);
      });
    }).onError((error, stackTrace) {
      Future.delayed(Duration(minutes: 3), () => _load());
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

  Iterable<String> findByName(String query) {
    final result = <String>[];
    query = query.toLowerCase();
    result.addAll(names.where((name) => name.toLowerCase().contains(query)));
    return result;
  }
}
