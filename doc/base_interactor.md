# The Interactor: The Business Brain 🧠

The **Interactor** is the pure business logic layer. It acts as the specific "Brain" for a feature, bridging the gap between your Data Layer (Services/Repositories) and your Orchestrator (Hako). It also contains all calculations, transformations, and business rules needed by the Hako.

Unlike the Hako (which cares about the UI) or Services/Repositories (which care about Data), the Interactor cares about **Use Cases**.

---

### An important note: The Data Layer (A Teaching Model) 🏗️

Kondo is technically agnostic about your data layer (you could use Firebase, SQLite, or pure HTTP). However, in our examples and recommendations, we use two specific types of structures:

* **Services (Facades):** These are lightweight wrappers around external APIs (Remote API, File System). They have no memory. They just fetch and return.
* **Repositories (The Truth):** These hold the shared **App State**. They fetch data from Services, cache it in memory (e.g., `savedAlbumList`), and might notify listeners when it changes (or just get the data directly).

### 1. State Management: Feature vs. App State 🗄️

One of the most confusing parts of architecture is "Where does this variable live?" Kondo draws a sharp line:

* **App State (Persistent):** Lives in **Repositories**.
* *Examples:* User Authentication data, The global list of saved albums, The "Dark Mode" setting.
* *Role:* This state outlives any specific screen. It is cached and shared across the app.


* **Feature State (Transient):** Lives in the **Hako**.
* *Examples:* The current text in the search bar, The "Expanded" state of a card, The exact `VisualPlaylist` being displayed right now.
* *Role:* This state dies when the screen closes.

### 2. The Golden Rule: "Ready to Consume" 🍽️

The Interactor exists to serve the Hako. It should not always just blindly re-expose Repository/Service methods. It must tailor the data exactly how the Hako needs it.

* **Bespoke Logic:** If the Hako needs a `VisualPlaylist` (with album art pre-resolved and list of tracks ready to be played), the Interactor should not return a raw `Playlist` and force the Hako to fetch the art or the tracks separately. The Interactor does the heavy lifting.
* **Action-Oriented:** Prefer **Public Methods** over Getters.
* *❌ Avoid:* `bool get isUserLoggedIn` (Implies a cheap property lookup).
* *✅ Prefer:* `Future<bool> checkUserLoggedIn()` (Implies a business check that might involve logic or async work).


**The Interactor's Job:**
The Interactor fetches **App State** from Repositories and hands it to the Hako to become **Feature State**. It never holds state itself.

### 3. Handling Streams 🌊

Interactors **can** and **should** expose Streams, but with a strict limitation:

* **Transformer, Not Source:** The Interactor can take a Stream from a Repository (e.g., `playlistListStream`), `map` it, `filter` it, and return it as a derived Stream (e.g., `getVisualPlaylistStream`).
* **No StreamControllers:** The Interactor must **never** instantiate a `StreamController` or manually add events to a stream. That implies holding state.
* *Why?* If the Interactor holds a Controller, it holds memory. If you navigate away and come back, that memory might be stale or duplicated.
* *Rule:* Only Repositories (which are already instantiated) manage Stream Controllers. Interactors only **pipe** and **transform** them.


### 4. Shared Functionality via Mixins 🧩

Do not use class inheritance (e.g., `BaseInteractor`) to share business logic. It leads to fragile "God Classes."

Instead, use **Mixins** to plug in specific infrastructure capabilities:

* **`AnalyticsMixin`**: Adds `logEvent()` capabilities.
* **`CheckConnectionMixin`**: Adds `checkConnection()` capabilities.
* **`LibraryMixin`**: Adds quick access to common library repos.

### 5. Inline Construction & Passing Parameters 🏗️

A common architectural pattern in Kondo is **inline construction** of the Interactor inside the `KondoProvider` instantiation block.

Because the Interactor is dedicated to a specific feature or screen instance, you can pass **route arguments or entity identifiers (like `productId`, `userId`, or `orderId`) directly into the Interactor constructor** as immutable `final` fields:

