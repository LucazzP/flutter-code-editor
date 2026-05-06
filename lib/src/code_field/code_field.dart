import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import '../code_theme/code_theme.dart';
import '../gutter/gutter.dart';
import '../line_numbers/gutter_style.dart';
import '../search/widget/search_widget.dart';
import '../sizes.dart';
import '../wip/autocomplete/popup.dart';
import 'actions/comment_uncomment.dart';
import 'actions/enter_key.dart';
import 'actions/indent.dart';
import 'actions/outdent.dart';
import 'actions/search.dart';
import 'actions/tab.dart';
import 'code_controller.dart';
import 'default_styles.dart';
import 'js_workarounds/js_workarounds.dart';

final _shortcuts = <ShortcutActivator, Intent>{
  // Copy
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyC,
  ): CopySelectionTextIntent.copy,
  const SingleActivator(
    LogicalKeyboardKey.keyC,
    meta: true,
  ): CopySelectionTextIntent.copy,
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.insert,
  ): CopySelectionTextIntent.copy,

  // Cut
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyX,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  const SingleActivator(
    LogicalKeyboardKey.keyX,
    meta: true,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.delete,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),

  // Undo
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyZ,
  ): const UndoTextIntent(SelectionChangedCause.keyboard),
  const SingleActivator(
    LogicalKeyboardKey.keyZ,
    meta: true,
  ): const UndoTextIntent(SelectionChangedCause.keyboard),

  // Redo
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(SelectionChangedCause.keyboard),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(SelectionChangedCause.keyboard),

  // Indent
  LogicalKeySet(
    LogicalKeyboardKey.tab,
  ): const IndentIntent(),

  // Outdent
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.tab,
  ): const OutdentIntent(),

  // Comment Uncomment
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.slash,
  ): const CommentUncommentIntent(),
  const SingleActivator(
    LogicalKeyboardKey.slash,
    meta: true,
  ): const CommentUncommentIntent(),

  // Search
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyF,
  ): const SearchIntent(),
  const SingleActivator(
    LogicalKeyboardKey.keyF,
    meta: true,
  ): const SearchIntent(),

  // Dismiss
  LogicalKeySet(
    LogicalKeyboardKey.escape,
  ): const DismissIntent(),

  // EnterKey
  LogicalKeySet(
    LogicalKeyboardKey.enter,
  ): const EnterKeyIntent(),

  // TabKey
  LogicalKeySet(
    LogicalKeyboardKey.tab,
  ): const TabKeyIntent(),
};

const _searchPopupPadding = 10.0;
const _searchPopupMinWidth = 320.0;
const _searchPopupMinHeight = 70.0;

class CodeField extends StatefulWidget {
  /// {@macro flutter.widgets.textField.minLines}
  final int? minLines;

  /// {@macro flutter.widgets.textField.maxLInes}
  final int? maxLines;

  /// {@macro flutter.widgets.textField.expands}
  final bool expands;

  /// Whether overflowing lines should wrap around
  /// or make the field scrollable horizontally.
  final bool wrap;

  /// A CodeController instance to apply
  /// language highlight, themeing and modifiers.
  final CodeController controller;

  /// An UndoHistoryController instance
  /// to control TextField history.
  final UndoHistoryController? undoController;

  @Deprecated('Use gutterStyle instead')
  final GutterStyle lineNumberStyle;

  /// {@macro flutter.widgets.textField.cursorColor}
  final Color? cursorColor;

  /// {@macro flutter.widgets.textField.textStyle}
  final TextStyle? textStyle;

  /// {@macro flutter.widgets.textField.smartDashesType}
  final SmartDashesType smartDashesType;

  /// {@macro flutter.widgets.textField.smartQuotesType}
  final SmartQuotesType smartQuotesType;

  /// A way to replace specific line numbers by a custom TextSpan
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;

  /// {@macro flutter.widgets.textField.enabled}
  final bool? enabled;

  /// {@macro flutter.widgets.editableText.onChanged}
  final void Function(String)? onChanged;

  /// {@macro flutter.widgets.editableText.readOnly}
  ///
  /// This is just passed as a parameter to a [TextField].
  /// See also [CodeController.readOnly].
  final bool readOnly;

