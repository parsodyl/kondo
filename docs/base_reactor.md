# The Reactor: The Side Effects Handler ⚡

The **Reactor** manages the boundaries and external environment of your feature. It acts as the specific "Side Effects Handler" for a Hako, defining a contract for actions that affect the app environment rather than the data rendered on the screen.

If the Hako defines *what the user sees* and the Interactor defines *the business rules*, the Reactor defines **what happens outside the primary view render cycle.**

---

### 1. Reactions are NOT State 🚫

A common anti-pattern in modern declarative frameworks is treating ephemeral side effects as state. Developers often create objects like `MapsToDetailState`, `ShowErrorToastState`, or `ScrollToTopAction`, inject them into the state stream, and force the View to listen and clear them.

**In Kondo, we do not model reactions as State.**

State is strictly for data that needs to be rendered and persisted in the UI. If an action is a one-off event (a "fire-and-forget" command or an async prompt), it belongs to the Reactor. The Hako simply commands the Reactor, keeping the state registry perfectly clean and focused on the UI's semantic structure.

### 2. The Scope of the Reactor 🔭

The Reactor handles **everything that is "launched," triggered, or requires imperative control** over the UI or OS. Its responsibilities fall into three main categories:

#### A. Visual & In-Page Control
The Reactor handles imperative UI actions that don't involve navigating to a new feature, but rather manipulating the current visual environment.
* **Scroll Control:** `reactor.scrollToTop()`, `reactor.scrollToErrorField()`
* **Tab/Page Controllers:** `reactor.switchToTab(int index)`
* **Focus Management:** `reactor.removeKeyboardFocus()`

#### B. User Prompts & Decisions (Yielding to Hako)
Often, a side effect isn't a dead end—it requires the user to make a quick decision that the Hako needs to evaluate. The Reactor acts as the prompt, returning a `Future` that the Hako awaits.
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
The Reactor acts as the gateway to other features and native device capabilities.
* **Navigation:** `reactor.goToAlbumDetails(albumId)`, `reactor.goBack()`
* **Native APIs:** `reactor.shareText(text)`, `reactor.openSpotify(url)`
* **System UI:** `reactor.showToast(message)`

### 3. The `ContextAwareAdapter` (The Safe Bridge) 🌉

Because the Reactor executes framework-specific side effects (which in Flutter almost always require a `BuildContext`), it needs a safe way to access the View's context without coupling the Hako to the widget tree.

We handle this using the **`ContextAwareAdapter`**. It acts as an anti-corruption layer, ensuring that operations are only executed if the context is still mounted, preventing "deactivated widget" exceptions.

```dart
// Example: A robust Reactor implementation
class GoRouterAdapter extends ContextAwareAdapter {
  GoRouterAdapter({required super.contextResolver});

  void go(String location, {Object? extra}) =>
      tryRun((context) => GoRouter.of(context).go(location, extra: extra));

  void pop<T extends Object?>([T? result]) =>
      tryRun((context) => GoRouter.of(context).pop<T>());
}

class MyFeatureReactor {
  MyFeatureReactor(super.router);
  
  final GoRouterAdapter router;

  // Navigate
  void goToDetails(String id) {
    tryRun((context) => context.go('/details/$id')); 
  }
}

// Usage
final reactor = MyFeatureReactor(GoRouterAdapter(contextResolver: () => context));
```

### 4. Designing the Reactor Contract 📐

When writing a Reactor, the methods should describe the **Intent of the UI Action**, not the implementation detail.

* **❌ Avoid:** `showMaterialAlertDialog()`, `pushNamedRoute()`, `executeUrlLauncher()`
* **✅ Prefer:** `showErrorDialog()`, `goToSettings()`, `openExternalBrowser()`

The Hako shouldn't know if the app uses `GoRouter` or standard `Navigator`, nor should it care if an error is displayed via a SnackBar or a Dialog. It only commands the intent.

---

### Summary Checklist for Reactors

1. [ ] **Are side effects kept out of State?** (Ensure you aren't creating State objects for navigation or toasts).
2. [ ] **Does it use `ContextAwareAdapter`?** (Safely interact with the `BuildContext` using `tryRun`).
3. [ ] **Are methods intent-based?** (Name methods based on the action, hiding the routing/UI library implementation).
4. [ ] **Does it return safe fallbacks for user prompts?** (Ensure `Future` return types handle `null` gracefully when dialogs are dismissed or context unmounts).