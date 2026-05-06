import 'dart:math';

import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../sizes.dart';
import 'popup_controller.dart';

/// Popup window displaying the list of possible completions
class Popup extends StatefulWidget {
  final PopupController controller;
  final Size editingWindowSize;

  /// The window coordinates of the top-left corner of the editor widget.
  final Offset? editorOffset;

  /// The window coordinates of the highest allowed top-left corner
  /// of the popup if shown above the caret.
  ///
  /// Since the popup is pushed to the bottom of the allowed rectangle
  /// the actual position may be lower.
  final Offset flippedOffset;

  /// The window coordinates of the top-left corner of the popup
  /// if shown below the caret.
  final Offset normalOffset;

  final FocusNode parentFocusNode;
  final TextStyle style;
  final Color? backgroundColor;

  const Popup({
    super.key,
    required this.controller,
    required this.editingWindowSize,
    required this.editorOffset,
    required this.flippedOffset,
    required this.normalOffset,
    required this.parentFocusNode,
    required this.style,
    this.backgroundColor,
  });

  @override
  PopupState createState() => PopupState();
}

class PopupState extends State<Popup> {
  final pageStorageBucket = PageStorageBucket();

  @override
  void initState() {
    widget.controller.addListener(rebuild);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeListener(rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verticalFlipRequired = _isVerticalFlipRequired();
    final bool isHorizontalOverflowed = _isHorizontallyOverflowed();
    final double leftOffsetLimit = max(
      widget.editorOffset?.dx ?? 0,
      (widget.editorOffset?.dx ?? 0) +
          widget.editingWindowSize.width -
          Sizes.autocompletePopupMaxWidth,
    );
    final popupBackgroundColor =
        (widget.backgroundColor ?? theme.colorScheme.surface).withValues(
      alpha: 0.96,
    );
    final hoverColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    final selectedColor = theme.colorScheme.primary.withValues(alpha: 0.22);

    return PageStorage(
      bucket: pageStorageBucket,
      child: Positioned(
        left: isHorizontalOverflowed ? leftOffsetLimit : widget.normalOffset.dx,
        top: verticalFlipRequired
            ? widget.flippedOffset.dy
            : widget.normalOffset.dy,
        child: Container(
          alignment: verticalFlipRequired
              ? Alignment.bottomCenter
              : Alignment.topCenter,
          constraints: const BoxConstraints(
            maxHeight: Sizes.autocompletePopupMaxHeight,
            maxWidth: Sizes.autocompletePopupMaxWidth,
          ),
          // Container is used because the vertical borders
          // in DecoratedBox are hidden under scroll.
          // ignore: use_decorated_box
          child: Container(
            decoration: BoxDecoration(
              color: popupBackgroundColor,
              border: Border.all(
                color: widget.style.color!,
                width: 0.5,
              ),
            ),
            child: ScrollablePositionedList.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemScrollController: widget.controller.itemScrollController,
              itemPositionsListener: widget.controller.itemPositionsListener,
              itemCount: widget.controller.suggestions.length,
              itemBuilder: (context, index) {
                return _buildListItem(
                  index,
                  backgroundColor: popupBackgroundColor,
                  hoverColor: hoverColor,
                  selectedColor: selectedColor,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  bool _isVerticalFlipRequired() {
    final isPopupShorterThanWindow =
        Sizes.autocompletePopupMaxHeight < widget.editingWindowSize.height;
    final isPopupOverflowingHeight = widget.normalOffset.dy +
            Sizes.autocompletePopupMaxHeight -
            (widget.editorOffset?.dy ?? 0) >
        widget.editingWindowSize.height;

    return isPopupOverflowingHeight && isPopupShorterThanWindow;
  }

  bool _isHorizontallyOverflowed() {
    return widget.normalOffset.dx -
            (widget.editorOffset?.dx ?? 0) +
            Sizes.autocompletePopupMaxWidth >
        widget.editingWindowSize.width;
  }

  Widget _buildListItem(
    int index, {
    required Color backgroundColor,
    required Color hoverColor,
    required Color selectedColor,
  }) {
    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: () {
          widget.controller.selectedIndex = index;
          widget.parentFocusNode.requestFocus();
        },
        onDoubleTap: () {
          widget.controller.selectedIndex = index;
          widget.parentFocusNode.requestFocus();
          widget.controller.onCompletionSelected();
        },
        hoverColor: hoverColor,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: ColoredBox(
          color: widget.controller.selectedIndex == index
              ? selectedColor
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.controller.suggestions[index],
              overflow: TextOverflow.ellipsis,
              style: widget.style,
            ),
          ),
        ),
      ),
    );
  }

  void rebuild() {
    setState(() {});
  }
}