  final Color? background;
  final EdgeInsets padding;
  final Decoration? decoration;
  final TextSelectionThemeData? textSelectionTheme;
  final FocusNode? focusNode;

  @Deprecated('Use gutterStyle instead')
  final bool? lineNumbers;

  final GutterStyle gutterStyle;

  const CodeField({
    super.key,
    required this.controller,
    this.undoController,
    this.minLines,
    this.maxLines,
    this.expands = false,
    this.wrap = false,
    this.background,
    this.decoration,
    this.textStyle,
    this.smartDashesType = SmartDashesType.disabled,
    this.smartQuotesType = SmartQuotesType.disabled,
    this.padding = EdgeInsets.zero,
    GutterStyle? gutterStyle,
    this.enabled,
    this.readOnly = false,
    this.cursorColor,
    this.textSelectionTheme,
    this.lineNumberBuilder,
    this.focusNode,
    this.onChanged,
    @Deprecated('Use gutterStyle instead') this.lineNumbers,
    @Deprecated('Use gutterStyle instead')
    this.lineNumberStyle = const GutterStyle(),
  })  : assert(
            gutterStyle == null || lineNumbers == null,
            'Can not provide gutterStyle and lineNumbers at the same time. '
            'Please use gutterStyle and provide necessary columns to show/hide'),
        gutterStyle = gutterStyle ??
            ((lineNumbers == false) ? GutterStyle.none : lineNumberStyle);

  @override
  State<CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<CodeField> {
  // Add a controller
  LinkedScrollControllerGroup? _controllers;
  ScrollController? _numberScroll;
  ScrollController? _codeScroll;
  ScrollController? _horizontalCodeScroll;
  final _codeFieldKey = GlobalKey();
  final _textFieldKey = GlobalKey();

  OverlayEntry? _suggestionsPopup;
  OverlayEntry? _searchPopup;
  Offset _normalPopupOffset = Offset.zero;
  Offset _flippedPopupOffset = Offset.zero;
  double painterWidth = 0;
  double painterHeight = 0;

  FocusNode? _focusNode;
  String? lines;
  String longestLine = '';
  Size? windowSize;
  late TextStyle textStyle;
  Color? _backgroundCol;

  final _editorKey = GlobalKey();
  Offset? _editorOffset;
  bool _overlayGeometryUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _numberScroll = _controllers?.addAndGet();
    _codeScroll = _controllers?.addAndGet();

    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_scheduleOverlayGeometryUpdate);
    widget.controller.popupController.addListener(_onPopupStateChanged);
    widget.controller.searchController.addListener(
      _onSearchControllerChange,
    );
    _codeScroll?.addListener(_scheduleOverlayGeometryUpdate);
    _horizontalCodeScroll = ScrollController()
      ..addListener(_scheduleOverlayGeometryUpdate);
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode!.attach(context, onKeyEvent: _onKeyEvent);

    widget.controller.searchController.codeFieldFocusNode = _focusNode;

