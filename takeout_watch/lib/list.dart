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

import 'package:flutter/material.dart';
import 'package:rotary_scrollbar/rotary_scrollbar.dart';

class RotaryList<T> extends StatefulWidget {
  final List<T> entries;
  final Widget Function(BuildContext, T) tileBuilder;

  const RotaryList(this.entries, {required this.tileBuilder, super.key});

  @override
  State<RotaryList<T>> createState() => _RotaryListState<T>();
}

class _RotaryListState<T> extends State<RotaryList<T>> {
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotaryScrollWrapper(
      rotaryScrollbar: RotaryScrollbar(
        controller: scrollController,
      ),
      child: ListView.builder(
          controller: scrollController,
          itemBuilder: (context, index) {
            final entry = widget.entries[index];
            return Padding(
                padding: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: Card(
                  elevation: 0,
                  color: Colors.white10,
                  child: widget.tileBuilder.call(context, entry),
                ));
          },
          itemCount: widget.entries.length),
    );
  }
}
