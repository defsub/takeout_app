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

bool isNullOrEmpty(String? s) => s?.trim().isEmpty ?? true;

bool isNotNullOrEmpty(String? s) => s?.trim().isNotEmpty ?? false;

const kilobyte = 1024;
const megabyte = kilobyte*1024;
const gigabyte = megabyte*1024;

String storage(int size) {
  int n = size ~/ gigabyte;
  if (n > 0) {
    return '$n GB';
  }
  n = size ~/ megabyte;
  if (n > 0) {
    return '$n MB';
  }
  n = size ~/ kilobyte;
  if (n > 0) {
    return '$n KB';
  }
  return '$size B';
}
