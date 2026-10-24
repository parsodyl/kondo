import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hako_test/hako_test.dart';
import 'package:kondo/kondo.dart';

// --- Test State ---

class CounterState {
  const CounterState(this.count);
  final int count;
}

// --- Fakes ---

class FakeInteractor {
  int increment(int value) => value + 1;
}

class FakeReactor {
  bool actionCalled = false;
  void doAction() => actionCalled = true;
}

// --- Test Hakos ---

class DefaultKondoHako extends KondoHako {
  DefaultKondoHako()
      : super((register) {
          register<CounterState>(const CounterState(0));
        });
}

class NamedStateKondoHako extends KondoHako {
  NamedStateKondoHako()
      : super((register) {
          register<CounterState>(
            const CounterState(0),
            name: 'custom_connect_stream',
          );
          register<CounterState>(
            const CounterState(0),
            name: 'custom_map_stream',
          );
        });

  CounterState getNamedState(String name) => get<CounterState>(name: name);

  void connectNamed(Stream<CounterState> stream, String name) {
    connectStream<CounterState>(stream: stream, name: name);
  }

  void mapNamed(Stream<int> stream, String name) {
    mapStream<int, CounterState>(
      stream: stream,
      mapper: (current, event) => CounterState(event),
      name: name,
    );
  }
}

class TestKondoHako extends KondoHako {
  TestKondoHako()
      : super((register) {
          register<CounterState>(const CounterState(0));
        });

  bool onReadyCalled = false;

  @override
  FutureOr<void> onReady() {
    onReadyCalled = true;
  }

  CounterState getCounterState() => get<CounterState>();

  void updateCounter(int value) {
    set<CounterState>((_) => CounterState(value));
  }

  void connectToStream(
    Stream<CounterState> stream, {
    Function? onError,
    void Function()? onDone,
    String? name,
  }) {
    connectStream<CounterState>(
      stream: stream,
      onError: onError,
      onDone: onDone,
      name: name,
    );
  }

  void connectToStreamWithMerger(
    Stream<CounterState> stream,
    CounterState Function(CounterState current, CounterState event) merger, {
    Function? onError,
    void Function()? onDone,
    String? name,
  }) {
    connectStream<CounterState>(
      stream: stream,
      onEvent: merger,
      onError: onError,
      onDone: onDone,
      name: name,
    );
  }

  void listenToStream<T>(
    Stream<T> stream,
    void Function(T) onData, {
    Function? onError,
    void Function()? onDone,
  }) {
    listenStream<T>(
      stream: stream,
      onData: onData,
      onError: onError,
      onDone: onDone,
    );
  }

  void mapStreamToState<T, S>(
    Stream<T> stream,
    S Function(S current, T event) mapper, {
    Function? onError,
    void Function()? onDone,
    String? name,
  }) {
    mapStream<T, S>(
      stream: stream,
      mapper: mapper,
      onError: onError,
      onDone: onDone,
      name: name,
    );
  }
}

class TestIKondoHako extends IKondoHako<FakeInteractor> {
  TestIKondoHako({required super.interactor})
      : super((register) {
          register<CounterState>(const CounterState(0));
        });

  CounterState getCounterState() => get<CounterState>();
}

class TestRKondoHako extends RKondoHako<FakeReactor> {
  TestRKondoHako({required super.reactor})
      : super((register) {
          register<CounterState>(const CounterState(0));
        });
}

class TestIRKondoHako extends IRKondoHako<FakeInteractor, FakeReactor> {
  TestIRKondoHako({
    required super.interactor,
    required super.reactor,
  }) : super((register) {
          register<CounterState>(const CounterState(0));
        });

  CounterState getCounterState() => get<CounterState>();

  void updateCounter(int value) {
    set<CounterState>((_) => CounterState(value));
  }
}

