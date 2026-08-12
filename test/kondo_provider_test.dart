import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kondo/kondo.dart';

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

    testWidgets('custom onReady replaces default hako.onReady',
        (tester) async {
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
  });

  group('KondoProvider.value', () {
    testWidgets('provides existing hako to descendants', (tester) async {
      final existingHako = TestKondoHako();

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

    testWidgets('does NOT dispose hako when removed from tree',
        (tester) async {
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
  });
}
