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

### 5. Connecting Data Safely (`connectStream`) 🔌

Because the Hako orchestrates the UI, it must safely listen to the streams provided by the Interactor. Doing this manually with `StreamSubscription`s often leads to memory leaks.

The `KondoHako` base class provides native helpers to effortlessly bind streams:

*   **`connectStream<T>()`**: Listens to an incoming stream and automatically maps the incoming data onto the registered state `T` (often utilizing `.copyWith()`).
*   **`listenStream()`**: Safely listens to a stream for side-effects without directly mutating a registered state.

Crucially, both of these helpers natively bind to the Hako's lifecycle. When the Hako is destroyed (e.g., the user navigates away from the feature), all streams are **automatically canceled**. You never have to worry about dangling listeners!

---

### What's Next? ➡️

Understanding the role of the Hako and its granular rebuilding is just the first step. To write performant and clean features, you must understand exactly *how* to shape the data inside it. 

In the upcoming sections, we will cover:
1.  **Naming Event Handlers:** The "Wireframe Test" and intent-oriented naming formulas for your Hako methods.
2.  **Structuring State:** Why you should avoid monolithic "God States" and use Semantic Sectioning.
3.  **Internal State Structures:** How to explicitly define the structs registered inside the Hako.
