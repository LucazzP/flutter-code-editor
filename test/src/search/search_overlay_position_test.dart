import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_code_editor/src/search/widget/search_widget.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';

void main() {
  testWidgets(
    'search overlay is shown at the code field bottom-right when space allows',
    (wt) async {
      final controller = createController('class Example {}');
      final focusNode = FocusNode();

      await wt.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 500,
                height: 220,
                child: CodeField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const BoxDecoration(),
                ),
              ),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await wt.pump();

      controller.showSearch();
      await wt.pump();

      final codeFieldRect = wt.getRect(find.byType(CodeField));
      final searchRect = wt.getRect(find.byType(SearchWidget));

      expect(searchRect.right, closeTo(codeFieldRect.right - 10, 2));
      expect(searchRect.bottom, closeTo(codeFieldRect.bottom - 10, 2));

      await wt.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      focusNode.dispose();
    },
  );
}
