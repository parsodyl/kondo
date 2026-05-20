import 'package:hako/hako.dart';

/// Base class for Kondo-specific events within a Hako state container.
///
/// This abstract class extends [HakoEvent] and provides common functionality
/// for events used in the Kondo architecture pattern. All Kondo events can
/// optionally include a [label] for identification and debugging purposes.
///
/// Equality is determined by the runtime type, meaning two events of the
/// same type are considered equal regardless of their label values.
///
/// See also:
/// * [InteractorEvent], which represents events triggered by interactors.
/// * [ReactorEvent], which represents events triggered by reactors.
abstract class KondoHakoEvent extends HakoEvent {
  /// Constructs a [KondoHakoEvent] with an optional [label].
  ///
  /// The [label] can be used to identify or describe the event for
  /// debugging and logging purposes.
  const KondoHakoEvent([this.label]);

  /// An optional label for identifying or describing this event.
  ///
  /// This is particularly useful for debugging and logging to distinguish
  /// between multiple instances of the same event type.
  final String? label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is KondoHakoEvent && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Represents an event triggered by an interactor.
///
/// Interactor events are typically dispatched when an interactor component
/// performs an action or operation within the Kondo architecture.
///
/// This event can be constructed with or without a label using the default
/// constructor or [InteractorEvent.withLabel] respectively.
class InteractorEvent extends KondoHakoEvent {
  /// Constructs an [InteractorEvent] without a label.
  const InteractorEvent();

  /// Constructs an [InteractorEvent] with the specified [label].
  ///
  /// The [label] can be used to identify the specific interactor or
  /// action that triggered this event.
  const InteractorEvent.withLabel(super.label);

  @override
  String toString() {
    return 'InteractorEvent${label != null ? '{label: $label}' : ''}';
  }
}

/// Represents an event triggered by a reactor.
///
/// Reactor events are typically dispatched when a reactor component
/// responds to state changes or performs side effects within the Kondo
/// architecture.
///
/// This event can be constructed with or without a label using the default
/// constructor or [ReactorEvent.withLabel] respectively.
class ReactorEvent extends KondoHakoEvent {
  /// Constructs a [ReactorEvent] without a label.
  const ReactorEvent();

  /// Constructs a [ReactorEvent] with the specified [label].
  ///
  /// The [label] can be used to identify the specific reactor or
  /// reaction that triggered this event.
  const ReactorEvent.withLabel(super.label);

  @override
  String toString() {
    return 'ReactorEvent${label != null ? '{label: $label}' : ''}';
  }
}