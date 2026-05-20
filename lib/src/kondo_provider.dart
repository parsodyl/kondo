import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hako/hako.dart';
import 'package:kondo/src/kondo_hako.dart';

/// A function type that creates a [KondoHako] instance.
///
/// Parameters:
/// * [context] - The [BuildContext] for accessing the widget tree
///
/// Returns a new instance of [KondoHako] subtype [H].
typedef CreateHako<H extends KondoHako> = H Function(BuildContext context);

/// A function type for initialization callbacks on [KondoHako] instances.
///
/// This callback is invoked during the initialization lifecycle of a
/// [KondoProvider], allowing custom initialization logic to be executed
/// after the Hako is created and the first frame is rendered.
///
/// Parameters:
/// * [hako] - The [KondoHako] instance to initialize
///
/// Returns a [FutureOr] to support both synchronous and asynchronous
/// initialization logic.
typedef OnKondoInit<H extends KondoHako> = FutureOr<void> Function(H hako);

/// A Provider widget that provides a [KondoHako] instance to its descendants
/// and manages its initialization lifecycle.
///
/// [KondoProvider] extends [HakoProvider] to add specialized initialization
/// support for the Kondo architecture pattern. It automatically handles the
/// initialization of [KondoHako] instances by calling their [KondoHako.onInit]
/// method after the first frame is rendered, ensuring the widget tree is
/// ready before initialization logic runs.
///
/// [KondoProvider] offers two constructors:
/// - The default constructor for creating new [KondoHako] instances
/// - The `.value` constructor for providing existing instances
///
/// When providing an existing instance using `.value`, the instance will not
/// be automatically disposed when the provider is removed from the widget tree.
///
/// ## Initialization Lifecycle
///
/// The initialization process follows these steps:
/// 1. The [KondoHako] instance is created (or provided)
/// 2. The widget tree is built
/// 3. After the first frame completes, the initialization callback is invoked
///
/// This ensures that the widget tree and [BuildContext] are fully available
/// before any initialization logic runs, which is critical for operations
/// that depend on the widget tree being mounted.
///
/// Type Parameters:
/// * [H] - The type of the [KondoHako] instance. Must extend [KondoHako].
///
/// Example:
/// ```dart
/// // Creating a new instance with initialization
/// KondoProvider<MyHako>(
///   createHako: (context) => MyHako(
///     interactor: MyInteractor(),
///     reactor: MyReactor(),
///   ),
///   builder: (context) => MyScreen(),
/// )
///
/// // Custom initialization callback
/// KondoProvider<MyHako>(
///   createHako: (context) => MyHako(),
///   onInit: (hako) async {
///     // ..do other stuff..
///     await hako.loadInitialData();
///   },
///   builder: (context) => MyScreen(),
/// )
///
/// // Providing an existing instance
/// KondoProvider<MyHako>.value(
///   value: existingHako,
///   builder: (context) => MyScreen(),
/// )
///
/// // Skip initialization when needed
/// KondoProvider<MyHako>(
///   createHako: (context) => MyHako(),
///   doNotInit: true,
///   builder: (context) => MyScreen(),
/// )
/// ```
class KondoProvider<H extends KondoHako> extends HakoProvider<H> {
  KondoProvider._create({
    required super.create,
    super.child,
    super.lazy,
    super.key,
  });

  KondoProvider._value({
    required super.value,
    super.child,
    super.key,
  }) : super.value();

