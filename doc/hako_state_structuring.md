# Kondo Hakos: Structuring State
In Kondo, the **Hako** constructor serves as the "Table of Contents" for your User Interface. Just as we want Event Handlers to describe what the user **can do**, we want our State Objects to describe what is meaningful that the user **can see**.

The golden rule: **Model the state according to semantic sections of the view, rejecting both "Monolithic State" (one big class) and "Raw Data" dumps.**

---

### The Three Levels of Structuring

When defining the state in your Hako, you generally face three options. In Kondo, we aim for the "Sweet Spot" in the middle.

#### 1. Data-Oriented (Too Low-Level) ❌

* **Examples:** `List<Track>`, `AsyncSnapshot`, `String`, `int`
* **The Problem:** These raw data types describe *what* the data is, but not *where* it is or what role it plays. Is that `List<Track>` the main album tracklist? A generic "You might also like" scroll? A search result? You cannot visualize the screen structure from these types.
* **Verdict:** Avoid. This adds ambiguity and makes the Hako harder to read.

#### 2. Monolithic (Too High-Level) ⚠️

* **Examples:** `AlbumDetailState`, `HomePageState`, `ScreenViewModel`
* **The Problem:** This hides the complexity inside a single massive class. You cannot see the screen's composition until you open the file and parse its properties. It also tends to trigger unnecessary rebuilds—changing a small `isFavorite` boolean might force the whole screen to evaluate.
* **Verdict:** Avoid most of the times. This obscures the UI structure and hurts performance.

#### 3. Semantic Sectioning (The Sweet Spot) ✅

* **Examples:** `AlbumHeaderState`, `TracklistState`, `PlayerBarState`
* **The Why:** These names describe the **semantic regions** of the screen. I can close my eyes and visualize the main layout just by reading these names: there is a header, a collection of tracks, and a player bar.
* **Verdict:** **Preferred.** This makes the Hako transparent and ensures widgets only rebuild when their specific section changes.

---

### The Naming Formula

To achieve consistency, use this straightforward formula for naming your State Objects:

> **[SemanticSection]** + `State` (or `HakoState`)

* **SemanticSection:** A name that **describes the section's purpose or role** in the current screen.
#### How should I identify Semantic Section names?

Ask yourself: *"If I drew boxes on a wireframe, what would I label them?"*

* **Screen orientation:** `Header`, `Content`, `Footer`, `Sidebar`
* **Functional purpose:** `SearchInput`, `FilterPanel`, `ResultsList`
* **Persistent component:** `PlayerBar`, `NavigationDrawer`, `ModalOverlay`

**Important:** Avoid Flutter widget names in your state objects (e.g., `SliverList`, `GridView`, `Column`, `Stack`). Instead, use semantic names that describe the purpose or role of the section rather than its implementation detail.

#### Examples

| Context | **❌ Data-Oriented** (Avoid) | **⚠️ Monolithic** (Avoid most of the times) | **✅ Semantic Section** (Use) |
| --- | --- | --- | --- |
| **Album Info** | `Album` | `AlbumDetailState` | **`AlbumHeaderState`** |
| **Track List** | `List<Track>` | `AlbumDetailState` | **`TracklistState`** |
| **Search Bar** | `String` | `SearchScreenState` | **`SearchInputState`** |
| **Player** | `PlaybackInfo` | `MainScreenState` | **`PlayerBarState`** |

---

#### Concrete Example: Album Detail Screen

Looking at an album detail screen, you might identify:

```dart
super((register) {
  register(AlbumHeaderState(...)); // Top card: cover art, title, artist 
  register(TracklistState(...)); // Scrollable list of tracks 
  register(PlayerBarState(...)); // Bottom-fixed playback controls
});
```

### Granularity: When to Split? ✂️

Once you've identified the major sections, ask: "Should any of these sections be split further?"

How small is too small? We don't want a state object for every single piece of UI, use these rules to decide when to create a new one in the Hako:

* **Independent Lifecycle:** Can this subsection load, fail, update, or change status (enabled/disabled, valid/invalid) independently from other subsections? Both conditions must be true:
    * The subsection has its own distinct state that can change separately
    * **AND** the subsection can be displayed/interacted with even when other subsections are in a different state