void main() {
  group('KondoHako', () {
    hakoTest<TestKondoHako>(
      'registers and retrieves state',
      build: () => TestKondoHako(),
      verify: (hako) {
        expect(hako.getCounterState().count, 0);
      },
    );

    hakoTest<TestKondoHako>(
      'updates state via set',
      build: () => TestKondoHako(),
      act: (hako) => hako.updateCounter(5),
      expect: () => [
        isSetEvent<CounterState>(),
      ],
      verify: (hako) {
        expect(hako.getCounterState().count, 5);
      },
    );

    hakoTest<TestKondoHako>(
      'onReady is callable and triggers overridden callback',
      build: () => TestKondoHako(),
      act: (hako) => hako.onReady(),
      verify: (hako) {
        expect(hako.onReadyCalled, isTrue);
      },
    );

    hakoTest<DefaultKondoHako>(
      'default base onReady executes without error',
      build: () => DefaultKondoHako(),
      act: (hako) => hako.onReady(),
      verify: (hako) {
        expect(hako.get<CounterState>().count, 0);
      },
    );

    test('calling set after dispose updates container value without error', () {
      final hako = TestKondoHako();
      hako.dispose();

      expect(() => hako.updateCounter(42), returnsNormally);
      expect(hako.getCounterState().count, 42);
    });

    test('in-flight async operation completing after dispose', () async {
      final hako = TestKondoHako();

      Future<void> asyncOperation() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        hako.updateCounter(99);
      }

      final future = asyncOperation();
      hako.dispose();
      await future;

      expect(hako.getCounterState().count, 99);
    });
  });

  group('connectStream', () {
    hakoTest<TestKondoHako>(
      'updates state when stream emits',
      build: () => TestKondoHako(),
      act: (hako) async {
        final controller = StreamController<CounterState>();
        hako.connectToStream(controller.stream);
        controller.add(const CounterState(42));
        await Future<void>.delayed(Duration.zero);
        await controller.close();
      },
      expect: () => [
        isSetEvent<CounterState>(),
      ],
      verify: (hako) {
        expect(hako.getCounterState().count, 42);
      },
    );

    hakoTest<NamedStateKondoHako>(
      'tags SetEvent with name when name parameter is provided',
      build: () => NamedStateKondoHako(),
      act: (hako) async {
        final controller = StreamController<CounterState>();
        hako.connectNamed(controller.stream, 'custom_connect_stream');
        controller.add(const CounterState(99));
        await Future<void>.delayed(Duration.zero);
        await controller.close();
      },
      expect: () => [
        isSetEvent<CounterState>(name: 'custom_connect_stream'),
      ],
      verify: (hako) {
        expect(hako.getNamedState('custom_connect_stream').count, 99);
      },
    );

    hakoTest<TestKondoHako>(
      'uses onEvent merger when provided',
      build: () => TestKondoHako(),
      act: (hako) async {
        final controller = StreamController<CounterState>();
        hako.connectToStreamWithMerger(
          controller.stream,
          (current, event) => CounterState(current.count + event.count),
        );
        controller.add(const CounterState(10));
        await Future<void>.delayed(Duration.zero);
        controller.add(const CounterState(5));
        await Future<void>.delayed(Duration.zero);
        await controller.close();
      },
      expect: () => [
        isSetEvent<CounterState>(),
        isSetEvent<CounterState>(),
      ],
      verify: (hako) {
        expect(hako.getCounterState().count, 15);
      },
    );

    test('cancels subscription on dispose', () async {
      final hako = TestKondoHako();
      final controller = StreamController<CounterState>();

      hako.connectToStream(controller.stream);
      hako.dispose();

      expect(controller.hasListener, isFalse);

      await controller.close();
    });

    test('forwards errors and completion to onError and onDone', () async {
      final hako = TestKondoHako();
      final controller = StreamController<CounterState>();
      Object? capturedError;
      var doneCalled = false;

      hako.connectToStream(
        controller.stream,
        onError: (Object error) => capturedError = error,
        onDone: () => doneCalled = true,
      );

      controller.addError(StateError('stream failure'));
      await Future<void>.delayed(Duration.zero);

      expect(capturedError, isA<StateError>());
      expect(doneCalled, isFalse);

      await controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(doneCalled, isTrue);
      hako.dispose();
    });

    test('forwards error and stackTrace when onError accepts two arguments',
        () async {
      final hako = TestKondoHako();
      final controller = StreamController<CounterState>();
      Object? capturedError;
      StackTrace? capturedStackTrace;

      hako.connectToStream(
        controller.stream,
        onError: (Object error, StackTrace stackTrace) {
          capturedError = error;
          capturedStackTrace = stackTrace;
        },
      );

      final error = StateError('stream failure with stack');
      final stackTrace = StackTrace.current;
      controller.addError(error, stackTrace);
      await Future<void>.delayed(Duration.zero);

      expect(capturedError, same(error));
      expect(capturedStackTrace, same(stackTrace));

      await controller.close();
      hako.dispose();
    });
  });

  group('mapStream', () {
    hakoTest<TestKondoHako>(
      'updates state using mapper when stream emits',
      build: () => TestKondoHako(),
      act: (hako) async {
        final controller = StreamController<int>();
        hako.mapStreamToState<int, CounterState>(
          controller.stream,
          (current, event) => CounterState(current.count + event),
        );
        controller.add(10);
        await Future<void>.delayed(Duration.zero);
        controller.add(5);
        await Future<void>.delayed(Duration.zero);
        await controller.close();
      },
      expect: () => [
        isSetEvent<CounterState>(),
        isSetEvent<CounterState>(),
      ],
      verify: (hako) {
        expect(hako.getCounterState().count, 15);
      },
    );

    hakoTest<NamedStateKondoHako>(
      'tags SetEvent with name when name parameter is provided',
      build: () => NamedStateKondoHako(),
      act: (hako) async {
        final controller = StreamController<int>();
        hako.mapNamed(controller.stream, 'custom_map_stream');
        controller.add(77);
        await Future<void>.delayed(Duration.zero);
        await controller.close();
      },
      expect: () => [
        isSetEvent<CounterState>(name: 'custom_map_stream'),
      ],
      verify: (hako) {
        expect(hako.getNamedState('custom_map_stream').count, 77);
      },
    );

    test('cancels subscription on dispose', () async {
      final hako = TestKondoHako();
      final controller = StreamController<int>();

      hako.mapStreamToState<int, CounterState>(
        controller.stream,
        (current, event) => CounterState(event),
      );
      hako.dispose();

      expect(controller.hasListener, isFalse);

      await controller.close();
    });

    test('forwards errors and completion to onError and onDone', () async {
      final hako = TestKondoHako();
      final controller = StreamController<int>();
      Object? capturedError;
      var doneCalled = false;

      hako.mapStreamToState<int, CounterState>(
        controller.stream,
        (current, event) => CounterState(event),
        onError: (Object error) => capturedError = error,
        onDone: () => doneCalled = true,
      );

      controller.addError(StateError('map failure'));
      await Future<void>.delayed(Duration.zero);

      expect(capturedError, isA<StateError>());
      expect(doneCalled, isFalse);

      await controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(doneCalled, isTrue);
      hako.dispose();
    });

    test('forwards error and stackTrace when onError accepts two arguments',
        () async {
      final hako = TestKondoHako();
      final controller = StreamController<int>();
      Object? capturedError;
      StackTrace? capturedStackTrace;

      hako.mapStreamToState<int, CounterState>(
        controller.stream,
        (current, event) => CounterState(event),
        onError: (Object error, StackTrace stackTrace) {
          capturedError = error;
          capturedStackTrace = stackTrace;
        },
      );

      final error = StateError('map failure with stack');
      final stackTrace = StackTrace.current;
      controller.addError(error, stackTrace);
      await Future<void>.delayed(Duration.zero);

      expect(capturedError, same(error));
      expect(capturedStackTrace, same(stackTrace));

      await controller.close();
      hako.dispose();
    });
  });

  group('listenStream', () {
    test('invokes onData callback on stream events', () async {
      final hako = TestKondoHako();
      final controller = StreamController<int>();
      final received = <int>[];

      hako.listenToStream<int>(controller.stream, received.add);

      controller.add(1);
      controller.add(2);
      controller.add(3);
      await Future<void>.delayed(Duration.zero);

      expect(received, [1, 2, 3]);

      await controller.close();
      hako.dispose();
    });

    test('cancels subscription on dispose', () async {
      final hako = TestKondoHako();
      final controller = StreamController<int>();
      final received = <int>[];

      hako.listenToStream<int>(controller.stream, received.add);

      controller.add(1);
      await Future<void>.delayed(Duration.zero);

      hako.dispose();

      controller.add(2);
      await Future<void>.delayed(Duration.zero);

      expect(received, [1]);
      expect(controller.hasListener, isFalse);

      await controller.close();
    });

    test('forwards errors and completion to onError and onDone', () async {
      final hako = TestKondoHako();
      final controller = StreamController<int>();
      Object? capturedError;
      var doneCalled = false;

      hako.listenToStream<int>(
        controller.stream,
        (_) {},
        onError: (Object error) => capturedError = error,
        onDone: () => doneCalled = true,
      );

      controller.addError(StateError('listen failure'));
      await Future<void>.delayed(Duration.zero);

      expect(capturedError, isA<StateError>());
      expect(doneCalled, isFalse);

      await controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(doneCalled, isTrue);
      hako.dispose();
    });

    test('forwards error and stackTrace when onError accepts two arguments',
        () async {
      final hako = TestKondoHako();
      final controller = StreamController<int>();
      Object? capturedError;
      StackTrace? capturedStackTrace;

      hako.listenToStream<int>(
        controller.stream,
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          capturedError = error;
          capturedStackTrace = stackTrace;
        },
      );

      final error = StateError('listen failure with stack');
      final stackTrace = StackTrace.current;
      controller.addError(error, stackTrace);
      await Future<void>.delayed(Duration.zero);

      expect(capturedError, same(error));
      expect(capturedStackTrace, same(stackTrace));

      await controller.close();
      hako.dispose();
    });
  });

  group('Multiple stream subscriptions cleanup', () {
    test('cancels all subscriptions of any type on dispose', () async {
      final hako = TestKondoHako();
      final c1 = StreamController<CounterState>();
      final c2 = StreamController<int>();
      final c3 = StreamController<String>();

      hako.connectToStream(c1.stream);
      hako.mapStreamToState<int, CounterState>(
        c2.stream,
        (current, event) => CounterState(event),
      );
      hako.listenToStream<String>(c3.stream, (_) {});

      expect(c1.hasListener, isTrue);
      expect(c2.hasListener, isTrue);
      expect(c3.hasListener, isTrue);

      hako.dispose();

      expect(c1.hasListener, isFalse);
      expect(c2.hasListener, isFalse);
      expect(c3.hasListener, isFalse);

      await c1.close();
      await c2.close();
      await c3.close();
    });
  });

  group('IKondoHako', () {
    final interactor = FakeInteractor();

    hakoTest<TestIKondoHako>(
      'exposes interactor',
      build: () => TestIKondoHako(interactor: interactor),
      verify: (hako) {
        expect(hako.interactor, same(interactor));
      },
    );

    hakoTest<TestIKondoHako>(
      'emits InteractorEvent on interactor access',
      build: () => TestIKondoHako(interactor: FakeInteractor()),
      act: (hako) => hako.interactor,
      expect: () => [
        isA<InteractorEvent>(),
      ],
    );
  });

  group('RKondoHako', () {
    final reactor = FakeReactor();

    hakoTest<TestRKondoHako>(
      'exposes reactor',
      build: () => TestRKondoHako(reactor: reactor),
      verify: (hako) {
        expect(hako.reactor, same(reactor));
      },
    );

    hakoTest<TestRKondoHako>(
      'emits ReactorEvent on reactor access',
      build: () => TestRKondoHako(reactor: FakeReactor()),
      act: (hako) => hako.reactor,
      expect: () => [
        isA<ReactorEvent>(),
      ],
    );
  });

  group('IRKondoHako', () {
    final interactor = FakeInteractor();
    final reactor = FakeReactor();

    hakoTest<TestIRKondoHako>(
      'exposes both interactor and reactor',
      build: () => TestIRKondoHako(
        interactor: interactor,
        reactor: reactor,
      ),
      verify: (hako) {
        expect(hako.interactor, same(interactor));
        expect(hako.reactor, same(reactor));
      },
    );

    hakoTest<TestIRKondoHako>(
      'emits correct events for each getter in order',
      build: () => TestIRKondoHako(
        interactor: FakeInteractor(),
        reactor: FakeReactor(),
      ),
      act: (hako) {
        hako.interactor;
        hako.reactor;
      },
      expect: () => [
        isA<InteractorEvent>(),
        isA<ReactorEvent>(),
      ],
    );
  });
}