  /// Creates a new [KondoProvider] that creates and provides a [KondoHako]
  /// instance to its descendants.
  ///
  /// The [createHako] factory function is called to instantiate the Hako.
  /// If [doNotInit] is `false` (the default), the Hako's [KondoHako.onInit]
  /// method will be automatically called after the first frame is rendered,
  /// unless a custom [onInit] callback is provided.
  ///
  /// Parameters:
  /// * [createHako] - A factory function that creates the [KondoHako] instance.
  ///   The function receives a [BuildContext] and should return a new instance
  ///   of type [H]. The created instance will be automatically disposed when
  ///   the provider is removed from the widget tree.
  /// * [builder] - Optional widget builder function that receives the
  ///   [BuildContext] and returns the widget subtree. If provided, this will
  ///   be used as the child of the provider.
  /// * [onInit] - Optional custom initialization callback. If provided, this
  ///   will be called instead of the Hako's default [KondoHako.onInit] method.
  ///   This allows for context-specific initialization logic without modifying
  ///   the Hako class itself.
  /// * [doNotInit] - If `true`, skips the automatic initialization process
  ///   entirely. Neither [onInit] nor [KondoHako.onInit] will be called.
  ///   Defaults to `false`.
  /// * [lazy] - Whether to create the [KondoHako] instance lazily (only when
  ///   first accessed) or immediately when the provider is created.
  ///   Defaults to `true`.
  /// * [key] - An optional [Key] to use for this widget.
  factory KondoProvider({
    required CreateHako<H> createHako,
    WidgetBuilder? builder,
    OnKondoInit<H>? onInit,
    bool doNotInit = false,
    bool? lazy,
    Key? key,
  }) =>
      KondoProvider._create(
        key: key,
        lazy: lazy,
        create: createHako,
        child: !doNotInit && builder != null
            ? _InitWidget(onInit: onInit, builder: builder)
            : builder != null
                ? Builder(builder: builder)
                : null,
      );

  /// Creates a new [KondoProvider] that provides an existing [KondoHako]
  /// instance to its descendants.
  ///
  /// The provided [value] will not be automatically disposed when the provider
  /// is removed from the widget tree, allowing for external lifecycle
  /// management.
  ///
  /// If [doNotInit] is `false` (the default), the Hako's [KondoHako.onInit]
  /// method will be automatically called after the first frame is rendered,
  /// unless a custom [onInit] callback is provided.
  ///
  /// Parameters:
  /// * [value] - An existing [KondoHako] instance of type [H] to provide to
  ///   descendants. This instance will not be automatically disposed when the
  ///   provider is removed from the widget tree.
  /// * [builder] - Optional widget builder function that receives the
  ///   [BuildContext] and returns the widget subtree. If provided, this will
  ///   be used as the child of the provider.
  /// * [onInit] - Optional custom initialization callback. If provided, this
  ///   will be called instead of the Hako's default [KondoHako.onInit] method.
  ///   This allows for context-specific initialization logic without modifying
  ///   the Hako class itself.
  /// * [doNotInit] - If `true`, skips the automatic initialization process
  ///   entirely. Neither [onInit] nor [KondoHako.onInit] will be called.
  ///   Defaults to `false`.
  /// * [key] - An optional [Key] to use for this widget.
  factory KondoProvider.value({
    required H value,
    WidgetBuilder? builder,
    OnKondoInit<H>? onInit,
    bool doNotInit = false,
    Key? key,
  }) =>
      KondoProvider._value(
        key: key,
        value: value,
        child: !doNotInit && builder != null
            ? _InitWidget(onInit: onInit, builder: builder)
            : builder != null
                ? Builder(builder: builder)
                : null,
      );
}

class _InitWidget<H extends KondoHako> extends StatefulWidget {
  const _InitWidget({
    required this.onInit,
    required this.builder,
  });

  final OnKondoInit<H>? onInit;
  final WidgetBuilder builder;

  @override
  _InitWidgetState<H> createState() => _InitWidgetState<H>();
}

class _InitWidgetState<H extends KondoHako> extends State<_InitWidget<H>> {
  @override
  void initState() {
    super.initState();
    final hako = context.readHako<H>();
    _deferAfterFrame(
      context,
      () => widget.onInit != null ? widget.onInit!(hako) : hako.onInit(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }
}

void _deferAfterFrame(BuildContext context, VoidCallback callback) {
  WidgetsBinding.instance.endOfFrame.then<void>(
    (_) async {
      if (context.mounted) {
        callback();
      }
    },
  );
}
