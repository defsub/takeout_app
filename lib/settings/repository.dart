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

import 'dart:async';

import 'settings.dart';
import 'model.dart';

class SettingsRepository {
  StreamSubscription<Settings>? _subscription;
  Settings? _settings;

  SettingsRepository({SettingsCubit? cubit}) {
    if (cubit != null) {
      init(cubit);
    }
  }

  void init(SettingsCubit cubit) {
    _settings = cubit.state;
    _subscription = cubit.stream.listen((event) {
      _settings = event;
    });
  }

  void dispose() {
    _subscription?.cancel();
  }

  Settings? get settings => _settings;
}
