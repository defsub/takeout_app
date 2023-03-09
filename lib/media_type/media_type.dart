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

import 'package:hydrated_bloc/hydrated_bloc.dart';

enum MediaType {
  music,
  video,
  podcast,
  stream;

  static final _names = MediaType.values.asNameMap();

  static MediaType of(String name) {
    final value = _names[name];
    return value != null ? value : throw ArgumentError();
  }
}

abstract class MediaTypeEvent {}

class NextMediaTypeEvent extends MediaTypeEvent {}

class PreviousMediaTypeEvent extends MediaTypeEvent {}

class SelectMediaTypeEvent extends MediaTypeEvent {
  final MediaType mediaType;

  SelectMediaTypeEvent(this.mediaType);
}

class MediaTypeBloc extends Bloc<MediaTypeEvent, MediaType> {
  MediaTypeBloc() : super(MediaType.music) {
    on<NextMediaTypeEvent>(_onNext);
    on<PreviousMediaTypeEvent>(_onPrevious);
    on<SelectMediaTypeEvent>(_onSelect);
  }

  void _onNext(NextMediaTypeEvent event, Emitter<MediaType> emit) {
    switch (state) {
      case MediaType.music:
        emit(MediaType.video);
        break;
      case MediaType.video:
        emit(MediaType.podcast);
        break;
      case MediaType.podcast:
        emit(MediaType.music);
        break;
      default:
        emit(MediaType.music);
        break;
    }
  }

  void _onPrevious(PreviousMediaTypeEvent event, Emitter<MediaType> emit) {
    switch (state) {
      case MediaType.music:
        emit(MediaType.podcast);
        break;
      case MediaType.video:
        emit(MediaType.music);
        break;
      case MediaType.podcast:
        emit(MediaType.video);
        break;
      default:
        emit(MediaType.music);
        break;
    }
  }

  void _onSelect(SelectMediaTypeEvent event, Emitter<MediaType> emit) {
    emit(event.mediaType);
  }
}

class SelectedMediaType extends HydratedCubit<MediaType> {
  SelectedMediaType() : super(MediaType.music);

  // music -> video -> podcast
  void next() {
    switch (state) {
      case MediaType.music:
        emit(MediaType.video);
        break;
      case MediaType.video:
        emit(MediaType.podcast);
        break;
      case MediaType.podcast:
        emit(MediaType.music);
        break;
      default:
        emit(MediaType.music);
        break;
    }
  }

  // music <- video <- podcast
  void previous() {
    switch (state) {
      case MediaType.music:
        emit(MediaType.podcast);
        break;
      case MediaType.video:
        emit(MediaType.music);
        break;
      case MediaType.podcast:
        emit(MediaType.video);
        break;
      default:
        emit(MediaType.music);
        break;
    }
  }

  void select(MediaType mediaType) {
    emit(mediaType);
  }

  @override
  MediaType? fromJson(Map<String, dynamic> json) => MediaType.of(json['name']);

  @override
  Map<String, dynamic>? toJson(MediaType state) => {'name': state.name};
}
