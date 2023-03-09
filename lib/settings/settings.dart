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

import 'model.dart';

class SettingsCubit extends HydratedCubit<Settings> {
  SettingsCubit() : super(Settings.initial());

  void add(
          {String? user,
          String? host,
          bool? allowStreaming,
          bool? allowDownload,
          bool? allowArtistArtwork}) =>
      emit(state.copyWith(
          user: user,
          host: host,
          allowMobileStreaming: allowStreaming,
          allowMobileDownload: allowDownload,
          allowMobileArtistArtwork: allowArtistArtwork));

  void set user(String user) {
    emit(state.copyWith(user: user));
  }

  void set host(String host) {
    emit(state.copyWith(host: host));
  }

  void set allowStreaming(bool value) {
    emit(state.copyWith(allowMobileStreaming: value));
  }

  void set allowDownload(bool value) {
    emit(state.copyWith(allowMobileDownload: value));
  }

  void set allowArtistArtwork(bool value) {
    emit(state.copyWith(allowMobileArtistArtwork: value));
  }

  @override
  Settings fromJson(Map<String, dynamic> json) =>
      Settings.fromJson(json['settings']);

  @override
  Map<String, dynamic>? toJson(Settings settings) =>
      {'settings': settings.toJson()};
}
