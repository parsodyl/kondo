import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kondo/kondo.dart';
import 'package:provider/provider.dart';

// --- Fakes ---

class FakeService {
  const FakeService(this.name);
  final String name;
}

class FakeDependencyResolver implements KondoDependencyResolver {
  final _instances = <Type, Object>{};
  bool dismantleCalled = false;

  void register<T extends Object>(T instance) {
    _instances[T] = instance;
  }

  @override
  T resolve<T>() {
    final instance = _instances[T];
    if (instance == null) {
      throw StateError('No instance registered for type $T');
    }
    return instance as T;
  }

  @override
  FutureOr<void> dismantle() {
    dismantleCalled = true;
  }
}

void main() {
  group('KondoDependencyResolver', () {
    test('resolve returns registered instances', () {
      final resolver = FakeDependencyResolver()
        ..register(const FakeService('test'));

      expect(resolver.resolve<FakeService>().name, 'test');
    });
  });

  group('KondoDependencyProvider', () {
    testWidgets('makes resolver accessible via context', (tester) async {
      final resolver = FakeDependencyResolver()
        ..register(const FakeService('injected'));

      late FakeService resolvedService;
      await tester.pumpWidget(
        KondoDependencyProvider(
          createResolver: (_) => resolver,
          child: Builder(builder: (context) {
            resolvedService = context.resolveDependency<FakeService>();
            return const SizedBox();
          }),
        ),
      );

      expect(resolvedService.name, 'injected');
    });

    testWidgets('calls dismantle on dispose', (tester) async {
      final resolver = FakeDependencyResolver();

      await tester.pumpWidget(
        KondoDependencyProvider(
          createResolver: (_) => resolver,
          child: Builder(builder: (context) {
            // Access the resolver to ensure Provider has created it.
            context.read<KondoDependencyResolver>();
            return const SizedBox();
          }),
        ),
      );

      expect(resolver.dismantleCalled, isFalse);

      // Remove the provider from the tree.
      await tester.pumpWidget(const SizedBox());

      expect(resolver.dismantleCalled, isTrue);
    });
  });

  group('KondoDependencyProvider.value', () {
    testWidgets('makes resolver accessible via context', (tester) async {
      final resolver = FakeDependencyResolver()
        ..register(const FakeService('existing'));

      late FakeService resolvedService;
      await tester.pumpWidget(
        KondoDependencyProvider.value(
          value: resolver,
          child: Builder(builder: (context) {
            resolvedService = context.resolveDependency<FakeService>();
            return const SizedBox();
          }),
        ),
      );

      expect(resolvedService.name, 'existing');
    });

    testWidgets('does NOT call dismantle on dispose', (tester) async {
      final resolver = FakeDependencyResolver();

      await tester.pumpWidget(
        KondoDependencyProvider.value(
          value: resolver,
          child: const SizedBox(),
        ),
      );

      await tester.pumpWidget(const SizedBox());

      expect(resolver.dismantleCalled, isFalse);
    });
  });

  group('resolveDependency extension', () {
    testWidgets('resolves correct type from context', (tester) async {
      final resolver = FakeDependencyResolver()
        ..register(const FakeService('via-extension'));

      late FakeService resolved;
      await tester.pumpWidget(
        KondoDependencyProvider(
          createResolver: (_) => resolver,
          child: Builder(builder: (context) {
            resolved = context.resolveDependency<FakeService>();
            return const SizedBox();
          }),
        ),
      );

      expect(resolved.name, 'via-extension');
    });
  });
}
