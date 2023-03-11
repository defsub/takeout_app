import 'package:bloc/bloc.dart';

import 'package:takeout_app/client/repository.dart';
import 'package:takeout_app/media_type/media_type.dart';
import 'package:takeout_app/spiff/model.dart';
import 'package:takeout_app/patch.dart';

class PlaylistState {
  final Spiff spiff;

  PlaylistState(this.spiff);

  factory PlaylistState.initial() => PlaylistState(Spiff.empty());
}

class PlaylistLoaded extends PlaylistState {
  PlaylistLoaded(super.spiff);
}

class PlaylistChanged extends PlaylistState {
  PlaylistChanged(super.spiff);
}

class PlaylistUpdated extends PlaylistState {
  PlaylistUpdated(super.spiff);
}

class PlaylistCubit extends Cubit<PlaylistState> {
  final ClientRepository clientRepository;

  PlaylistCubit(this.clientRepository) : super(PlaylistState.initial()) {
    load();
  }

  void load({Duration? ttl}) {
    clientRepository.playlist(ttl: ttl).then((spiff) {
      emit(PlaylistLoaded(spiff));
    }).onError((error, stackTrace) {});
  }

  void reload() {
    load(ttl: Duration.zero);
  }

  void replace(String ref,
      {int index = 0,
      double position = 0.0,
      MediaType mediaType = MediaType.music}) {
    final body =
        patchReplace(ref, mediaType.name) + patchPosition(index, position);
    clientRepository.patch(body).then((result) {
      if (result.isModified) {
        final spiff = Spiff.fromJson(result.body);
        emit(PlaylistChanged(spiff));
      } else {
        // TODO
      }
    }).onError((error, stackTrace) {
      // TODO
    });
  }

  void update({int index = 0, double position = 0.0}) {
    final body = patchPosition(index, position);
    clientRepository.patch(body).then((result) {
      // TODO
    }).onError((error, stackTrace) {
      // TODO
    });
  }
}