    // Workaround for disabling spellchecks in FireFox
    // https://github.com/akvelon/flutter-code-editor/issues/197
    disableSpellCheckIfWeb();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleOverlayGeometryUpdate();
    });
    _onTextChanged();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    return widget.controller.onKey(event);
  }

  @override
  void dispose() {
    widget.controller.searchController.codeFieldFocusNode = null;
    widget.controller.removeListener(_onTextChanged);
    widget.controller.removeListener(_scheduleOverlayGeometryUpdate);
    widget.controller.popupController.removeListener(_onPopupStateChanged);
    _disposeOverlayEntry(_suggestionsPopup);
    _suggestionsPopup = null;
    widget.controller.searchController.removeListener(
      _onSearchControllerChange,
    );
    _disposeOverlayEntry(_searchPopup);
    _searchPopup = null;
    _codeScroll?.removeListener(_scheduleOverlayGeometryUpdate);
    _horizontalCodeScroll?.removeListener(_scheduleOverlayGeometryUpdate);
    _numberScroll?.dispose();
    _codeScroll?.dispose();
    _horizontalCodeScroll?.dispose();
    if (widget.focusNode == null) {
      _focusNode?.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(_onTextChanged);
    oldWidget.controller.removeListener(_scheduleOverlayGeometryUpdate);
    oldWidget.controller.popupController.removeListener(_onPopupStateChanged);
    oldWidget.controller.searchController.removeListener(
      _onSearchControllerChange,
    );

    widget.controller.searchController.codeFieldFocusNode = _focusNode;
    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_scheduleOverlayGeometryUpdate);
    widget.controller.popupController.addListener(_onPopupStateChanged);
    widget.controller.searchController.addListener(
      _onSearchControllerChange,
    );
  }

  void rebuild() {
    setState(_scheduleOverlayGeometryUpdate);
  }

  void _onTextChanged() {
    // Rebuild line number
    final str = widget.controller.text.split('\n');
    final buf = <String>[];

    for (var k = 0; k < str.length; k++) {
      buf.add((k + 1).toString());
    }

    // Find longest line
    longestLine = '';
    widget.controller.text.split('\n').forEach((line) {
      if (line.length > longestLine.length) longestLine = line;
    });

    rebuild();
  }

  // Wrap the codeField in a horizontal scrollView
  Widget _wrapInScrollView(
    Widget codeField,
    TextStyle textStyle,
    double minWidth,
  ) {
    final intrinsic = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 0,
              minWidth: minWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(longestLine, style: textStyle),
            ), // Add extra padding
          ),
          widget.expands ? Expanded(child: codeField) : codeField,
        ],
      ),
    );

    return widget.wrap
        ? intrinsic
        : SingleChildScrollView(
            padding: EdgeInsets.only(
              right: widget.padding.right,
            ),
            scrollDirection: Axis.horizontal,
            controller: _horizontalCodeScroll,
            child: intrinsic,
          );
  }

  @override
  Widget build(BuildContext context) {
    // Default color scheme
    const rootKey = 'root';

    final themeData = Theme.of(context);
    final styles = CodeTheme.of(context)?.styles;
    _backgroundCol = widget.background ??
        styles?[rootKey]?.backgroundColor ??
        DefaultStyles.backgroundColor;

    if (widget.decoration != null) {
      _backgroundCol = null;
    }

    final defaultTextStyle = TextStyle(
      color: styles?[rootKey]?.color ?? DefaultStyles.textColor,
      fontSize: themeData.textTheme.titleMedium?.fontSize,
      height: themeData.textTheme.titleMedium?.height,
    );

    textStyle = defaultTextStyle.merge(widget.textStyle);

    final codeField = TextField(
      key: _textFieldKey,
      focusNode: _focusNode,
      scrollPadding: widget.padding,
      style: textStyle,
      smartDashesType: widget.smartDashesType,
      smartQuotesType: widget.smartQuotesType,
      controller: widget.controller,
      undoController: widget.undoController,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      expands: widget.expands,
      scrollController: _codeScroll,
      decoration: const InputDecoration(
        isCollapsed: true,
        contentPadding: EdgeInsets.symmetric(vertical: 16),
        disabledBorder: InputBorder.none,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      cursorColor: widget.cursorColor ?? defaultTextStyle.color,
      autocorrect: false,
      enableSuggestions: false,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      readOnly: widget.readOnly,
    );

    final editingField = Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: widget.textSelectionTheme,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Control horizontal scrolling
          return _wrapInScrollView(codeField, textStyle, constraints.maxWidth);
        },
      ),
    );

    return FocusableActionDetector(
      actions: widget.controller.actions,
      shortcuts: _shortcuts,
      child: Container(
        decoration: widget.decoration,
        color: _backgroundCol,
        key: _codeFieldKey,
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.gutterStyle.showGutter) _buildGutter(),
            Expanded(key: _editorKey, child: editingField),
          ],
        ),
      ),
    );
  }

  Widget _buildGutter() {
    final lineNumberSize = textStyle.fontSize;
    final lineNumberColor =
        widget.gutterStyle.textStyle?.color ?? textStyle.color?.withOpacity(.5);

    final lineNumberTextStyle =
        (widget.gutterStyle.textStyle ?? textStyle).copyWith(
      color: lineNumberColor,
      fontFamily: textStyle.fontFamily,
      fontSize: lineNumberSize,
    );

    final gutterStyle = widget.gutterStyle.copyWith(
      textStyle: lineNumberTextStyle,
      errorPopupTextStyle: widget.gutterStyle.errorPopupTextStyle ??
          CodeTheme.of(context)?.styles['root'] ??
          textStyle.copyWith(
            fontSize: DefaultStyles.errorPopupTextSize,
            backgroundColor: DefaultStyles.backgroundColor,
            fontStyle: DefaultStyles.fontStyle,
          ),
    );

    return GutterWidget(
      codeController: widget.controller,
      style: gutterStyle,
      scrollController: _numberScroll,
    );
  }

  void _scheduleOverlayGeometryUpdate() {
    if (_overlayGeometryUpdateScheduled) {
      return;
    }

    _overlayGeometryUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayGeometryUpdateScheduled = false;
      if (!mounted) {
        return;
      }

      _updateOverlayGeometry();
      if (_suggestionsPopup != null ||
          widget.controller.popupController.shouldShow) {
        _onPopupStateChanged();
      }
      if (_searchPopup != null ||
          widget.controller.searchController.shouldShow) {
        _onSearchControllerChange();
      }
    });
  }

  void _updateOverlayGeometry() {
    final overlay = Overlay.maybeOf(context);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    final editorBox =
        _editorKey.currentContext?.findRenderObject() as RenderBox?;

    Size? nextWindowSize = windowSize;
    Offset? nextEditorOffset = _editorOffset;

    if (overlayBox != null && editorBox != null && editorBox.hasSize) {
      nextWindowSize = editorBox.size;
      nextEditorOffset = editorBox.localToGlobal(
        Offset.zero,
        ancestor: overlayBox,
      );
    }

    Offset nextNormalOffset = _normalPopupOffset;
    Offset nextFlippedOffset = _flippedPopupOffset;
    final textFieldState = _textFieldKey.currentState;
    final editableTextState = _getEditableTextState(textFieldState);
    final renderEditable = editableTextState?.renderEditable;
    final selection = widget.controller.selection;

    if (overlayBox != null &&
        renderEditable != null &&
        renderEditable.hasSize &&
        selection.isValid) {
      final caretRect = renderEditable.getLocalRectForCaret(selection.extent);
      final caretTopLeft = renderEditable.localToGlobal(
        caretRect.topLeft,
        ancestor: overlayBox,
      );
      final caretBottomLeft = renderEditable.localToGlobal(
        caretRect.bottomLeft,
        ancestor: overlayBox,
      );

      nextNormalOffset = caretBottomLeft.translate(
        0,
        Sizes.caretPadding.toDouble(),
      );
      const popupHeight = Sizes.autocompletePopupMaxHeight;
      final caretPadding = Sizes.caretPadding.toDouble();
      nextFlippedOffset = caretTopLeft.translate(
        0,
        -(popupHeight + caretPadding),
      );
    }

    final shouldUpdate = nextWindowSize != windowSize ||
        nextEditorOffset != _editorOffset ||
        nextNormalOffset != _normalPopupOffset ||
        nextFlippedOffset != _flippedPopupOffset;

    if (!shouldUpdate) {
      return;
    }

    setState(() {
      windowSize = nextWindowSize;
      _editorOffset = nextEditorOffset;
      _normalPopupOffset = nextNormalOffset;
      _flippedPopupOffset = nextFlippedOffset;
    });
  }

  EditableTextState? _getEditableTextState(State? textFieldState) {
    if (textFieldState == null) {
      return null;
    }

    // `editableTextKey` is only exposed on the private TextField state type.
    // ignore: avoid_dynamic_calls
    final editableTextKey = (textFieldState as dynamic).editableTextKey
        as GlobalKey<EditableTextState>;
    return editableTextKey.currentState;
  }

  void _onPopupStateChanged() {
    final shouldShow =
        widget.controller.popupController.shouldShow && windowSize != null;
    if (!shouldShow) {
      _disposeOverlayEntry(_suggestionsPopup);
      _suggestionsPopup = null;
      return;
    }

    if (_suggestionsPopup == null) {
      _suggestionsPopup = _buildSuggestionOverlay();
      Overlay.of(context).insert(_suggestionsPopup!);
    }

    _suggestionsPopup!.markNeedsBuild();
  }

  void _onSearchControllerChange() {
    final shouldShow = widget.controller.searchController.shouldShow;

    if (!shouldShow) {
      _disposeOverlayEntry(_searchPopup);
      _searchPopup = null;
      return;
    }

    _updateOverlayGeometry();

    if (_searchPopup == null) {
      _searchPopup = _buildSearchOverlay();
      Overlay.of(context).insert(_searchPopup!);
    }

    _searchPopup!.markNeedsBuild();
  }

  OverlayEntry _buildSearchOverlay() {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = _getTextColorFromTheme() ?? colorScheme.onSurface;
    return OverlayEntry(
      builder: (context) {
        final searchPopup = Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(
              color: borderColor,
            ),
            borderRadius: const BorderRadius.all(
              Radius.circular(5),
            ),
          ),
          child: Material(
            color: _backgroundCol,
            child: SearchWidget(
              searchController: widget.controller.searchController,
            ),
          ),
        );

        final codeFieldRect = _getCodeFieldRectInOverlay();
        final canPositionInsideEditor = codeFieldRect != null &&
            codeFieldRect.width >= _searchPopupMinWidth &&
            codeFieldRect.height >= _searchPopupMinHeight;

        if (canPositionInsideEditor) {
          return Positioned(
            left: codeFieldRect.left,
            top: codeFieldRect.top,
            width: codeFieldRect.width,
            height: codeFieldRect.height,
            child: Padding(
              padding: const EdgeInsets.all(_searchPopupPadding),
              child: Align(
                alignment: Alignment.bottomRight,
                child: searchPopup,
              ),
            ),
          );
        }

        return Positioned(
          bottom: _searchPopupPadding,
          right: _searchPopupPadding,
          child: searchPopup,
        );
      },
    );
  }

  Rect? _getCodeFieldRectInOverlay() {
    final overlay = Overlay.maybeOf(context);
    final overlayBox = overlay?.context.findRenderObject() as RenderBox?;
    final codeFieldBox =
        _codeFieldKey.currentContext?.findRenderObject() as RenderBox?;

    if (overlayBox == null || codeFieldBox == null || !codeFieldBox.hasSize) {
      return null;
    }

    final offset = codeFieldBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    return offset & codeFieldBox.size;
  }

  void _disposeOverlayEntry(OverlayEntry? entry) {
    if (entry == null) {
      return;
    }
    if (entry.mounted) {
      entry.remove();
    }
    entry.dispose();
  }

  Color? _getTextColorFromTheme() {
    final textTheme = Theme.of(context).textTheme;

    return textTheme.bodyLarge?.color ??
        textTheme.bodyMedium?.color ??
        textTheme.bodySmall?.color ??
        textTheme.displayLarge?.color ??
        textTheme.displayMedium?.color ??
        textTheme.displaySmall?.color ??
        textTheme.headlineLarge?.color ??
        textTheme.headlineMedium?.color ??
        textTheme.headlineSmall?.color ??
        textTheme.labelLarge?.color ??
        textTheme.labelMedium?.color ??
        textTheme.labelSmall?.color ??
        textTheme.titleLarge?.color ??
        textTheme.titleMedium?.color ??
        textTheme.titleSmall?.color;
  }

  OverlayEntry _buildSuggestionOverlay() {
    return OverlayEntry(
      builder: (context) {
        return Popup(
          normalOffset: _normalPopupOffset,
          flippedOffset: _flippedPopupOffset,
          controller: widget.controller.popupController,
          editingWindowSize: windowSize!,
          style: textStyle,
          backgroundColor: _backgroundCol,
          parentFocusNode: _focusNode!,
          editorOffset: _editorOffset,
        );
      },
    );
  }
}
