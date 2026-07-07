/// The Kondo architecture pattern for Flutter.
///
/// Kondo structures every feature around the Triad: Hako (orchestrator),
/// Interactor (business logic), and Reactor (side effects). It enforces
/// strict separation of concerns, ensuring business logic never leaks
/// into the UI and side effects never mix with state.
///
/// Built on top of the [hako](https://pub.dev/packages/hako) state management
/// package, Kondo extends core state concepts into a full architectural
/// pattern.
library;

export 'package:hako/hako.dart';

export 'src/kondo_dependency.dart';
export 'src/kondo_hako.dart';
export 'src/kondo_hako_events.dart';
export 'src/kondo_provider.dart';
export 'src/context_aware_adapter.dart';
