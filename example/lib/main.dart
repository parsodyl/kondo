import 'package:flutter/material.dart';
import 'package:kondo/kondo.dart';

// --- Services ---

class AnalyticsService {
  Future<void> logEvent(String name, Map<String, dynamic> parameters) async {
    // Simulate network delay so the loading indicator is visible
    await Future<void>.delayed(const Duration(milliseconds: 250));
    debugPrint('Analytics: $name $parameters');
  }
}

// --- State ---

class CounterSectionState {
  const CounterSectionState(this.count, {this.isLoading = false});
  final int count;
  final bool isLoading;
}

// --- Interactor ---

/// The brain of the operation. It holds no state and knows nothing about Flutter widgets.
/// It just computes data or talks to external Services/Repositories.
class CounterInteractor {
  CounterInteractor(this.analyticsService);

  final AnalyticsService analyticsService;

  // Business logic is pure
  Future<int> increment(int currentCount) async {
    // 1. Business logic happens here!
    final newCount = currentCount + 1;

    // 2. Side-operations (like logging) are transparent
    await analyticsService.logEvent('counter_incremented', {'count': newCount});

    // 3. Return 'Ready to consume' feature data
    return newCount;
  }

  // Domain rules dictate boundaries
  bool isLimitReached(int count) => count >= 10;
}

// --- Reactor & ContextAwareAdapter ---

/// Reusable, memory-safe launcher extending [ContextAwareAdapter] to safely wrap
/// actions like `showDialog` or `Navigator.push`.
class ContextAwareDialogLauncher extends ContextAwareAdapter {
  ContextAwareDialogLauncher({required super.contextResolver});

  // We use `String Function(BuildContext)` callbacks so text can be translated
  // seamlessly at the exact moment the dialog triggers!
  Future<void> launchInfoDialog({
    required String Function(BuildContext context) title,
  }) async {
    // tryRunAsync strictly guarantees the interior closure only executes if the widget is still mounted
    await tryRunAsync((getContext) async {
      final context = getContext();
      if (context != null) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(title: Text(title(context))),
        );
      }
    });
  }
}

/// The boundary to UI side effects. We don't capture raw BuildContext inside our
/// logic layer, but instead use context-aware adapters.
class CounterReactor {
  CounterReactor({required this.dialogLauncher});

  final ContextAwareDialogLauncher dialogLauncher;

  Future<void> showLimitDialog() async {
    await dialogLauncher.launchInfoDialog(
      // The context callback guarantees translations work flawlessly here
      title: (context) => 'Limit Reached!',
    );
  }
}

// --- Hako ---

/// The Orchestrator. The Hako listens to the View, delegates pure work to the Interactor,
/// triggers side effects in the Reactor, and natively updates state.
class CounterHako extends IRKondoHako<CounterInteractor, CounterReactor> {
  CounterHako({
    required super.interactor,
    required super.reactor,
  }) : super((register) {
          register(const CounterSectionState(0));
        });

  Future<void> onIncrementTap() async {
    final currentCount = get<CounterSectionState>().count;

    // Abstractly broadcast the UI loading intent
    set((_) => CounterSectionState(currentCount, isLoading: true));

    // Delegate domain logic and calculations completely to the Interactor
    final newCount = await interactor.increment(currentCount);

    // Update Orchestrator state and remove loading barrier
    set((_) => CounterSectionState(newCount, isLoading: false));

    // Delegate UI side effects based on domain rules
    if (interactor.isLimitReached(newCount)) {
      await reactor.showLimitDialog();
    }
  }
}

// Best Practice: Always provide a safe Context Extension for your views!
extension CounterHakoContextExtension on BuildContext {
  CounterHako get counterHako => readHako<CounterHako>();

  CounterSectionState watchCounterSectionState() =>
      watchHakoState<CounterHako, CounterSectionState>();
}

// --- Dependency Resolver ---

class MyDependencyResolver implements KondoDependencyResolver {
  MyDependencyResolver() {
    _analyticsService = AnalyticsService();
  }

  late final AnalyticsService _analyticsService;

  @override
  T resolve<T>() {
    if (T == AnalyticsService) {
      return _analyticsService as T;
    }
    if (T == CounterInteractor) {
      return CounterInteractor(_analyticsService) as T;
    }
    throw Exception('Dependency not found');
  }

  @override
  Future<void> dismantle() async {}
}

// --- App and View ---

void main() {
  runApp(
    KondoDependencyProvider(
      createResolver: (context) => MyDependencyResolver(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CounterPage(),
    );
  }
}

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return KondoProvider<CounterHako>(
      createHako: (context) => CounterHako(
        interactor: context.resolveDependency<CounterInteractor>(),
        reactor: CounterReactor(
          // Safely passing the Context through a robust lazy loader!
          dialogLauncher:
              ContextAwareDialogLauncher(contextResolver: () => context),
        ),
      ),
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Kondo Counter')),
        body: Center(
          child: Builder(
            builder: (context) {
              // Here we restrict the rebuild geometry to ONLY this specific section.
              final state = context.watchCounterSectionState();

              return state.isLoading
                  ? const CircularProgressIndicator()
                  : Text('Count: ${state.count}');
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          // Call events strictly formulated via intent ('onIncrementTap')
          onPressed: context.counterHako.onIncrementTap,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