* **Different Frequency:** Does this subsection update at a different speed? (e.g., a progress bar updating every second vs. the static album title).

**Concrete Examples:**

* Considering **Independent Lifecycle:**
    * ✅ **Split:** `CommentsSectionState` and `VideoPlayerState` — The video can display and play while comments are still loading or failed.
    * ✅ **Split:** `ShippingDetailsFormState` and `PaymentFormState` — Shipping details can be validated while payment info is still being entered.
    * ❌ **Don't Split:** `AlbumTitleState` and `AlbumArtistState` — Both load together from the same source with the same lifecycle.
    * ❌ **Don't Split:** `EmailFieldState` and `PasswordFieldState` — Both validated together; the form submit is enabled/disabled based on combined validity.

* Considering **Different Frequency:**
  * ✅ **Split:** `PlaybackProgressState` (updates every 100ms during playback) and `TrackMetadataState` (updates only on track change)
  * ❌ **Don't Split:** `ProgressBarState` and `TimeStampState` within `PlaybackProgressState` — The progress bar and time display always update together on the same timer tick. Keep them in one state object.

---

### Applying the Principles: Common Scenarios

#### 1. Global vs. Local Loading 🚧

Where do we put the `isLoading` flag? In the section state or a global state?

* **Scenario A: Local Loading (Shimmer/Spinner)**
  If the user can still tap "Back" or interact with other sections (like the Header), the loading status belongs inside the **section state**.
* *State:* `TracklistState.loading()`
* *Visual:* Only the collection area shows a spinner. The header remains visible.


* **Scenario B: Global Loading (Overlay)**
  If the operation prevents *any* interaction (like a critical deletion or initial setup), register a separate **overlay state** at the Hako level.
* *State:* `PageOverlayState` (or `InteractionBlockerState`).
* *Visual:* A full-screen `Stack` with a `ModalBarrier` or loading overlay.



**The Rule:** If it blocks a section, put it in the Section State. If it blocks the page, give it its own 'Overlay' drawer.

**Note:** Information like empty or error states would follow the same pattern. The only difference is the visual treatment (e.g., an error placeholder vs. a loading spinner).

#### 2. Forms 📋

How should I model form state?

* **Scenario A: Simple Forms (Unified Context)**
  Model as a **Single State Object** when all fields share the same lifecycle and validation context.
* *State:* `LoginFormState` with `email`, `password`, `isValid`, `errorMessage`.
* *Why:* The fields are tightly coupled; validation often depends on multiple inputs simultaneously.


* **Scenario B: Complex Forms (Distinct Sections)**
  Split into **Multiple State Objects** when sections meet the standard splitting criteria.
* *State:* `AccountDetailsFormState(...)` + `ProfileSetupFormState(...)`.
* *Why:* Different sections might have **Independent Data** (e.g., fetched from different APIs) or **Independent Status** (e.g., address validation fails, but payment selection remains valid).



**The Rule:** Forms don't require special rules—they follow the standard **Granularity** and **Semantic Sectioning** principles. Model simple forms as a single unit; split complex forms when sections update or fail independently.

**Note:** Kondo is intentionally agnostic about form validation libraries. Choose the form management approach that fits you or your team, then apply Kondo's structuring principles to organize the resulting state.

---

### The "Manifest Test" 📝

The constructor of your Hako acts as the "Manifest" for your UI. You should be able to roughly sketch the screen structure on a whiteboard just by reading the `register` calls.

**If your Hako looks like this:**

```dart
// ❌ Bad: The Raw Data Dump (Ambiguous)
super((register) {
  register(Album(...));          // The header? Or just data?
  register(<Track>[]);           // The content? Or a hidden playlist?
  register(true);                // What is loading? The page? The list?
});

// ❌ Bad: The Monolith (Opaque)
super((register) {
  register(AlbumDetailState.initial()); // What is inside? I have no idea.
});
```

* *Critique:* These hide the structure. I have to open the state file or guess based on variable types to know if this screen has a header, a list, or a player.

**It should look like this:**

```dart
// ✅ Good: The Manifest (Transparent)
super((register) {
  register(AlbumHeaderState(...));      // Top part
  register(TracklistState(...));        // Main content area
  register(AlbumSearchInputState(...)); // Transient search bar
  register(PageOverlayState(...));      // Global blocker
});
```

