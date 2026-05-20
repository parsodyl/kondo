# The Hako: The Orchestrator 📦

The **Hako** is the cornerstone of a feature. It is the central hub where everything connects. While it contains no Flutter widgets, the Hako is entirely **aware of the View's interface**. It knows *what* state the UI needs to render and *which* events the UI can trigger.

Building a robust Hako comes down to mastering four areas: State Structure, Internal Composition, Event Naming, and UI Integration.

---

### 1. Structuring the State (The Manifest) 🏗️

The Hako's constructor acts as a "Manifest" or a "Table of Contents" for your UI.

**The Golden Rule:** Model the state according to **Semantic Sections** of the view, rejecting both "Monolithic State" (one big class) and "Raw Data" dumps.

When defining state, ask yourself: *"If I drew boxes on a wireframe, what would I label them?"* * ✅ **Use:** `HeaderState`, `TracklistState`, `PlayerBarState`.

* ❌ **Avoid:** `AlbumDetailState` (Too monolithic) or `List<Track>` (Too primitive).

> 📖 **Deep Dive:** For full rules on granularity, handling global loading vs. local loading, and why we strictly reject Hako string labels, read the [Structuring State Guide](https://www.google.com/search?q=structuring_state.md).

---

### 2. Composing Internal State (The Identity Rule) 🧩

Once you have defined the outer shell (the Semantic Section), what goes inside it?

A UI section is usually a cocktail of three ingredients:

1. **Domain Data** (Entities from the Interactor)
2. **User Input** (Text, Toggles from the View)
3. **Transient Status** (Loading flags, error messages)

To compose these, follow the **Identity Rule**: Does the data have an ID that the Interactor will need later?

* **The Smart Wrapper (1 Identity) 🍬**
* *Use when:* Displaying a single domain entity.
* *How:* Wrap the Domain Entity and add UI flags. By keeping the entity, the Hako always has the `id` ready when the user taps "Delete" or "Edit".
* *Example:* `AlbumHeaderState(this.album, this.isLoading)`


* **The Composite Wrapper (N Identities) 🧺**
* *Use when:* Building dashboards or headers that combine disparate data.
* *How:* Wrap multiple distinct entities together.
* *Example:* `HomeHeaderState(this.user, this.weatherInfo)`


* **The Pure State (0 Identities) 📝**
* *Use when:* Capturing user input or managing transient UI flow.
* *How:* Define explicit primitive fields. There is no domain entity *yet*.
* *Example:* `CrateFormState(this.name, this.color)`



---

### 3. Naming Event Handlers (The Intent) 🏷️

The Hako acts as the contract between your View and your Logic. The names of its methods must reflect **what the user can do**, not how the UI is implemented.

**The Golden Rule:** Name handlers based on User Intent or Logical Element, avoiding both Widget Implementation details and abstract Business Logic terms.

**The Formula:** `on` + **[Subject]** + **[Trigger Suffix]**.

* ✅ **Good:** `onAddTap`, `onQueryChanged`, `onFilterToggled`
* ❌ **Bad (Widget leak):** `onFabTap`, `onTextFieldChange`
* ❌ **Bad (Logic leak):** `createAlbum`, `search`

> 📖 **Deep Dive:** For the complete naming matrix and the "Wireframe Test", read the [Naming Event Handlers Guide](https://www.google.com/search?q=naming_event_handlers.md).

---

### 4. Handling Streams 🌊

Because the Interactor is stateless, the Hako must often consume streams of data to keep the UI updated. Kondo provides distinct tools depending on *why* you are listening to the stream:

1. **`connectStream` (The Auto-Pilot):**
   Use this when data from the Interactor should directly become View state. Use Dart's `.map()` to transform the domain stream into a State stream before connecting.
```dart
connectStream<CrateContentState>(
  stream: interactor.getVisualCrateStream(id).map(CrateContentState.new),
);

```


2. **`listenStream` (The Trigger):**
   Use this when a stream event should trigger *logic* or a side effect, rather than just dumping data into the registry.
```dart
listenStream(
  stream: interactor.getAlbumListStream(),
  onData: (_) => _refreshAlbums(), 
);

```


3. **`await for` (The Process Driver):**
   Use this inside `onInit()` when you need to manually drive a complex, sequential state machine (like a multi-step sync process).

---

### 5. Exposing State to the UI (The Context Extension) 🔌

To keep your Flutter `build` methods clean and readable, **always** provide an extension on `BuildContext` at the bottom of your Hako file.

This acts as the public interface for the View, hiding the generic boilerplate and providing "Intellisense" discovery for developers.

**The Rule:** Strip the word "State" from the watcher methods. We want the UI to read naturally: *"Watch the Tracklist"*, not *"Watch the Tracklist State object"*.

```dart
// At the bottom of album_detail_hako.dart

extension AlbumDetailHakoContextExtension on BuildContext {
  // 1. Get the Hako to trigger events
  AlbumDetailHako get albumDetailHako => readHako<AlbumDetailHako>();

  // 2. Watch specific semantic sections (Notice the dropped "State" suffix)
  AlbumHeaderState watchAlbumHeader() =>
      watchHakoState<AlbumDetailHako, AlbumHeaderState>();

  TracklistState watchTracklist() =>
      watchHakoState<AlbumDetailHako, TracklistState>();
}

```

**Usage in the View:**

```dart
Widget build(BuildContext context) {
  final header = context.watchAlbumHeader(); // Clean, readable, type-safe!
  
  return Column(
    children: [
      Text(header.album.title),
      IconButton(
        icon: Icon(Icons.play),
        onPressed: context.albumDetailHako.onPlayTap, 
      )
    ]
  );
}

```