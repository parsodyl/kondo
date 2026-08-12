import 'package:flutter/material.dart';
import 'package:kondo/kondo.dart';

// --- Services ---

class AnalyticsService {
  Future<void> logEvent(String name, Map<String, dynamic> parameters) async {
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

class CounterInteractor {
  CounterInteractor(this.analyticsService);

  final AnalyticsService analyticsService;

  Future<int> increment(int currentCount) async {
    final newCount = currentCount + 1;
    await analyticsService.logEvent('counter_incremented', {'count': newCount});
    return newCount;
  }

  bool isLimitReached(int count) => count >= 10;
}

// --- Reactor & ContextAwareAdapter ---

class ContextAwareDialogLauncher extends ContextAwareAdapter {
  ContextAwareDialogLauncher({required super.contextResolver});

  Future<void> launchInfoDialog({
    required String Function(BuildContext context) title,
  }) async {
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

class CounterReactor {
  CounterReactor({required this.dialogLauncher});

  final ContextAwareDialogLauncher dialogLauncher;

  Future<void> showLimitDialog() async {
    await dialogLauncher.launchInfoDialog(
      title: (context) => 'Limit Reached!',
    );
  }
}

// --- Hako ---

class CounterHako extends IRKondoHako<CounterInteractor, CounterReactor> {
  CounterHako({
    required super.interactor,
    required super.reactor,
  }) : super((register) {
          register(const CounterSectionState(0));
        });

  Future<void> onIncrementTap() async {
    final currentCount = get<CounterSectionState>().count;
    
    set((_) => CounterSectionState(currentCount, isLoading: true));
    
    final newCount = await interactor.increment(currentCount);
    
    set((_) => CounterSectionState(newCount, isLoading: false));
    
    if (interactor.isLimitReached(newCount)) {
      await reactor.showLimitDialog();
    }
  }
}

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
          dialogLauncher: ContextAwareDialogLauncher(contextResolver: () => context),
        ),
      ),
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Kondo Counter')),
        body: Center(
          child: Builder(
            builder: (context) {
              final state = context.watchCounterSectionState();

              return state.isLoading
                  ? const CircularProgressIndicator()
                  : Text('Count: ${state.count}');
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: context.counterHako.onIncrementTap,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
