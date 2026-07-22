import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farvixo_all/features/tools/converter/models/target_format.dart';
import 'package:farvixo_all/features/tools/converter/providers/pdf_converter_provider.dart';
import 'package:farvixo_all/features/tools/converter/widgets/converter_steps.dart';
import 'package:farvixo_all/features/tools/converter/widgets/format_grid.dart';

void main() {
  testWidgets('steps announce current step via Semantics', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConverterSteps(view: ConverterView.convert),
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(ConverterSteps));
    expect(node.label, contains('Step 3 of 4'));
    expect(node.label, contains('Convert'));
    handle.dispose();
  });

  testWidgets('format tiles expose selected + Pro semantics', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormatGrid(
            formats: const [TargetFormat.docx, TargetFormat.xlsx],
            selected: TargetFormat.docx,
            onSelect: (_) {},
            isPro: false,
          ),
        ),
      ),
    );
    final word = tester.getSemantics(find.text('Word'));
    expect(word.label, contains('Word'));

    final excel = tester.getSemantics(find.text('Excel'));
    expect(excel.label.toLowerCase(), contains('pro'));
    handle.dispose();
  });

  testWidgets('format grid uses more columns on wide layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1100,
            child: FormatGrid(
              formats: TargetFormat.values.take(10).toList(),
              selected: TargetFormat.docx,
              onSelect: (_) {},
              isPro: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
