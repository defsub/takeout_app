// Copyright (C) 2021 The Takeout Authors.
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

import 'dart:collection';

import 'package:takeout_app/global.dart';

extension TakeoutDuration on Duration {
  String get inHoursMinutes {
    var mins = inMinutes.remainder(60);
    return inHours > 0 ? '${inHours}h ${mins}m' : '${mins}m';
  }

  String get hhmmss {
    final hours = twoDigits(inHours);
    final mins = twoDigits(inMinutes.remainder(60));
    final secs = twoDigits(inSeconds.remainder(60));
    return '$hours:$mins:$secs';
  }
}

String twoDigits(int n) {
  return n >= 10 ? '${n}' : '0${n}';
}

String ymd(dynamic date) {
  final t = (date is String)
      ? DateTime.parse(date)
      : (date is DateTime)
          ? date
          : DateTime.parse(date.toString());
  final y = twoDigits(t.year);
  final m = twoDigits(t.month);
  final d = twoDigits(t.day);
  return '${y}-${m}-${d}';
}

bool isNullOrEmpty(String? s) => s?.trim().isEmpty ?? true;

bool isNotNullOrEmpty(String? s) => s?.trim().isNotEmpty ?? false;

const kilobyte = 1024;
const megabyte = kilobyte * 1024;
const gigabyte = megabyte * 1024;

String storage(int size) {
  double f = size / gigabyte;
  if (f >= 1.0) {
    return '${f.toStringAsFixed(2)} GB';
  }
  f = size / megabyte;
  if (f >= 1.0) {
    return '${f.toStringAsFixed(2)} MB';
  }
  f = size / kilobyte;
  if (f >= 1.0) {
    return '${f.toStringAsFixed(2)} KB';
  }
  return '${f.toStringAsFixed(2)} B';
}

int parseYear(String date) {
  var year = -1;
  try {
    // parse supports many expected formats
    final d = DateTime.parse(date);
    year = d.year;
  } on FormatException {
    // try year only
    year = int.tryParse(date) ?? 0;
  }
  return year;
}

String merge(List<String> args, {String separator = textSeparator}) {
  args.retainWhere((s) => s.toString().isNotEmpty);
  return args.join(separator);
}

// TODO move below to util, global or other
String year(String date) {
  var d = DateTime.parse(date);
  // year 1 is a Go zero value date
  return d.year == 1 ? '' : '${d.year}';
}

class ExpiringMap<K, V> {
  final Duration duration;
  final Map<K, V> _map = {};

  ExpiringMap(this.duration);

  V? operator [](K key) => _map[key];

  void operator []=(K key, V value) {
    _map[key] = value;
    Future.delayed(duration, () => _map.remove(key));
  }

  bool containsKey(K key) {
    return _map.containsKey(key);
  }

  Iterable<K> keys() {
    return _map.keys;
  }

  Iterable<V> values() {
    return _map.values;
  }

  int get length {
    return _map.length;
  }
}

class ExpiringSet<V> {
  final Duration duration;
  final Set<V> _set = HashSet<V>();

  ExpiringSet(this.duration);

  void add(V value) {
    if (_set.contains(value)) {
      return;
    }
    _set.add(value);
    Future.delayed(duration, () => _set.remove(value));
  }

  bool contains(V value) {
    return _set.contains(value);
  }

  Iterator<V> get iterator {
    return _set.iterator;
  }

  int get length {
    return _set.length;
  }
}
