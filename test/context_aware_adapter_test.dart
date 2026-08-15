import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kondo/kondo.dart';

class TestAdapter extends ContextAwareAdapter {
  TestAdapter({required super.contextResolver});
}

void main() {
  group('maybeContext', () {
    testWidgets('returns context when widget is mounted', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        Builder(builder: (context) {
          capturedContext = context;
          return const SizedBox();
        }),
      );

      final adapter = TestAdapter(contextResolver: () => capturedContext);
      expect(adapter.maybeContext, isNotNull);
    });

    testWidgets('returns null when widget is unmounted', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        Builder(builder: (context) {
          capturedContext = context;
          return const SizedBox();
        }),
      );

      // Remove the widget from the tree, making the old context unmounted.
      await tester.pumpWidget(const SizedBox());

      final adapter = TestAdapter(contextResolver: () => capturedContext);
      expect(adapter.maybeContext, isNull);
    });
  });

  group('getFromContext', () {
    testWidgets('returns extracted value when mounted', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(builder: (context) {
            capturedContext = context;
            return const SizedBox();
          }),
        ),
      );

      final adapter = TestAdapter(contextResolver: () => capturedContext);
      final result = adapter.getFromContext(
        (context) => Directionality.of(context),
      );
      expect(result, TextDirection.ltr);
    });

    testWidgets('returns null when unmounted', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        Builder(builder: (context) {
          capturedContext = context;
          return const SizedBox();
        }),
      );

      await tester.pumpWidget(const SizedBox());

      final adapter = TestAdapter(contextResolver: () => capturedContext);
      final result = adapter.getFromContext((_) => 'value');
      expect(result, isNull);
    });
  });

  group('tryRun', () {
    testWidgets('executes action and returns result when mounted',
        (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        Builder(builder: (context) {
          capturedContext = context;
          return const SizedBox();
        }),
      );

      final adapter = TestAdapter(contextResolver: () => capturedContext);
      var executed = false;
      final result = adapter.tryRun<String>((context) {
        executed = true;
        return 'done';
      });
      expect(executed, isTrue);
      expect(result, 'done');
    });

    testWidgets('skips action and returns null when unmounted',
        (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        Builder(builder: (context) {
          capturedContext = context;
          return const SizedBox();
        }),
      );

      await tester.pumpWidget(const SizedBox());

      final adapter = TestAdapter(contextResolver: () => capturedContext);
      var executed = false;
      final result = adapter.tryRun<String>((context) {
        executed = true;
        return 'done';
      });
      expect(executed, isFalse);
      expect(result, isNull);
    });

    testWidgets('works with async actions when mounted', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        Builder(builder: (context) {
          capturedContext = context;
          return const SizedBox();
        }),
      );

      final adapter = TestAdapter(contextResolver: () => capturedContext);
      final result = await adapter.tryRun<String>((context) async {
        return 'async done';
      });
      expect(result, 'async done');
    });
  });
}