---

### An Important Note (1): String Labels ⚠️

If you look at the documentation for the underlying [hako package](https://pub.dev/documentation/hako/latest/hako/Hako-class.html), you will notice it supports labeling state objects with `String` keys (e.g., `register<bool>(true, 'isLoading')`).

**In Kondo, we explicitly reject this feature.**

While `hako` is designed to be a flexible tool, **Kondo** is a strict architecture designed for scalability and safety. We avoid String labels for two critical reasons:

1. **Fragility:** "Magic strings" are prone to typos and resist automated refactoring. A typo in a string key (`'isLaoding'`) causes a runtime crash, whereas a typo in a class name causes a compile-time error.
2. **Consistency:** Kondo relies on **Semantic Sectioning**. Using wrapper classes (e.g., `HeaderState`, `FooterState`) enforces a consistent, discoverable structure. Allowing string labels encourages "Primitive Obsession"—registering loose variables like `bool` or `int` that float around without a clear home.

**The Rule:**
Always identify your state by its **Type**, never by a **String Key**.

**❌ Bad: Using Hako's Label Feature**

```dart
// Fragile & Loose
register<bool>(true, 'isHeaderLoading');
register<bool>(false, 'isListLoading');

// Later...
final headerLoading = get<bool>('isHeaderLoading'); // Typo risk!
```

**✅ Good: Using Kondo Wrappers**

```dart
// Robust & Structured
register(HeaderState(isLoading: true));
register(TracklistState(isLoading: false));

// Later...
final headerLoading = get<HeaderState>().isLoading; // Type-safe!

```

### An Important Note (2): Extension Types ⚠️

Dart 3.3 introduced **Extension Types**, which allow you to wrap an underlying object with a new type signature at zero runtime cost.

**In Kondo, these are permitted, but with a strict technical constraint.**

Because extension types are **erased** to their underlying representation at runtime, the Hako registry cannot distinguish between the extension type and the primitive it wraps. For example, `extension type HeaderTitleState(String)` and `String` result in the exact same registry key at runtime.

Therefore, you can use an `extension type` as a lightweight "Single Value Wrapper" **only if that underlying type is unique within the Hako.**

**The Rule:**
Use Extension Types to give semantic meaning to a primitive, but **never** register two extension types that wrap the same primitive in the same Hako.

**✅ Good: Unique Wrapper**
If `SearchQueryState` is the *only* String-based state in this Hako, this is safe, clean, and expressive.

```dart
// Define state type
extension type SearchQueryState(String value) {}

// In Hako
register(SearchQueryState(''));
```

**❌ Critical Failure: Type Collision**
If you try to register two different extension types that wrap the same primitive to represent different UI sections, Hako will see them as the same key, causing a `StateError` at runtime.

```dart
// These define distinct static types...
extension type HeaderTitleState(String value) {}
extension type FooterMessageState(String value) {}

// ...but at runtime, they are BOTH just 'String'.
super((register) {
  register(HeaderTitleState(''));
  register(FooterMessageState('')); // 💥 StateError: This overwrites HeaderTitle!
});
```

**Verdict:** If you need to store multiple "String" values for different sections (e.g., a Header Title and a Footer Message), you **must** use distinct `class` wrappers (e.g., `HeaderState` and `FooterState`) or combine them. Extension types are only for singular, unique values.

---

### Summary Checklist

Use this checklist when reviewing Hako code:

* [ ] **Is the Monolith avoided most of the times?** (No `ScreenState` classes that hold everything).
* [ ] **Are raw data types avoided?** (No `List<Track>` or `String` directly in the registry).
* [ ] **Are UI widgets avoided in names?** (Prefer `Collection` or `Content` over `GridView` or `SliverList`).
* [ ] **Is granularity appropriate?** (States are split based on independent lifecycle and frequency of update?).
* [ ] **Does it pass the Manifest Test?** (Can you sketch/visualize the screen just by reading the `register` calls?).
* [ ] **Are string labels avoided?** (State identified by Type, not String keys).
* [ ] **Are extension types used correctly?** (No duplicate underlying types in the same Hako).