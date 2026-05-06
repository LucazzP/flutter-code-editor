import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_code_editor/src/sizes.dart';
import 'package:flutter_code_editor/src/wip/autocomplete/popup.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

void main() {
  group('CodeField autocomplete popup', () {
    testWidgets('positions suggestions below the caret',
        (WidgetTester wt) async {
      final controller = createController('');
      final focusNode = FocusNode();
      controller.autocompleter.setCustomWords(['widgetBuilder']);

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeField(
              controller: controller,
              focusNode: focusNode,
              decoration: const BoxDecoration(),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await wt.pump();

      await wt.enterText(find.byType(TextField), 'wid');
      await wt.pump();
      await wt.pump();

      final popup = wt.widget<Popup>(find.byType(Popup));
      final editableText =
          wt.state<EditableTextState>(find.byType(EditableText));
      final overlayBox = wt.renderObject<RenderBox>(find.byType(Overlay).first);
      final caretRect = editableText.renderEditable.getLocalRectForCaret(
        controller.selection.extent,
      );
      final expectedOffset = editableText.renderEditable
          .localToGlobal(caretRect.bottomLeft, ancestor: overlayBox)
          .translate(0, Sizes.caretPadding.toDouble());

      expect(find.text('widgetBuilder'), findsOneWidget);
      expect(popup.normalOffset.dx, closeTo(expectedOffset.dx, 0.1));
      expect(popup.normalOffset.dy, closeTo(expectedOffset.dy, 0.1));

      await wt.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('shows suggestions on Ctrl+Space', (WidgetTester wt) async {
      final controller = createController('wid');
      final focusNode = FocusNode();
      controller.autocompleter.setCustomWords(['widgetBuilder']);

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeField(
              controller: controller,
              focusNode: focusNode,
              decoration: const BoxDecoration(),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      controller.setCursor(0);
      await wt.pump();

      await wt.sendKeyDownEvent(LogicalKeyboardKey.control);
      await wt.sendKeyEvent(LogicalKeyboardKey.space);
      await wt.sendKeyUpEvent(LogicalKeyboardKey.control);
      await wt.pump();
      await wt.pump();

      expect(controller.text, 'wid');
      expect(find.byType(Popup), findsOneWidget);
      expect(find.text('widgetBuilder'), findsOneWidget);

      await wt.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('applies selected suggestion on Enter after Ctrl+Space',
        (WidgetTester wt) async {
      final controller = createController('wid');
      final focusNode = FocusNode();
      controller.autocompleter.setCustomWords(['widgetBuilder']);

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeField(
              controller: controller,
              focusNode: focusNode,
              decoration: const BoxDecoration(),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      controller.setCursor(0);
      await wt.pump();

      await wt.sendKeyDownEvent(LogicalKeyboardKey.control);
      await wt.sendKeyEvent(LogicalKeyboardKey.space);
      await wt.sendKeyUpEvent(LogicalKeyboardKey.control);
      await wt.pump();
      await wt.pump();

      await wt.sendKeyEvent(LogicalKeyboardKey.enter);
      await wt.pump();

      expect(controller.text, 'widgetBuilder ');
      expect(find.byType(Popup), findsNothing);

      await wt.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('applies suggestion on single click', (WidgetTester wt) async {
      final controller = createController('wid');
      final focusNode = FocusNode();
      controller.autocompleter.setCustomWords(['widgetBuilder']);

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeField(
              controller: controller,
              focusNode: focusNode,
              decoration: const BoxDecoration(),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      controller.setCursor(0);
      await wt.pump();

      await wt.sendKeyDownEvent(LogicalKeyboardKey.control);
      await wt.sendKeyEvent(LogicalKeyboardKey.space);
      await wt.sendKeyUpEvent(LogicalKeyboardKey.control);
      await wt.pump();
      await wt.pump();

      await wt.tap(find.text('widgetBuilder'));
      await wt.pump();

      expect(controller.text, 'widgetBuilder ');
      expect(find.byType(Popup), findsNothing);

      await wt.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('keeps popup open when arrowing past fourth suggestion',
        (WidgetTester wt) async {
      final controller = createController('wo');
      final focusNode = FocusNode();
      controller.autocompleter.setCustomWords([
        'word0',
        'word1',
        'word2',
        'word3',
        'word4',
        'word5',
        'word6',
      ]);

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodeField(
              controller: controller,
              focusNode: focusNode,
              decoration: const BoxDecoration(),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await wt.pump();

      await wt.sendKeyDownEvent(LogicalKeyboardKey.control);
      await wt.sendKeyEvent(LogicalKeyboardKey.space);
      await wt.sendKeyUpEvent(LogicalKeyboardKey.control);
      await wt.pump();
      await wt.pump();

      for (var i = 0; i < 5; i++) {
        await wt.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await wt.pump();
      }
      await wt.pump();

      expect(find.byType(Popup), findsOneWidget);
      expect(controller.popupController.shouldShow, isTrue);
      expect(controller.popupController.selectedIndex, 5);
      expect(
        controller.popupController.itemPositionsListener.itemPositions.value
            .map((item) => item.index),
        contains(5),
      );

      await wt.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focusNode.dispose();
    });
  });
}
