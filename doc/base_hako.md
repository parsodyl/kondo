# The Hako: The UI Orchestrator 📦

The **Hako** is the core state binder and UI translator of your feature. If the Interactor is the "Brain" and the Reactor handles the "External Environment," the Hako acts as the central **Orchestrator**. It catches interactions from the user, routes them to the correct Triad component, and perfectly translates raw business data into isolated UI states.

---

### 1. The Foundation: The `hako` Package 🧱

If you are unfamiliar with the underlying state system, Kondo is built strictly on top of the **[`hako` package](https://pub.dev/packages/hako)**. 

*Hako* (箱), the Japanese word for box, is a lightweight state container designed for simplicity, performance, and testability. It forces a minimal and explicit API focused around three core operations:
1.  **Register:** Declaring initial state types in the constructor via `register<T>()`.
2.  **Read:** Accessing current state without listening via `get<T>()`.
3.  **Update:** Mutating state safely via `set<T>()`.

*Note: The raw `hako` package is entirely architecture-agnostic. It doesn't know what an Interactor or Reactor is—it simply holds data securely and notifies listeners.*

### 2. State Mechanics & Granular Rebuilding 🗄️

State inside a Hako is not a massive, monolithic `ScreenState` object. Instead, Hako relies on **Granular Rebuilding**.

When you register discrete state structures (e.g., `register<HeaderState>()` and `register<ListState>()`), Hako selects and caches those values internally. 
If your UI updates the header via `set<HeaderState>()`, **only the specific widgets** bound with `context.watchHakoState<MyHako, HeaderState>()` will rebuild. The rest of your layout—like the list—survives unmodified.

This effectively eliminates expensive full-screen repaints without requiring manual rebuild conditions!

### 3. Enter `KondoHako` (The Architectural Wrapper) 🦸‍♂️

Kondo takes this raw, unopinionated container and supercharges it to enforce the **Kondo Triad**. 

Rather than extending `Hako` directly, you extend one of the specific **`KondoHako`** variants. These variants inject your feature's specific architectural layers, giving the Hako secure, immediate access to business logic and side effects without performing unsafe global lookups.

**The Kondo Variants:**
*   **`KondoHako`**: The base class. It offers automatic lifecycle hooks (like `onReady()`) and safe stream management, perfect for simple UI features with no heavy business logic.
*   **`IKondoHako<I>`**: Injects an **Interactor** (`interactor`). Use this when your feature needs pure business logic, calculations, or data fetching, but doesn't require complex routing side effects.
*   **`RKondoHako<R>`**: Injects a **Reactor** (`reactor`). Use this when your feature needs to launch dialogs or trigger navigation, but doesn't have complex data logic.
*   **`IRKondoHako<I, R>`**: The comprehensive variant. It injects both the **Interactor** and **Reactor**. This is the most feature-complete variant and forms the full Kondo Triad for complex screens.

```dart
// Example of the full Triad Hako definition
class MyFeatureHako extends IRKondoHako<MyFeatureInteractor, MyFeatureReactor> {
  MyFeatureHako({
    required super.interactor,
    required super.reactor,
  }) : super((register) {
         // Granular initial state setup happens here
         register(const HeaderState());
         register(const ListState());
       });
}
```

### 4. The Role of the Orchestrator 🚦

The Hako acts strictly as a "Traffic Cop" and a "Translator." It holds **NO business logic**.

*   **Traffic Cop (Routing Intent):** When a user taps a button, the Hako receives the event. It decides if this requires a visual side effect (routes to `reactor.showDialog()`) or a business operation (routes to `interactor.deleteItem()`).
*   **Translator (Binding State):** When the Interactor outputs raw domain data (e.g., `Stream<List<Song>>`), the Hako intercepts it and translates it into a hyper-specific UI struct via `set<T>()`.

### 5. Lifecycle: Constructor vs `onReady()` ⏳

A common question when building features is: **Where should initial data loading and startup side effects happen?**

Kondo clearly separates synchronous setup from post-render lifecycle operations:

```
[ Widget Tree Mounts ] ──► [ Hako Constructor (Synchronous) ] ──► [ 1st Frame Rendered ] ──► [ onReady() Hook ]
```

#### 🏗️ The Constructor: Synchronous Registration & Wiring
The constructor runs immediately when `KondoProvider` instantiates your Hako. It should be kept lightweight, synchronous, and purely declarative:
* Registering initial state structures via `register<T>()`.
* Wiring injected dependencies (`super.interactor`, `super.reactor`).
* Setting up immediate, persistent stream subscriptions (via `connectStream`).

> [!WARNING]
> **Never trigger asynchronous network calls or UI side effects directly in the constructor.** The widget tree has not completed its first render, meaning widgets are not yet mounted and initial layout constraints are not finalized.

#### 🚀 The `onReady()` Hook: Post-Render Startup Logic
`onReady()` is automatically invoked by `KondoProvider` **after the first frame has successfully rendered** (`WidgetsBinding.instance.addPostFrameCallback`).

This is the designated place for:
* **Initial Resource Fetching:** Loading detail data from the network/database when a page opens (e.g., `await interactor.loadProductDetails(id)`).
* **Startup UI Side Effects:** Displaying an onboarding dialog, checking location permissions, or opening a bottom sheet right as the screen appears via the `Reactor`.
* **Viewport Actions:** Requesting auto-scroll to a specific position or setting focus once the widget hierarchy is laid out.

```dart
class ProductDetailHako extends IRKondoHako<ProductDetailInteractor, ProductDetailReactor> {
  ProductDetailHako({
    required super.interactor,
    required super.reactor,
  }) : super((register) {
          // 1. Synchronous initial state setup
          register(const ProductDetailState(isLoading: true));
        });

  @override
  Future<void> onReady() async {
    // 2. Load data right after the screen renders (the interactor already holds the productId)
    final product = await interactor.fetchProduct();
    set<ProductDetailState>((_) => ProductDetailState(product: product, isLoading: false));

    // 3. Trigger initial side effects if required (e.g., promo dialog or warning)
    if (product.isOutdated) {
      await reactor.showOutdatedWarningDialog();
    }
  }
}
```

#### Customizing `onReady` in the View
If needed, `KondoProvider` allows you to customize or skip the default `onReady` invocation:
* **`KondoProvider(onReady: (hako) => ...)`**: Override the default startup hook with custom view-level startup logic.
* **`KondoProvider(skipReady: true, ...)`**: Completely suppress automatic `onReady` execution (useful in testing or deferred initialization scenarios).

---

### 6. Connecting Data Safely (`connectStream` & `listenStream`) 🔌

Real-world Flutter apps are reactive: Interactors expose streams of data from WebSockets, Firebase, local SQLite change streams, or reactive repositories.

Because the Hako orchestrates the UI, it must consume these streams and translate incoming emissions into state updates. Doing this manually with raw `StreamSubscription`s often leads to boilerplate, manual error handling, and accidental memory leaks.

The `KondoHako` base class provides built-in stream binding methods that automatically tie subscription lifetimes to the Hako:

#### 1. `connectStream<T>()`: Direct State Mapping
Use `connectStream<T>` when incoming stream data directly updates a registered state structure `T`.

* **Automatic State Updating:** Each stream emission triggers `set<T>()`.
* **State Folding (`onEvent`):** Optionally fold or merge the incoming item with the current state.
* **Guaranteed Cleanup:** The subscription is registered internally and automatically canceled when the Hako is destroyed.

```dart
class ChatHako extends IKondoHako<ChatInteractor> {
  ChatHako({required super.interactor})
      : super((register) {
          register(const ChatMessagesSectionState([]));
          register(const ConnectionSectionState(isOnline: false));
        }) {
    // 1. Direct state replacement
    connectStream<ConnectionSectionState>(
      stream: interactor.getConnectionStatusStream().map(ConnectionSectionState.new),
    );

    // 2. Incremental state transformation (merging incoming state)
    connectStream<ChatMessagesSectionState>(
      stream: interactor.getIncomingMessagesStream().map(ChatMessagesSectionState.new),
      onEvent: (currentState, incomingState) => currentState.copyWith(
        messages: [...currentState.messages, ...incomingState.messages],
      ),
      onError: (error) => debugPrint('Stream error: $error'),
    );
  }
}
```

#### 2. `listenStream<T>()`: Handling Reactive Side Effects
Use `listenStream<T>` when you want to listen to a stream for custom handling, side effects, or complex conditional updates rather than directly replacing a state type.

```dart
listenStream<UserSessionEvent>(
  stream: interactor.getSessionEventsStream(),
  onData: (event) {
    if (event.isExpired) {
      reactor.showSessionExpiredDialog();
    }
  },
);
```

#### 📍 Where to Bind Streams: Constructor vs `onReady`
* **In the Constructor:** Ideal for persistent, immediate subscriptions (e.g. user authentication changes, realtime database sync).
* **In `onReady`:** (pretty rare) Ideal for subscriptions that should only start once the view is mounted or after an initial async setup completes.

---

### 7. View Integration: The Power of Context Extensions 🪄

In Flutter, accessing InheritedWidgets or Providers directly via generic lookups like `context.readHako<ProductDetailHako>()` or `context.watchHakoState<ProductDetailHako, HeaderState>()` can be repetitive, verbose, and error-prone.

Kondo strongly recommends declaring a **typed `BuildContext` extension** alongside every feature's Hako.

```dart
// lib/src/features/product_detail/product_detail_hako.dart

extension ProductDetailContextExtension on BuildContext {
  /// Fast, non-listening access to the Hako (for event handlers)
  ProductDetailHako get productDetailHako => readHako<ProductDetailHako>();

  /// Granular state watchers for tight rebuild boundaries
  HeaderSectionState watchHeaderState() =>
      watchHakoState<ProductDetailHako, HeaderSectionState>();

  ReviewsSectionState watchReviewsState() =>
      watchHakoState<ProductDetailHako, ReviewsSectionState>();
}
```

#### Why are Context Extensions a Best Practice?

1. **Clean, Readable View Code:**
   Instead of noisy generic methods inside widget trees:
   ```dart
   // ❌ Verbose & repetitive
   final state = context.watchHakoState<ProductDetailHako, HeaderSectionState>();
   onPressed: () => context.readHako<ProductDetailHako>().onSaveTap();

   // ✅ Clean & expressive
   final state = context.watchHeaderState();
   onPressed: context.productDetailHako.onSaveTap;
   ```

2. **Strict Rebuild Geometry:**
   By exposing dedicated helper methods for each semantic state (e.g., `watchHeaderState()`, `watchReviewsState()`), you encourage widgets to watch only the slice of state they actually need. If only the review count changes, the header widget never rebuilds.

3. **Refactoring Safety & Autocompletion:**
   If you ever rename a state struct or refactor feature internals, the compiler and IDE autocompletion guide you directly, protecting view widgets from broken generic signatures.

---

### What's Next? ➡️

Understanding the role of the Hako, its lifecycle, stream connections, and context extensions is the foundation of building robust features.

In the upcoming sections, we will cover:
1.  **[Naming Event Handlers](./naming_event_handlers.md):** The "Wireframe Test" and intent-oriented naming formulas for your Hako methods.
2.  **[Structuring State](./structuring_state.md):** Why you should avoid monolithic "God States" and use Semantic Sectioning.
3.  **[Internal State Structures](./internal_state_structure.md):** How to explicitly define the structs registered inside the Hako.
