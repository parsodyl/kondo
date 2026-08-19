# The Reactor: The Side Effects Handler ⚡

The **Reactor** manages the boundaries and external environment of your feature. It acts as the specific "Side Effects Handler" for a Hako, defining a contract for actions that affect the app environment rather than the data rendered on the screen.

If the Hako defines *what the user sees* and the Interactor defines *the business rules*, the Reactor defines **what happens outside the primary view render cycle.**

---

### 1. Reactions are NOT State 🚫

A common anti-pattern in modern declarative frameworks is treating ephemeral side effects as state. Developers might want to create objects like `MapsToDetailState`, `ShowErrorToastState`, or `ScrollToTopAction`, inject them into the state stream, and force the View to listen and clear them.

**In Kondo, we do not model reactions as State.**

State is strictly for data that needs to be rendered and persisted in the UI. If an action is a one-off event (a "fire-and-forget" command or an async prompt), it belongs to the Reactor. The Hako simply commands the Reactor, keeping the state registry perfectly clean and focused on the UI's semantic structure.

---

### 2. The Scope of the Reactor 🔭

The Reactor handles **everything that is "launched," triggered, or requires imperative control** over the UI or OS. Its responsibilities fall into three main categories:

#### A. Visual & In-Page Control
The Reactor handles imperative UI actions that manipulate the current visual environment without navigating to a new feature:
* **Scroll Control:** `reactor.scrollToTop()`, `reactor.scrollToErrorField()`
* **Tab/Page Controllers:** `reactor.switchToOverviewTab()`
* **Focus Management:** `reactor.removeKeyboardFocus()`

#### B. User Prompts & Decisions (Yielding to Hako)
Often, a side effect isn't a dead end—it requires the user to make a quick decision that the Hako needs to evaluate. The Reactor acts as the prompt, returning a `Future` that the Hako awaits:
* **Confirmations:** `Future<bool> askForDeletion()`
* **System Pickers:** `Future<File?> pickImageFromGallery()`
* **Bottom Sheets:** `Future<SortOption?> showSortMenu()`

*Example inside a Hako:*
```dart
Future<void> onDeleteTap() async {
  // 1. Ask the Reactor to launch the prompt and wait for the user's decision
  final isConfirmed = await reactor.askForDeletion();
  if (!isConfirmed) return;
  
  // 2. Evaluate and proceed with business logic
  await interactor.deleteItem(id);
  reactor.goBack();
}
```

#### C. Routing & External Systems
The Reactor acts as the gateway to other features and native device capabilities:
* **Navigation:** `reactor.goToAlbumDetails(albumId)`, `reactor.goBack()`
* **Native APIs:** `reactor.shareText(text)`, `reactor.openSpotify(url)`
* **System UI:** `reactor.showToast(message)`

---

### 3. Implementation Pattern 1: Lightweight Function Callbacks 🪶

For simple features or purely local widget controllers (like a `ScrollController`, `FocusNode`, or a single local UI trigger), you don't always need a full adapter class. You can define your Reactor to accept lightweight **function callbacks**:

```dart
class FeedReactor {
  FeedReactor({
    required this.onScrollToTop,
    required this.onDismissKeyboard,
  });

  final void Function() onScrollToTop;
  final void Function() onDismissKeyboard;

  void scrollToTop() => onScrollToTop();
  void dismissKeyboard() => onDismissKeyboard();
}

// In the View:
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KondoProvider<FeedHako>(
      createHako: (context) => FeedHako(
        reactor: FeedReactor(
          onScrollToTop: () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          },
          onDismissKeyboard: () => FocusScope.of(context).unfocus(),
        ),
      ),
      builder: (context) => FeedView(scrollController: _scrollController),
    );
  }
}
```

#### When to use Callbacks:
* Controlling local view controllers (`ScrollController`, `PageController`, `FocusNode`).
* Quick prototypes and simple screens with 1–2 synchronous UI actions.

---

### 4. Implementation Pattern 2: `ContextAwareAdapter` (The Safe Bridge) 🛡️

When your feature triggers asynchronous side effects (e.g., waiting for an API response, then navigating or showing a dialog), passing raw callbacks or capturing `BuildContext` can lead to the **Deactivated Widget Crash** (`AssertionError: BuildContext is unmounted`).

Kondo provides **`ContextAwareAdapter`** to safely bridge pure Dart logic with Flutter's widget tree without memory leaks or unmounted context crashes.

