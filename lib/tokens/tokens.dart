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

class TokensCubit extends HydratedCubit<Tokens> {
  TokensCubit() : super(Tokens.empty());

  void add(Tokens tokens) {
    emit(tokens);
  }

  @override
  Tokens fromJson(Map<String, dynamic> json) => Tokens.fromJson(json['tokens']);

  @override
  Map<String, dynamic>? toJson(Tokens tokens) => {'tokens': tokens.toJson()};
}