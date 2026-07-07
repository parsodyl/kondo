import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Abstract base class for dependency resolution and lifecycle management.
///
/// Implementations of this class are responsible for resolving dependencies
/// of any type and cleaning up resources when they are no longer needed.
///
/// Implementations can leverage existing dependency injection libraries such
/// as `kiwi` or `get_it` to handle the actual dependency registration and
/// resolution logic.
///
/// Example usage:
/// ```dart
/// class MyResolver implements KondoDependencyResolver {
///   MyResolver() {
///     // Register dependencies in the constructor
///     _instances[MyService] = MyService();
///     _instances[MyRepository] = MyRepository();
///   }
///
///   final Map<Type, dynamic> _instances = {};
///
///   @override
///   T resolve<T>() {
///     return _instances[T] as T;
///   }
///
///   @override
///   Future<void> dismantle() async {
///     _instances.clear();
///   }
/// }
/// ```
abstract interface class KondoDependencyResolver {
  /// Resolves and returns an instance of type [T].
  ///
  /// This method should retrieve or create an instance of the requested type.
  /// Implementations are responsible for managing the lifecycle of resolved
  /// dependencies.
  ///
  /// It should throw an exception if the dependency cannot be resolved.
  T resolve<T>();

  /// Cleans up resources and disposes of managed dependencies.
  ///
  /// This method is called automatically when the [KondoDependencyProvider]
  /// is disposed. Implementations should release any resources, close streams,
  /// and dispose of objects that require cleanup.
  FutureOr<void> dismantle();
}

/// Extension on [BuildContext] providing convenient access to dependency
/// resolution.
///
/// This extension allows any widget with access to a [BuildContext] to resolve
/// dependencies without directly accessing the [KondoDependencyResolver].
extension DependencyResolverContextExtension on BuildContext {
  /// Resolves and returns an instance of type [T] from the dependency resolver.
  ///
  /// This is a convenience method that reads the [KondoDependencyResolver] from
  /// the widget tree and calls its [resolve] method.
  ///
  /// Example:
  /// ```dart
  /// final myService = context.resolveDependency<MyService>();
  /// ```
  ///
  /// Throws an exception if no [KondoDependencyResolver] is found in the widget
  /// tree or if the dependency cannot be resolved.
  T resolveDependency<T>() => read<KondoDependencyResolver>().resolve<T>();
}

/// A [Provider] widget that manages the lifecycle of a
/// [KondoDependencyResolver].
///
/// This widget creates a [KondoDependencyResolver] and automatically calls its
/// [dismantle] method when the widget is disposed, ensuring proper cleanup of
/// resources.
///
/// Example:
/// ```dart
/// // 1. Setup the provider at the root
/// KondoDependencyProvider(
///   createResolver: (context) => MyResolver(),
///   child: MyApp(),
/// )
///
/// // 2. Access dependencies in child widgets
/// class MyWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     final myService = context.resolveDependency<MyService>();
///     return Text(myService.getData());
///   }
/// }
/// ```
class KondoDependencyProvider extends Provider<KondoDependencyResolver> {
  /// Creates a [KondoDependencyProvider].
  ///
  /// The [createResolver] callback is used to create the resolver instance.
  /// The [child] widget will have access to the resolver through the widget
  /// tree.
  ///
  /// When this provider is disposed, it automatically calls [dismantle] on the
  /// resolver to clean up resources.
  KondoDependencyProvider({
    required Create<KondoDependencyResolver> createResolver,
    required super.child,
    super.key,
  }) : super(
          create: createResolver,
          dispose: (context, resolver) => resolver.dismantle(),
        );

  /// Creates a [KondoDependencyProvider] with an existing resolver instance.
  ///
  /// Unlike the default constructor, this constructor takes an existing
  /// [KondoDependencyResolver] instance via the [value] parameter instead of
  /// creating a new one.
  ///
  /// **Important**: When using this constructor, the [dismantle] method will
  /// NOT be called automatically when the provider is disposed. The caller is
  /// responsible for managing the lifecycle of the resolver instance.
  ///
  /// This is useful when you need to share a resolver instance across multiple
  /// parts of your widget tree or when the resolver's lifecycle is managed
  /// externally.
  ///
  /// Example:
  /// ```dart
  /// final resolver = MyResolver();
  ///
  /// KondoDependencyProvider.value(
  ///   value: resolver,
  ///   child: MyWidget(),
  /// )
  /// ```
  KondoDependencyProvider.value({
    required super.value,
    required super.child,
    super.key,
  }) : super.value();
}
