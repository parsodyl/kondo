import 'dart:async';

import 'package:hako/hako.dart';

import 'kondo_hako_events.dart';

/// A base class for Hakos used in the Kondo architecture pattern.
///
/// **Important**: When using the Kondo architecture, you should extend one of
/// the `KondoHako` variants ([KondoHako], [IKondoHako], [RKondoHako], or
/// [IRKondoHako]) rather than extending [Hako] or [BaseHako] directly.
/// These variants provide the architectural foundation and lifecycle hooks
/// specific to the Kondo pattern.
///
/// It provides the foundation for simple state containers that need only
/// state management without additional architectural layers.
///
/// **KondoHako** serves as the orchestrator in the Kondo architecture. It:
/// * Holds and manages UI state
/// * Provides lifecycle hooks for initialization
/// * Offers helpers for managing stream subscriptions
/// * Automatically cleans up resources on disposal
///
/// This base variant is suitable for simple features that don't require
/// business logic or side effects. For more complex use cases, consider using
/// specialized versions:
/// * [IKondoHako] - when you need an Interactor for business logic
/// * [RKondoHako] - when you need a Reactor for side effects
/// * [IRKondoHako] - when you need both Interactor and Reactor
///
/// All variants extend this base class and inherit the stream subscription
/// helpers and automatic cleanup on dispose.
///
/// Example:
/// ```dart
/// class MyHako extends KondoHako {
///   MyHako() : super((register) {
///     register<MyState>(const MyState(isVisible: false));
///   });
///
///   void onVisibilityToggled() {
///     set<MyState>(
///       (current) => current.copyWith(isVisible: !current.isVisible),
///     );
///   }
/// }
/// ```
abstract class KondoHako extends BaseHako {
  /// Constructs a [KondoHako].
  ///
  /// The positional argument is a `StateRegistrar` callback used to register
  /// initial state objects:
  ///
  /// ```dart
  /// MyHako() : super((register) {
  ///   register<CounterState>(const CounterState(0));
  /// });
  /// ```
  KondoHako(super.registrar);

  final _subscriptions = <StreamSubscription<dynamic>>[];

  void _cancelAllSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// A lifecycle hook called after the Hako is initialized.
  ///
  /// Override this method to perform initialization logic such as:
  /// * Loading data from the interactor
  /// * Performing async initialization tasks
  ///
  /// This method is automatically called by [KondoProvider] after the first
  /// frame is rendered, ensuring the widget tree is ready before any
  /// initialization logic runs.
  FutureOr<void> onReady() {}

  /// Connects a stream to the Hako's state management.
  ///
  /// This helper method subscribes to a [stream] and automatically updates
  /// the state of type [T] when new events are emitted. The subscription is
  /// managed internally and will be automatically cancelled when the Hako is
  /// disposed.
  ///
  /// The ideal place to call this method is in the Hako's constructor for
  /// immediate subscription, or in [onReady] if you want to ensure the first
  /// frame is rendered before starting the subscription.
  ///
  /// By design, individual subscriptions cannot be canceled independently —
  /// all stream lifecycle management is unified and handled internally when
  /// the Hako is disposed.
  void connectStream<T>({
    required Stream<T> stream,
    T Function(T current, T event)? onEvent,
    Function? onError,
    void Function()? onDone,
    String? name,
  }) {
    final subscription = stream.listen(
      (event) => set<T>(
        (current) => onEvent != null ? onEvent(current, event) : event,
        name: name,
      ),
      onError: onError,
      onDone: onDone,
    );
    _subscriptions.add(subscription);
  }

  /// Maps a stream of type [T] to the Hako's state of type [S].
  ///
  /// This helper method subscribes to a [stream] and uses the [mapper] function
  /// to transform incoming events (and the current state) into a new state.
  /// The subscription is managed internally and will be automatically cancelled
  /// when the Hako is disposed.
  ///
  /// The ideal place to call this method is in the Hako's constructor for
  /// immediate subscription, or in [onReady] if you want to ensure the first
  /// frame is rendered before starting the subscription.
  ///
  /// By design, individual subscriptions cannot be canceled independently —
  /// all stream lifecycle management is unified and handled internally when
  /// the Hako is disposed.
  void mapStream<T, S>({
    required Stream<T> stream,
    required S Function(S current, T event) mapper,
    Function? onError,
    void Function()? onDone,
    String? name,
  }) {
    final subscription = stream.listen(
      (event) => set<S>(
        (current) => mapper(current, event),
        name: name,
      ),
      onError: onError,
      onDone: onDone,
    );
    _subscriptions.add(subscription);
  }

  /// Listens to a stream without automatically updating state.
  ///
  /// This helper method subscribes to a [stream] and invokes the [onData]
  /// callback when new events are emitted. Unlike [connectStream], this method
  /// does not automatically update the Hako's state, giving you full control
  /// over how to handle the events. The subscription is managed internally and
  /// will be automatically cancelled when the Hako is disposed.
  ///
  /// The ideal place to call this method is in the Hako's constructor for
  /// immediate subscription, or in [onReady] if you want to ensure the first
  /// frame is rendered before starting the subscription.
  ///
  /// By design, individual subscriptions cannot be canceled independently —
  /// all stream lifecycle management is unified and handled internally when
  /// the Hako is disposed.
  void listenStream<T>({
    required Stream<T> stream,
    required void Function(T event) onData,
    Function? onError,
    void Function()? onDone,
  }) {
    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
    );
    _subscriptions.add(subscription);
  }

  @override
  void dispose() {
    if (_subscriptions.isNotEmpty) {
      _cancelAllSubscriptions();
    }
    super.dispose();
  }
}

