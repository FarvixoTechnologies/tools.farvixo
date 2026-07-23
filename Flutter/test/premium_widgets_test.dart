import 'package:farvixo_all/widgets/premium/premium.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('ToolIdentity', () {
    testWidgets('is deterministic and distinct per tool', (tester) async {
      late Color mergeA;
      late Color mergeB;
      late Color split;
      await tester.pumpWidget(host(Builder(builder: (context) {
        mergeA = ToolIdentity.of('merge-pdf', categoryId: 'pdf')
            .accent(context);
        mergeB = ToolIdentity.of('merge-pdf', categoryId: 'pdf')
            .accent(context);
        split = ToolIdentity.of('split-pdf', categoryId: 'pdf')
            .accent(context);
        return const SizedBox.shrink();
      })));
      expect(mergeA, mergeB); // stable across lookups
      expect(mergeA == split, isFalse); // unique per tool
    });

    testWidgets('confetti palette has 5 colors', (tester) async {
      await tester.pumpWidget(host(Builder(builder: (context) {
        final colors = ToolIdentity.of('image-compressor',
                categoryId: 'image')
            .confettiColors(context);
        expect(colors, hasLength(5));
        return const SizedBox.shrink();
      })));
    });
  });

  group('AnimatedCount', () {
    testWidgets('settles on the target value', (tester) async {
      await tester.pumpWidget(host(AnimatedCount(value: 68, suffix: '%')));
      await tester.pumpAndSettle();
      expect(find.text('68%'), findsOneWidget);
    });
  });

  group('PremiumProgressRing', () {
    testWidgets('renders the rolling percent', (tester) async {
      await tester.pumpWidget(host(const Center(
        child: PremiumProgressRing(progress: 0.5, milestoneHaptics: false),
      )));
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
    });
  });

  group('ConfettiController', () {
    test('fire() bumps the generation', () {
      final c = ConfettiController();
      expect(c.generation, 0);
      c.fire();
      c.fire();
      expect(c.generation, 2);
    });
  });

  group('BeforeAfterSlider', () {
    testWidgets('shows both labels', (tester) async {
      await tester.pumpWidget(host(const BeforeAfterSlider(
        before: ColoredBox(color: Colors.black),
        after: ColoredBox(color: Colors.white),
      )));
      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
    });
  });

  group('TypewriterText', () {
    testWidgets('reveals the full text', (tester) async {
      await tester.pumpWidget(host(const TypewriterText(text: 'Farvixo')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Farvixo'), findsOneWidget);
    });
  });
}
