import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farvixo_all/features/tools/converter/models/target_format.dart';
import 'package:farvixo_all/features/tools/converter/providers/pdf_converter_provider.dart';
import 'package:farvixo_all/features/tools/converter/widgets/converter_steps.dart';
import 'package:farvixo_all/features/tools/converter/widgets/format_grid.dart';

void main() {
  testWidgets('converter steps highlight analyze for review view',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConverterSteps(view: ConverterView.review),
        ),
      ),
    );
    expect(find.text('Analyze'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
  });

  testWidgets('format grid shows PRO on locked formats for free users',
      (tester) async {
    TargetFormat? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormatGrid(
            formats: const [TargetFormat.docx, TargetFormat.xlsx],
            selected: TargetFormat.docx,
            onSelect: (f) => picked = f,
            isPro: false,
          ),
        ),
      ),
    );
    expect(find.text('PRO'), findsOneWidget);
    await tester.tap(find.text('Word'));
    await tester.pump();
    expect(picked, TargetFormat.docx);
  });

  testWidgets('compare mode toggles selection via callback', (tester) async {
    final selected = <TargetFormat>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return FormatGrid(
                formats: const [TargetFormat.txt, TargetFormat.md],
                selected: null,
                onSelect: (_) {},
                isPro: true,
                compareMode: true,
                compareSelected: selected,
                onToggleCompare: (f) => setState(() {
                  if (!selected.add(f)) selected.remove(f);
                }),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Text'));
    await tester.pump();
    expect(selected, contains(TargetFormat.txt));
  });
}
