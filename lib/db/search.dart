import 'package:takeout_app/client/repository.dart';
import 'package:takeout_app/db/artist.dart';

class Search {
  final ClientRepository clientRepository;
  final ArtistRepository _artistRepository;

  Search({required this.clientRepository, ArtistRepository? artistRepository})
      : _artistRepository = artistRepository ??
            ArtistRepository(clientRepository: clientRepository);

  Iterable<String> findArtistsByName(String query) {
    return _artistRepository.findByName(query);
  }
}
