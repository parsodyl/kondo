import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kondo/kondo.dart';
import 'package:provider/provider.dart';

// --- Test State ---

class TestState {
  const TestState(this.value);
  final int value;
}

// --- Test Hako ---

class TestKondoHako extends KondoHako {
  TestKondoHako()
      : super((register) {
          register<TestState>(const TestState(0));
        });

  bool onReadyCalled = false;
  int onReadyCallCount = 0;
  bool wasDisposed = false;

  @override
  FutureOr<void> onReady() {
    onReadyCalled = true;
    onReadyCallCount++;
  }

  @override
  void dispose() {
    wasDisposed = true;
    super.dispose();
  }

  TestState getState() => get<TestState>();
}

void main() {
  group('KondoProvider', () {
    testWidgets('provides hako to descendants via readHako', (tester) async {
      late TestKondoHako readHako;
      await tester.pumpWidget(
        KondoProvider<TestKondoHako>(
          createHako: (_) => TestKondoHako(),
          builder: (context) {
            readHako = context.readHako<TestKondoHako>();
            return const SizedBox();
          },
        ),
      );

      expect(readHako, isA<TestKondoHako>());
      expect(readHako.getState().value, 0);
    });

    testWidgets('calls hako.onReady after first frame by default',
        (tester) async {
      late TestKondoHako readHako;
      await tester.pumpWidget(
        KondoProvider<TestKondoHako>(
          createHako: (_) => TestKondoHako(),
          builder: (context) {
            readHako = context.readHako<TestKondoHako>();
            return const SizedBox();
          },
        ),
      );

      // onReady is called via addPostFrameCallback, needs another pump.
      await tester.pump();

      expect(readHako.onReadyCalled, isTrue);
      expect(readHako.onReadyCallCount, 1);
    });

    testWidgets('custom onReady replaces default hako.onReady', (tester) async {
      late TestKondoHako readHako;
      var customOnReadyCalled = false;

      await tester.pumpWidget(
        KondoProvider<TestKondoHako>(
          createHako: (_) => TestKondoHako(),
          onReady: (hako) {
            customOnReadyCalled = true;
          },
          builder: (context) {
            readHako = context.readHako<TestKondoHako>();
            return const SizedBox();
          },
        ),
      );

      await tester.pump();

      expect(customOnReadyCalled, isTrue);
      expect(readHako.onReadyCalled, isFalse);
    });

    testWidgets('skipReady prevents any onReady call', (tester) async {
      late TestKondoHako readHako;

      await tester.pumpWidget(
        KondoProvider<TestKondoHako>(
          createHako: (_) => TestKondoHako(),
          skipReady: true,
          builder: (context) {
            readHako = context.readHako<TestKondoHako>();
            return const SizedBox();
          },
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(readHako.onReadyCalled, isFalse);
    });

    testWidgets('disposes hako when removed from tree', (tester) async {
      late TestKondoHako createdHako;

      await tester.pumpWidget(
        KondoProvider<TestKondoHako>(
          createHako: (_) {
            createdHako = TestKondoHako();
            return createdHako;
          },
          builder: (context) {
            context.readHako<TestKondoHako>();
            return const SizedBox();
          },
        ),
      );

      expect(createdHako.wasDisposed, isFalse);

      await tester.pumpWidget(const SizedBox());

      expect(createdHako.wasDisposed, isTrue);
    });

    testWidgets('calls onReady when used without builder inside MultiProvider',
        (tester) async {
      late TestKondoHako readHako;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            KondoProvider<TestKondoHako>(
              createHako: (_) => TestKondoHako(),
            ),
          ],
          child: Builder(
            builder: (context) {
              readHako = context.readHako<TestKondoHako>();
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pump();

      expect(readHako.onReadyCalled, isTrue);
      expect(readHako.onReadyCallCount, 1);
    });

    testWidgets(
        'does NOT call onReady if unmounted before post-frame callback runs',
        (tester) async {
      late TestKondoHako createdHako;
      final showProvider = ValueNotifier<bool>(true);
      addTearDown(showProvider.dispose);

      // Register a post-frame callback BEFORE KondoProvider mounts so that it
      // runs first in the post-frame queue and unmounts the widget tree before
      // _ReadyWidget's post-frame callback checks `context.mounted`.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showProvider.value = false;
        tester.binding.buildOwner!
          ..buildScope(tester.binding.rootElement!)
          ..finalizeTree();
      });

      await tester.pumpWidget(
        ValueListenableBuilder<bool>(
          valueListenable: showProvider,
          builder: (context, show, _) {
            if (!show) return const SizedBox();
            return KondoProvider<TestKondoHako>(
              createHako: (_) {
                createdHako = TestKondoHako();
                return createdHako;
              },
              builder: (_) => const SizedBox(),
            );
          },
        ),
      );

      expect(createdHako.onReadyCalled, isFalse);
      expect(createdHako.wasDisposed, isTrue);
    });
  });

  group('KondoProvider.value', () {
    testWidgets('provides existing hako to descendants', (tester) async {
      final existingHako = TestKondoHako();
      addTearDown(existingHako.dispose);

      late TestKondoHako readHako;
      await tester.pumpWidget(
        KondoProvider<TestKondoHako>.value(
          value: existingHako,
          builder: (context) {
            readHako = context.readHako<TestKondoHako>();
            return const SizedBox();
          },
        ),
      );

      expect(readHako, same(existingHako));
    });

    testWidgets('calls hako.onReady after first frame by default',
        (tester) async {
      final existingHako = TestKondoHako();
      addTearDown(existingHako.dispose);

      await tester.pumpWidget(
        KondoProvider<TestKondoHako>.value(
          value: existingHako,
          builder: (_) => const SizedBox(),
        ),
      );

      await tester.pump();

      expect(existingHako.onReadyCalled, isTrue);
      expect(existingHako.onReadyCallCount, 1);
    });

    testWidgets('custom onReady replaces default hako.onReady', (tester) async {
      final existingHako = TestKondoHako();
      addTearDown(existingHako.dispose);
      var customOnReadyCalled = false;

      await tester.pumpWidget(
        KondoProvider<TestKondoHako>.value(
          value: existingHako,
          onReady: (hako) {
            customOnReadyCalled = true;
          },
          builder: (_) => const SizedBox(),
        ),
      );

      await tester.pump();

      expect(customOnReadyCalled, isTrue);
      expect(existingHako.onReadyCalled, isFalse);
    });

    testWidgets('skipReady prevents any onReady call', (tester) async {
      final existingHako = TestKondoHako();
      addTearDown(existingHako.dispose);

      await tester.pumpWidget(
        KondoProvider<TestKondoHako>.value(
          value: existingHako,
          skipReady: true,
          builder: (_) => const SizedBox(),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(existingHako.onReadyCalled, isFalse);
    });

    testWidgets('calls onReady when used without builder inside MultiProvider',
        (tester) async {
      final existingHako = TestKondoHako();
      addTearDown(existingHako.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            KondoProvider<TestKondoHako>.value(
              value: existingHako,
            ),
          ],
          child: const SizedBox(),
        ),
      );

      await tester.pump();

      expect(existingHako.onReadyCalled, isTrue);
      expect(existingHako.onReadyCallCount, 1);
    });

    testWidgets('does NOT dispose hako when removed from tree', (tester) async {
      final existingHako = TestKondoHako();

      await tester.pumpWidget(
        KondoProvider<TestKondoHako>.value(
          value: existingHako,
          builder: (_) => const SizedBox(),
        ),
      );

      await tester.pumpWidget(const SizedBox());

      expect(existingHako.wasDisposed, isFalse);

      // Clean up manually since the provider didn't dispose it.
      existingHako.dispose();
    });

    testWidgets(
        'throws AssertionError when used outside MultiProvider without builder or child',
        (tester) async {
      final existingHako = TestKondoHako();

      await tester.pumpWidget(
        KondoProvider<TestKondoHako>.value(
          value: existingHako,
        ),
      );

      expect(tester.takeException(), isAssertionError);
      existingHako.dispose();
    });
  });

  group('KondoProvider assertions and lazy evaluation', () {
    testWidgets(
        'throws AssertionError when used outside MultiProvider without builder or child',
        (tester) async {
      await tester.pumpWidget(
        KondoProvider<TestKondoHako>(
          createHako: (_) => TestKondoHako(),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets(
        'when skipReady is true and lazy is default, does not instantiate hako until read',
        (tester) async {
      var createCalled = false;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        KondoProvider<TestKondoHako>(
          skipReady: true,
          createHako: (_) {
            createCalled = true;
            return TestKondoHako();
          },
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      );

      expect(createCalled, isFalse);

      capturedContext.readHako<TestKondoHako>();
      expect(createCalled, isTrue);
    });

    testWidgets(
        'when skipReady is true and lazy is false, instantiates hako immediately',
        (tester) async {
      var createCalled = false;

      await tester.pumpWidget(
        KondoProvider<TestKondoHako>(
          skipReady: true,
          lazy: false,
          createHako: (_) {
            createCalled = true;
            return TestKondoHako();
          },
          builder: (_) => const SizedBox(),
        ),
      );

      expect(createCalled, isTrue);
    });

    testWidgets(
        'when skipReady is false, lazy is forced to false and instantiates immediately',
        (tester) async {
      var createCalled = false;

      await tester.pumpWidget(
        KondoProvider<TestKondoHako>(
          skipReady: false,
          lazy: true, // overridden by !skipReady ? false
          createHako: (_) {
            createCalled = true;
            return TestKondoHako();
          },
          builder: (_) => const SizedBox(),
        ),
      );

      expect(createCalled, isTrue);
    });
  });
}
