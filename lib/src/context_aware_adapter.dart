import 'dart:async';
import 'package:flutter/widgets.dart';

/// A base class for Reactor dependencies that need safe access to the
/// [BuildContext].
///
/// The [ContextAwareAdapter] acts as a bridge between pure logic (Reactor) and
/// the widget tree (Flutter). It ensures that operations are only performed
/// if the context is still mounted, preventing the common "Looking up a
/// deactivated widget's ancestor" crash.
///
/// ### Usage
/// Extend this class to create specific adapters like `PageNavigator`,
/// `DialogLauncher`, or `ToastManager`.
///
/// ```dart
/// class PageNavigator extends ContextAwareAdapter {
///   PageNavigator(super.contextResolver);
///
///   void pop() => tryRun((context) => Navigator.of(context).pop());
/// }
/// ```
abstract class ContextAwareAdapter {
  /// Creates a [ContextAwareAdapter] with a function that resolves the current
  /// context.
  ///
  /// The [contextResolver] is typically a closure capturing the context from
  /// the View's `build` method: `() => context`.
  const ContextAwareAdapter({required this.contextResolver});

  /// A function that returns the raw [BuildContext].
  ///
  /// **Note:** This does not guarantee that the context is valid. Use
  /// [maybeContext] for a safe, mounted-checked reference.
  final BuildContext Function() contextResolver;

  /// Returns the [BuildContext] if it is currently mounted, otherwise
  /// returns `null`.
  ///
  /// Use this to safely access the context without risking a "Deactivated
  /// Widget" exception.
  BuildContext? get maybeContext {
    final context = contextResolver();
    return context.mounted ? context : null;
  }

  /// Safely extracts data from the context (e.g., Theme, MediaQuery, Arguments).
  ///
  /// Returns `null` if the context is not mounted.
  ///
  /// ```dart
  /// final theme = getFromContext((c) => Theme.of(c));
  /// ```
  T? getFromContext<T>(T? Function(BuildContext context) getter) =>
      maybeContext != null ? getter(maybeContext!) : null;

  /// Safely executes an action using the context (e.g., Navigation, Dialogs).
  ///
  /// If the context is not mounted, the action is skipped and this
  /// returns `null`.
  ///
  /// Supports both synchronous and asynchronous actions.
  ///
  /// ```dart
  /// // Sync (Navigation)
  /// tryRun((c) => Navigator.of(c).pop());
  ///
  /// // Async (Dialog)
  /// await tryRun((c) => showDialog(context: c, ...));
  /// ```
  FutureOr<R?> tryRun<R>(FutureOr<R?> Function(BuildContext context) action) =>
      maybeContext != null ? action(maybeContext!) : null;
}