#### Why pass parameters to the Interactor instead of the Hako?
1. **Clean Orchestrator:** The Hako stays focused on orchestrating UI events and state without carrying redundant identifiers as fields.
2. **Simplified Method Signatures:** Interactor methods don't need to accept the `id` on every single function call (e.g., `interactor.fetchProduct()` instead of `interactor.fetchProduct(productId)`).
3. **Immutability & Encapsulation:** The identifier is bound at construction time and scoped strictly to the feature's business operations.

```dart
// 1. Define the Interactor with parameters and dependencies
class ProductDetailInteractor {
  ProductDetailInteractor(
    this.productId,
    this.productRepository,
    this.analyticsService,
  );

  final String productId;
  final ProductRepository productRepository;
  final AnalyticsService analyticsService;

  Future<Product> fetchProduct() async {
    final product = await productRepository.getProductById(productId);
    await analyticsService.logEvent('product_viewed', {'id': productId});
    return product;
  }
}

// 2. Construct inline within KondoProvider in your View
class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return KondoProvider<ProductDetailHako>(
      createHako: (context) => ProductDetailHako(
        // Construct the Interactor inline, passing route params and dependencies positionally
        interactor: ProductDetailInteractor(
          productId,
          context.resolveDependency<ProductRepository>(),
          context.resolveDependency<AnalyticsService>(),
        ),
        reactor: ProductDetailReactor(
          dialogLauncher: ProductDetailDialogLauncher(contextResolver: () => context),
        ),
      ),
      builder: (context) => const ProductDetailView(),
    );
  }
}
```

### 6. Calculations, Validations & Pure Utilities 🧮

A common mistake in Flutter architecture is letting "minor" computations, input validation rules, or formatting logic slip into the View widgets or the Hako orchestrator.

In Kondo, **all pure calculations, domain validations, and business utilities belong inside the Interactor**.

#### Examples of Interactor Logic:
* **Form & Input Validation:** Checking email formatting, password strength requirements, or character limits.
* **Pricing & Math Computations:** Calculating checkout totals, discounts, taxes, or shipping costs.
* **Domain Filtering & Sorting:** Filtering a list of products by selected criteria or sorting items.
* **Formatting Utilities:** Transforming raw numbers or timestamps into domain-meaningful structures before handing them to Hako.

```dart
class CheckoutInteractor {
  CheckoutInteractor(this.paymentService);

  final PaymentService paymentService;

  // Validation Rule
  String? validatePromoCode(String code) {
    if (code.trim().isEmpty) return 'Promo code cannot be empty';
    if (!RegExp(r'^[A-Z0-9]{4,10}$').hasMatch(code)) return 'Invalid promo format';
    return null;
  }

  // Pure Calculation
  double calculateTotal({
    required double subtotal,
    required double discountPercentage,
    required double taxRate,
  }) {
    final discounted = subtotal * (1 - discountPercentage);
    return discounted * (1 + taxRate);
  }

  // Domain Rule Boundary
  bool isEligibleForFreeShipping(double total) => total >= 50.0;
}
```

By keeping all validations and calculations in the Interactor:
1. **100% Unit Testable:** You can test business edge cases, math rounding, and validation rules in pure, lightning-fast Dart unit tests without booting the Flutter widget tester.
2. **Zero UI Contamination:** Widgets merely render strings; Hako merely passes input and records results; the Interactor owns the rules.

---

### Summary Checklist for Interactors

1. [ ] **Is it Stateless?** (No mutable variables).
2. [ ] **Is the logic bespoke?** (Methods return exactly what the Hako needs, not generic data).
3. [ ] **Are Services and Repositories injected?** (No `new Repository()` calls).
4. [ ] **Are streams purely transformed?** (No `StreamController` creation).
5. [ ] **Are validations and math computations centralized here?** (No business formulas in Hako or widgets).
6. [ ] **Are shared tools mixins?** (Analytics, connectivity).