/// A KondoHako variant with an Interactor for business logic.
///
/// This class extends [KondoHako] to include an Interactor component, which
/// handles the business logic layer of your feature. The Interactor is a
/// stateless component that:
/// * Performs calculations and data transformations
/// * Communicates with repositories and services
/// * Acts as an adapter between your data layer and feature logic
/// * Provides streams for reactive data sources
///
/// The Interactor is accessible through the [interactor] getter, which
/// automatically emits an [InteractorEvent] for debugging and tracking
/// purposes.
///
/// Type Parameters:
/// * [I] - The type of the Interactor
///
/// Example:
/// ```dart
/// class MyHako extends IKondoHako<MyInteractor> {
///   MyHako({required super.interactor}) : super((registrar) {
///     register<MyState>(const MyState());
///   });
///
///   @override
///   FutureOr<void> onReady() async {
///     final data = await interactor.fetchData();
///     set<MyState>((current) => current.copyWith(data: data));
///   }
/// }
/// ```
abstract class IKondoHako<I> extends KondoHako with _InteractorGetterMixin<I> {
  /// Constructs an [IKondoHako] with the required [interactor].
  IKondoHako(
    super.registrar, {
    required I interactor,
  }) : _interactor = interactor;

  @override
  final I _interactor;
}

/// A KondoHako variant with a Reactor for side effects.
///
/// This class extends [KondoHako] to include a Reactor component, which
/// handles side effects that affect the app environment rather than the UI
/// state. The Reactor is an abstract interface that:
/// * Defines contracts for navigation between screens
/// * Manages dialogs and bottom sheets
/// * Triggers system-level actions
/// * Handles any context-dependent operations
///
/// The Reactor is accessible through the [reactor] getter, which
/// automatically emits a [ReactorEvent] for debugging and tracking purposes.
///
/// Type Parameters:
/// * [R] - The type of the Reactor
///
/// Example:
/// ```dart
/// class MyHako extends RKondoHako<MyReactor> {
///   MyHako({required super.reactor}) : super((registrar) {
///     register<MyState>(const MyState());
///   });
///
///   void onForwardTap() {
///     reactor.navigateToNextScreen();
///   }
/// }
/// ```
abstract class RKondoHako<R> extends KondoHako with _ReactorGetterMixin<R> {
  /// Constructs an [RKondoHako] with the required [reactor].
  RKondoHako(
    super.registrar, {
    required R reactor,
  }) : _reactor = reactor;

  @override
  final R _reactor;
}

/// A KondoHako variant with both an Interactor and a Reactor.
///
/// This class extends [KondoHako] to include both an Interactor for business
/// logic and a Reactor for side effects, forming a complete Kondo Triad:
/// * **Hako** - The orchestrator holding UI state and coordinating between
///   components
/// * **Interactor** - The business logic layer handling data and domain rules
/// * **Reactor** - The side effects layer managing navigation and
///   context-dependent actions
///
/// This is the most feature-complete variant and is ideal for complex features
/// that require both business logic processing and side effect management.
///
/// Both the [interactor] and [reactor] are accessible through their respective
/// getters, which automatically emit tracking events for debugging purposes.
///
/// Type Parameters:
/// * [I] - The type of the Interactor
/// * [R] - The type of the Reactor
///
/// Example:
/// ```dart
/// class MyHako extends IRKondoHako<MyInteractor, MyReactor> {
///   MyHako({
///     required super.interactor,
///     required super.reactor,
///   }) : super((registrar) {
///     register<MyState>(const MyState());
///   });
///
///   Future<void> onSubmitTap() async {
///     final result = await interactor.processData();
///     if (result.isSuccess) {
///       reactor.navigateToSuccessScreen();
///     } else {
///       reactor.showErrorDialog();
///     }
///   }
/// }
/// ```
abstract class IRKondoHako<I, R> extends KondoHako
    with _InteractorGetterMixin<I>, _ReactorGetterMixin<R> {
  /// Constructs an [IRKondoHako] with the required [interactor] and [reactor].
  IRKondoHako(
    super.registrar, {
    required I interactor,
    required R reactor,
  })  : _interactor = interactor,
        _reactor = reactor;

  @override
  final I _interactor;
  @override
  final R _reactor;
}

mixin _InteractorGetterMixin<I> on KondoHako {
  I get _interactor;

  /// Provides access to the [interactor] instance, emitting a tracking event
  /// of type [InteractorEvent].
  I get interactor {
    onEvent(const InteractorEvent());
    return _interactor;
  }
}

mixin _ReactorGetterMixin<R> on KondoHako {
  R get _reactor;

  /// Provides access to the [reactor] instance, emitting a tracking event
  /// of type [ReactorEvent].
  R get reactor {
    onEvent(const ReactorEvent());
    return _reactor;
  }
}
