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

/// A function type for the ready lifecycle callbacks on [KondoHako] instances.
///
/// This callback is invoked during the lifecycle of a
/// [KondoProvider], allowing custom orchestration logic to be executed
/// after the Hako is created and the view is fully mounted (post-frame).
///
/// The [hako] parameter is the fully created instance, ready for
/// initialization.
typedef OnKondoReady<H extends KondoHako> = FutureOr<void> Function(H hako);

/// A Provider widget that provides a [KondoHako] instance to its descendants
/// and manages its ready lifecycle.
///
/// [KondoProvider] extends [HakoProvider] to add specialized lifecycle
/// support for the Kondo architecture pattern. It automatically handles the
/// orchestration phase of [KondoHako] instances by calling their [KondoHako.onReady]
/// method after the first frame is rendered, ensuring the widget tree is
/// fully mounted before any side effects or async fetches run.
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
/// The process follows these steps:
/// 1. The [KondoHako] instance is created. (Synchronous setup like stream connections happen in its constructor).
/// 2. The widget tree is built and painted to the screen.
/// 3. After the first frame completes, the `onReady` callback is invoked.
///
/// This ensures that the widget tree and [BuildContext] are fully available
/// before any orchestration logic runs, which is critical for Reactor operations
/// that depend on the widget tree being mounted (like dialogs or navigation).
///
/// Type Parameters:
/// * [H] - The type of the [KondoHako] instance. Must extend [KondoHako].
///
/// Example:
/// ```dart
/// // Creating a new instance with automatic ready hook
/// KondoProvider<MyHako>(
///   createHako: (context) => MyHako(
///     interactor: MyInteractor(),
///     reactor: MyReactor(),
///   ),
///   builder: (context) => MyScreen(),
/// )
///
/// // Custom ready callback
/// KondoProvider<MyHako>(
///   createHako: (context) => MyHako(),
///   onReady: (hako) async {
///     await hako.fetchInitialData();
///     hako.reactor.showWelcomeDialog();
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
/// // Skip the ready hook when needed
/// KondoProvider<MyHako>(
///   createHako: (context) => MyHako(),
///   skipReady: true,
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

  /// Creates a [KondoProvider] that creates and provides a [KondoHako]
  /// instance to its descendants.
  ///
  /// The [createHako] factory function is called to instantiate the Hako.
  /// If [skipReady] is `false` (the default), the Hako's [KondoHako.onReady]
  /// method will be automatically called after the first frame is rendered,
  /// unless a custom [onReady] callback is provided.
  factory KondoProvider({
    required CreateHako<H> createHako,
    WidgetBuilder? builder,
    OnKondoReady<H>? onReady,
    bool skipReady = false,
    bool? lazy,
    Key? key,
  }) =>
      KondoProvider._create(
        key: key,
        lazy: !skipReady ? false : (lazy ?? true),
        create: createHako,
        child: !skipReady && builder != null
            ? _ReadyWidget(onReady: onReady, builder: builder)
            : builder != null
                ? Builder(builder: builder)
                : null,
      );

  /// Provides an existing [KondoHako] instance to descendant widgets.
  factory KondoProvider.value({
    required H value,
    WidgetBuilder? builder,
    OnKondoReady<H>? onReady,
    bool skipReady = false,
    Key? key,
  }) =>
      KondoProvider._value(
        key: key,
        value: value,
        child: !skipReady && builder != null
            ? _ReadyWidget(onReady: onReady, builder: builder)
            : builder != null
                ? Builder(builder: builder)
                : null,
      );
}

class _ReadyWidget<H extends KondoHako> extends StatefulWidget {
  const _ReadyWidget({
    required this.onReady,
    required this.builder,
  });

  final OnKondoReady<H>? onReady;
  final WidgetBuilder builder;

  @override
  _ReadyWidgetState<H> createState() => _ReadyWidgetState<H>();
}

class _ReadyWidgetState<H extends KondoHako> extends State<_ReadyWidget<H>> {
  @override
  void initState() {
    super.initState();
    final hako = context.readHako<H>();
    _deferAfterFrame(
      context,
      () => widget.onReady != null ? widget.onReady!(hako) : hako.onReady(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }
}

void _deferAfterFrame(BuildContext context, VoidCallback callback) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted) {
      callback();
    }
  });
}