#### Core API of `ContextAwareAdapter`:
1. **Lazy Context Resolution (`contextResolver`):** Does not store `BuildContext` directly; invokes a closure `() => context` at the exact moment the effect executes.
2. **`maybeContext`:** A safe getter that resolves the context and verifies if it is currently mounted. Returns the valid `BuildContext` if mounted, or `null` if unmounted.
3. **`getFromContext<T>()`:** Safely extracts data from the context (e.g., `Theme.of(context)`, `MediaQuery.of(context)`). Returns `null` if the widget is unmounted.
4. **`tryRun()`:** The workhorse for imperative commands. Executes a closure only if the context is active and mounted. If unmounted, the closure is safely ignored—no crashes!

```dart
class ContextAwareDialogLauncher extends ContextAwareAdapter {
  ContextAwareDialogLauncher({required super.contextResolver});

  Future<void> showInfoDialog(String title) async {
    await tryRun((context) => showDialog(
          context: context,
          builder: (_) => AlertDialog(title: Text(title)),
        ));
  }
}
```

---

### 5. The Canonical Architecture: Component Adapter Injection 🏆

To keep your architecture clean, modular, and 100% unit-testable in pure Dart, the canonical pattern is **Component Adapter Injection (Composition)**:

1. Create dedicated, reusable adapters extending `ContextAwareAdapter` (e.g., `DialogLauncher`, `AppRouter`, `ToastManager`).
2. Inject those adapters into your pure Dart `Reactor` class.
3. Wire the adapters with `() => context` inside `KondoProvider`.

```dart
// 1. Reusable Component Adapters (Extend ContextAwareAdapter)
class ContextAwareRouter extends ContextAwareAdapter {
  ContextAwareRouter({required super.contextResolver});

  void pushDetails(String id) =>
      tryRun((context) => Navigator.of(context).pushNamed('/details/$id'));
  
  void pop() => tryRun((context) => Navigator.of(context).pop());
}

// 2. Pure Dart Reactor (Injected via Composition)
class ProductReactor {
  ProductReactor({
    required this.dialogs,
    required this.router,
  });

  final ContextAwareDialogLauncher dialogs;
  final ContextAwareRouter router;

  Future<void> notifyLimitReached() async {
    await dialogs.showInfoDialog('Limit Reached!');
  }

  void goToDetails(String id) {
    router.pushDetails(id);
  }
}

// 3. Wired cleanly in the View:
KondoProvider<ProductHako>(
  createHako: (context) => ProductHako(
    reactor: ProductReactor(
      dialogs: ContextAwareDialogLauncher(contextResolver: () => context),
      router: ContextAwareRouter(contextResolver: () => context),
    ),
  ),
  builder: (context) => const ProductView(),
)
```

#### Why Component Injection is the Standard:
1. **100% Pure Dart Unit Tests:** In unit tests, you mock `ContextAwareDialogLauncher` and `ContextAwareRouter` with Mockito/Mocktail to verify calls (`verify(mockRouter.pushDetails('123')).called(1)`), running in milliseconds without Flutter engine overhead.
2. **Centralized Safety:** All `mounted` context checks are written once inside your adapter classes and trusted across all features.
3. **Framework Agnostic:** If you switch from standard `Navigator` to `GoRouter` or `AutoRoute`, you only update the internal adapter. All your Reactors remain untouched.

---

### 6. Designing Intent-Based Reactor Contracts 📐

When writing a Reactor, the methods should describe the **Intent of the UI Action**, not the implementation detail:

* **❌ Avoid:** `showMaterialAlertDialog()`, `pushNamedRoute()`, `executeUrlLauncher()`
* **✅ Prefer:** `showErrorDialog()`, `goToSettings()`, `openExternalBrowser()`

The Hako shouldn't know if the app uses `GoRouter` or standard `Navigator`, nor should it care if an error is displayed via a SnackBar or a Dialog. It only commands the intent.

---

### Summary Checklist for Reactors

1. [ ] **Are side effects kept out of State?** (No State objects for navigation, snackbars, or toasts).
2. [ ] **Does it choose the right pattern?** (Callbacks for local controllers/scrolling; `ContextAwareAdapter` for async dialogs & navigation).
3. [ ] **Does it use Composition over Inheritance?** (Reactors receive injected adapters or callbacks, rather than extending `ContextAwareAdapter` directly).
4. [ ] **Are methods intent-based?** (Names describe the user action or outcome, not UI framework classes).
5. [ ] **Does it return safe fallbacks for user prompts?** (Ensure `Future` return types handle `null` gracefully when dialogs are dismissed or context unmounts).