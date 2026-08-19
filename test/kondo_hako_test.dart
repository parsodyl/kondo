import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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

  void connectToStream(Stream<CounterState> stream) {
    connectStream<CounterState>(stream: stream);
  }

  void connectToStreamWithMerger(
    Stream<CounterState> stream,
    CounterState Function(CounterState current, CounterState event) merger,
  ) {
    connectStream<CounterState>(stream: stream, onEvent: merger);
  }

  void listenToStream<T>(Stream<T> stream, void Function(T) onData) {
    listenStream<T>(stream: stream, onData: onData);
  }

  void mapStreamToState<T, S>(
    Stream<T> stream,
    S Function(S current, T event) mapper,
  ) {
    mapStream<T, S>(stream: stream, mapper: mapper);
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
    test('registers and retrieves state', () {
      final hako = TestKondoHako();
      expect(hako.getCounterState().count, 0);
      hako.dispose();
    });

    test('updates state via set', () {
      final hako = TestKondoHako();
      hako.updateCounter(5);
      expect(hako.getCounterState().count, 5);
      hako.dispose();
    });

    test('onReady is callable', () {
      final hako = TestKondoHako();
      hako.onReady();
      expect(hako.onReadyCalled, isTrue);
      hako.dispose();
    });

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
    test('updates state when stream emits', () async {
      final hako = TestKondoHako();
      final controller = StreamController<CounterState>();

      hako.connectToStream(controller.stream);

      controller.add(const CounterState(42));
      await Future<void>.delayed(Duration.zero);

      expect(hako.getCounterState().count, 42);

      await controller.close();
      hako.dispose();
    });

    test('uses onEvent merger when provided', () async {
      final hako = TestKondoHako();
      final controller = StreamController<CounterState>();

      hako.connectToStreamWithMerger(
        controller.stream,
        (current, event) => CounterState(current.count + event.count),
      );

      controller.add(const CounterState(10));
      await Future<void>.delayed(Duration.zero);

      expect(hako.getCounterState().count, 10);

      controller.add(const CounterState(5));
      await Future<void>.delayed(Duration.zero);

      expect(hako.getCounterState().count, 15);

      await controller.close();
      hako.dispose();
    });

    test('cancels subscription on dispose', () async {
      final hako = TestKondoHako();
      final controller = StreamController<CounterState>();

      hako.connectToStream(controller.stream);
      hako.dispose();

      expect(controller.hasListener, isFalse);

      await controller.close();
    });
  });

  group('mapStream', () {
    test('updates state using mapper when stream emits', () async {
      final hako = TestKondoHako();
      final controller = StreamController<int>();

      hako.mapStreamToState<int, CounterState>(
        controller.stream,
        (current, event) => CounterState(current.count + event),
      );

      controller.add(10);
      await Future<void>.delayed(Duration.zero);

      expect(hako.getCounterState().count, 10);

      controller.add(5);
      await Future<void>.delayed(Duration.zero);

      expect(hako.getCounterState().count, 15);

      await controller.close();
      hako.dispose();
    });

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
  });

  group('IKondoHako', () {
    test('exposes interactor', () {
      final interactor = FakeInteractor();
      final hako = TestIKondoHako(interactor: interactor);

      expect(hako.interactor, same(interactor));
      hako.dispose();
    });

    test('emits InteractorEvent on interactor access', () {
      final hako = TestIKondoHako(interactor: FakeInteractor());
      final stream = hako.openEventStream();

      hako.interactor;
      hako.closeEventStream();

      expect(
        stream,
        emitsInOrder([
          isA<InteractorEvent>(),
          emitsDone,
        ]),
      );
    });
  });

  group('RKondoHako', () {
    test('exposes reactor', () {
      final reactor = FakeReactor();
      final hako = TestRKondoHako(reactor: reactor);

      expect(hako.reactor, same(reactor));
      hako.dispose();
    });

    test('emits ReactorEvent on reactor access', () {
      final hako = TestRKondoHako(reactor: FakeReactor());
      final stream = hako.openEventStream();

      hako.reactor;
      hako.closeEventStream();

      expect(
        stream,
        emitsInOrder([
          isA<ReactorEvent>(),
          emitsDone,
        ]),
      );
    });
  });

  group('IRKondoHako', () {
    test('exposes both interactor and reactor', () {
      final interactor = FakeInteractor();
      final reactor = FakeReactor();
      final hako = TestIRKondoHako(
        interactor: interactor,
        reactor: reactor,
      );

      expect(hako.interactor, same(interactor));
      expect(hako.reactor, same(reactor));
      hako.dispose();
    });

    test('emits correct events for each getter', () {
      final hako = TestIRKondoHako(
        interactor: FakeInteractor(),
        reactor: FakeReactor(),
      );
      final stream = hako.openEventStream();

      hako.interactor;
      hako.reactor;
      hako.closeEventStream();

      expect(
        stream,
        emitsInOrder([
          isA<InteractorEvent>(),
          isA<ReactorEvent>(),
          emitsDone,
        ]),
      );
    });
  });
}
