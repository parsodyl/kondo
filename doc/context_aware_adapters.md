# Context-Aware Adapters 🛡️

The `ContextAwareAdapter` is a fundamental utility in the Kondo architectural pattern. It acts as a secure bridge between pure Dart logic (like your Triad's **Reactor**) and Flutter's framework layer (the `BuildContext`). Its primary purpose is to permanently eliminate the dreaded "Deactivated Widget crash" while ensuring your architecture remains clean, decoupled, and highly testable.

---

## 💥 The Problem: The Deactivated Widget Crash

In standard Flutter development, you often need to trigger a UI side effect—like showing a dialog, navigating, or displaying a snackbar—**after** an asynchronous operation (e.g., waiting for an API call to complete).

If the user navigates away from the screen before the asynchronous operation finishes, the original `BuildContext` becomes "unmounted" (dead). Attempting to use this dead context to trigger a navigation event or show a dialog will throw a fatal `AssertionError`.

To fix this natively, developers often clutter their logic with checks:
```dart
if (!context.mounted) return;
Navigator.pop(context);
```
However, passing `BuildContext` into a pure Dart class like an Interactor or Reactor tightly couples your logic to Flutter, ruining unit testability and violating the principles of clean architecture.

---

## 🛡️ The Solution: `ContextAwareAdapter`

The `ContextAwareAdapter` acts as a shield. It encapsulates the `mounted` checks and guarantees that side effects only execute if it is safe to do so.

### Core Features

#### 1. Lazy Context Resolution
The adapter doesn't store the `BuildContext` directly. Instead, it accepts a `contextResolver` (a `BuildContext Function()`). This ensures that it retrieves the most up-to-date context reference exactly at the moment the side effect needs to be triggered.

#### 2. `maybeContext`
A safe getter that invokes the `contextResolver` and verifies if the resulting `BuildContext` is currently mounted.
- If **mounted**: Returns the `BuildContext`.
- If **unmounted**: Returns `null`.

#### 3. `tryRun`
The workhorse of the adapter. It accepts a closure that receives a guaranteed-safe `BuildContext`. It internally uses `maybeContext` to check the widget tree's state. If the context is dead, the closure is simply ignored—no crashes, no messy `if (!mounted)` checks in your business logic!

```dart
tryRun((context) {
  // We only reach here if the context is perfectly valid and mounted!
  Navigator.of(context).pop();
});
```

---

## 🏗️ Architectural Usage: Composition vs Inheritance

Understanding **how** to use `ContextAwareAdapter` is critical for maintaining true unit-testability in your Kondo architecture.

### 🚫 The Anti-Pattern: Reactor Inheritance

A common mistake is making your Reactor *itself* extend `ContextAwareAdapter`.

```dart
// ❌ ANTI-PATTERN: Reactor extending ContextAwareAdapter
class MyFeatureReactor extends ContextAwareAdapter {
  MyFeatureReactor({required super.contextResolver});

  void showLimitDialog() {
    // The tryRun closure tightly couples the Reactor to Flutter's showDialog function
    tryRun((context) {
      showDialog(
        context: context, 
        builder: (_) => const AlertDialog(title: Text('Limit Reached!'))
      );
    });
  }
}
```

**Why is this bad?**
1. **Poor Unit Testability**: In a pure Dart unit test, you cannot easily test the logic inside the `tryRun` closure because `showDialog` is a static Flutter function requiring a real widget tree (`WidgetTester`). 
2. **Coupling**: Your Reactor is tightly coupled directly to Flutter's framework APIs.
3. **Violation of SRP (Single Responsibility Principle)**: The Reactor is now responsible for both orchestrating the intent of the side-effect *and* defining the low-level UI implementation details.

### ✅ The Best Practice: Component Injection (Composition)

Instead of Inheritance, we use **Composition**. We extract the safe execution logic into dedicated, reusable "Component Adapters", and we **inject** these adapters into our Reactors.

#### Step 1: Create Reusable Adapters
These component adapters are the *only* classes in your application that should extend `ContextAwareAdapter`.

```dart
// A reusable adapter for Dialogs
class ContextAwareDialogs extends ContextAwareAdapter {
  ContextAwareDialogs({required super.contextResolver});

  Future<void> showInfoDialog(String title) async {
    await tryRun((context) async {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(title: Text(title)),
      );
    });
  }
}

// A reusable adapter for Navigation
class ContextAwareRouter extends ContextAwareAdapter {
  ContextAwareRouter({required super.contextResolver});

  void pop() => tryRun((context) => Navigator.pop(context));
}
```

#### Step 2: Inject into the Reactor
Now, your Reactor simply expects these robust interfaces as dependencies. It does **not** extend `ContextAwareAdapter` itself.

```dart
// ✅ BEST PRACTICE: Reactor uses dependency injection
class MyFeatureReactor {
  MyFeatureReactor({
    required this.dialogs,
    required this.router,
  });

  final ContextAwareDialogs dialogs;
  final ContextAwareRouter router;

  Future<void> handleLimitReached() async {
    // The Reactor declares the intent; the Adapter handles the execution safely.
    await dialogs.showInfoDialog('Limit Reached!');
  }

  void goBack() {
    router.pop();
  }
}
```

### Why is Component Injection the Gold Standard?
1. **100% Pure Dart Testability**: You can now mock `ContextAwareDialogs` and `ContextAwareRouter` using Mockito (or Mocktail). You can verify intentions seamlessly: `verify(mockDialogs.showInfoDialog('Limit Reached!')).called(1);` without ever spinning up a Flutter test environment.
2. **Centralized Safety**: You write the context-checking logic once per component adapter, test it thoroughly, and trust it everywhere.
3. **Decoupled Architecture**: If you ever migrate from `Navigator 1.0` to `GoRouter`, you only update the internal implementation of `ContextAwareRouter`. The Reactor remains completely untouched.

---

## Summary Checklist

- [ ] Does your Reactor extend `ContextAwareAdapter`? **(It shouldn't!)**
- [ ] Are you passing a `BuildContext` or `contextResolver` into your Reactor? **(Pass injected adapter objects instead!)**
- [ ] Are your app's native actions (Dialogs, Navigation, Snackbars) wrapped in dedicated `ContextAwareAdapter` component classes? **(They should be!)**
