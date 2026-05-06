import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class PopupController extends ChangeNotifier {
  late List<String> suggestions;
  int _selectedIndex = 0;
  bool shouldShow = false;
  bool enabled = true;

  final ItemScrollController itemScrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();

  /// Should be called when an active list item is selected to be inserted
  /// into the text.
  late final void Function() onCompletionSelected;

  PopupController({required this.onCompletionSelected}) : super();

  set selectedIndex(int value) {
    _selectedIndex = value;
    notifyListeners();
  }

  int get selectedIndex => _selectedIndex;

  void show(List<String> suggestions) {
    if (!enabled) {
      return;
    }

    this.suggestions = suggestions;
    _selectedIndex = 0;
    shouldShow = true;
    notifyListeners();
    _jumpToWhenReady(index: 0);
  }

  void hide() {
    shouldShow = false;
    notifyListeners();
  }

  /// Changes the selected item and scrolls through the list of completions
  /// on keyboard arrows pressed.
  void scrollByArrow(ScrollDirection direction) {
    if (direction == ScrollDirection.up) {
      _selectedIndex =
          (selectedIndex - 1 + suggestions.length) % suggestions.length;
    } else {
      _selectedIndex = (selectedIndex + 1) % suggestions.length;
    }
    final visiblePositions = itemPositionsListener.itemPositions.value
        .where((item) {
          final bool isTopVisible = item.itemLeadingEdge >= 0;
          final bool isBottomVisible = item.itemTrailingEdge <= 1;
          return isTopVisible && isBottomVisible;
        })
        .map((e) => e.index)
        .toList();

    int? targetIndex;

    if (visiblePositions.isEmpty) {
      targetIndex = selectedIndex;
    } else {
      visiblePositions.sort();
      final firstVisibleIndex = visiblePositions.first;
      final lastVisibleIndex = visiblePositions.last;

      if (selectedIndex < firstVisibleIndex) {
        targetIndex = selectedIndex;
      } else if (selectedIndex > lastVisibleIndex) {
        final visibleCount = visiblePositions.length;
        targetIndex =
            (selectedIndex - visibleCount + 1).clamp(0, suggestions.length - 1);
      }
    }

    notifyListeners();
    if (targetIndex != null) {
      _jumpToWhenReady(index: targetIndex);
    }
  }

  void _jumpToWhenReady({
    required int index,
    double alignment = 0,
    int remainingAttempts = 3,
  }) {
    if (_tryJumpTo(index: index, alignment: alignment)) {
      return;
    }

    if (remainingAttempts <= 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!enabled) {
        return;
      }
      _jumpToWhenReady(
        index: index,
        alignment: alignment,
        remainingAttempts: remainingAttempts - 1,
      );
    });
  }

  bool _tryJumpTo({required int index, double alignment = 0}) {
    if (!itemScrollController.isAttached) {
      return false;
    }

    try {
      itemScrollController.jumpTo(index: index, alignment: alignment);
      return true;
    } on TypeError {
      return false;
    }
  }

  String getSelectedWord() => suggestions[selectedIndex];

  @override
  void dispose() {
    enabled = false;
    shouldShow = false;
    final itemPositions = itemPositionsListener.itemPositions;
    if (itemPositions is ChangeNotifier) {
      (itemPositions as ChangeNotifier).dispose();
    }
    super.dispose();
  }
}

/// Possible directions of completions list navigation
enum ScrollDirection {
  up,
  down,
}
