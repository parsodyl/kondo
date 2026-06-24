# State Ownership: Where Does This State Live? 🏠

In Kondo, the Interactor documentation draws a clear line between **App State** (persistent, lives in Repositories) and **Feature State** (transient, lives in Hakos). But this binary distinction hides a deeper question that every developer faces when building real apps: **Which Hako owns this Feature State?**

When your widget tree has multiple Triads—a shell feature wrapping a tab navigator, a detail screen inside that tab, a composer widget nested even deeper—state placement becomes a spatial decision. Choosing the wrong owner leads to duplicated data, stale UI, or unnecessary coupling between features.

The golden rule: **Match each state's owner to its natural scope in the widget tree, ensuring no feature holds state wider than it needs and no state is duplicated across siblings.**

---

### The Four Levels of Ownership

When deciding where a piece of state lives, there are four levels to consider. The first three are Kondo's domain—the challenge is picking the right one for each case. The fourth marks the boundary where Kondo ends and Flutter's native widget layer begins.

#### 1. 🌐 Repository (Global / Persistent)

The state outlives every feature. It survives navigation, tab switches, and even app suspension.

* **Examples:** User authentication token, the saved albums list, dark mode preference, unread notification count (raw).
* **Lifetime:** App lifecycle (or session lifecycle).
* **Who accesses it:** Any Interactor in any feature, via dependency injection.
* **Rule:** If the state must survive when *every* screen closes, it belongs here.

#### 2. 🏠 Ancestor Hako (Shared / Scoped)

The state is transient—it dies when this portion of the widget tree is removed—but it serves a **subtree** of child features, not just one.

* **Examples:** Selected tab index in a shell, current user profile summary displayed in a shared app bar, active filter applied across sibling list views, "editing mode" toggle that affects multiple child panels.
* **Lifetime:** Widget subtree lifecycle (e.g., the shell route's lifetime).
* **Who accesses it:** Child features receive the ancestor's data as **constructor parameters** when their Hako is created. Inside the child's own widgets, the standard `context.watchHakoState` pattern is used to read from the child's Hako (which now holds that data as its own Feature State).
* **Rule:** If removing *this* feature should also destroy the state, but multiple *child* features depend on it, it belongs here.

#### 3. 🍃 Leaf Hako (Local / Transient)

The state exists for a single feature bound to a screen or a portion of a screen. No sibling or parent cares about it.

* **Examples:** A locally computed `VisualPlaylist` derived from a Repository stream, the currently selected sort option for a list, a set of validated search results after an API call, loading and error states tied to a business operation, a user's draft selection before confirming.
* **Lifetime:** Single screen or portion of screen lifecycle.
* **Who accesses it:** Only the View directly connected to this Hako.
* **Rule:** If no other feature needs this state and it dies cleanly with the feature, it belongs here.

#### 4. 🎨 Widget (Pure UI Mechanics)

Not every piece of state belongs in Kondo. Kondo's mission is to sweep *business logic* out of the widget tree—not to replace Flutter's native state tools. Flutter already provides `StatefulWidget`, `InheritedWidget`, and your own design system components to manage visual state that has no business meaning.

* **Examples:** Scroll position, "is this card expanded", text field input, animation progress, focus state, a custom dropdown's open/closed toggle, a slider's thumb position.
* **Lifetime:** Managed entirely by the widget that owns it.
* **Rule:** If the state describes *how a widget looks or behaves mechanically*—not *what the feature means*—it belongs in the widget layer. **Kondo does not manage UI mechanics.**

Crucially, if you need UI-mechanical behavior, **isolate it into a dedicated custom widget.** Do not mix Kondo Feature State and widget-level UI state in the same widget. A widget should either consume Hako state via `watchHakoState` (a Kondo View) *or* manage its own visual mechanics via `StatefulWidget` (a UI component)—but not both.

> **Note:** This separation matters for both developers and agents. When Kondo state and UI-mechanical state coexist in the same widget, it becomes ambiguous whether a piece of state should be updated via `set<T>()` in the Hako or via `setState()` in the widget. Extract the mechanical behavior into a custom component, and let the Kondo View compose it. Kondo enters the picture only when the *output* of that component (e.g., the selection made in a dropdown) has business significance for the feature.

---

### The Decision Tree 🌳

When you encounter a new piece of state, walk through these questions in order:

**Q1: Is this just UI mechanics?**
→ Yes: **Widget layer.** Isolate it into a dedicated custom widget using `StatefulWidget` or your design system. Kondo is not needed.
→ No: Continue.

**Q2: Does this state outlive all screens?**
→ Yes: **Repository.**
→ No: Continue.

**Q3: Does more than one feature in the current subtree need this state?**
→ Yes: **Ancestor Hako** (the nearest common ancestor of all consumers).
→ No: Continue.

**Q4: Does this feature need to *react* to a Repository-level change?**
→ Yes: The **source of truth** stays in the Repository. The Leaf Hako's Interactor exposes a stream, and the Hako uses `connectStream` to create a **local projection** of that data as Feature State.
→ No: **Leaf Hako.** The state is purely local.

> **Note:** Q4 is the most commonly misunderstood step. The answer is *not* "put it in the Repository." The answer is: the Repository holds the **truth**, but the Hako holds a **projection** of that truth, shaped for its specific UI section. The Interactor transforms; the Hako binds.

---

### Passing Data to Child Features 📬

Once you know *where* state lives, the next question is *how* a child feature receives it. This decision has a subtle but critical implication: **constructor parameters are static snapshots**, while **stream connections are live wires.**

Choosing wrong leads to stale UI—a child Hako displaying outdated data because its constructor value was captured once and never refreshed.

#### When Constructor Parameters Are Safe ✅

If the data comes from an **Ancestor Hako** (via its `KondoProvider`), passing it as a constructor parameter to the child Hako is the most natural and correct approach.

*Why?* When the Ancestor Hako updates its state, the ancestor's View rebuilds. This rebuild tears down the child `KondoProvider`, destroying the old child Hako and creating a fresh one with the new constructor value. The child's entire Triad is reconstructed—so the "static" parameter is never stale.

```dart
// ✅ Safe: Parent state change destroys and recreates the child Triad
KondoProvider<SongDetailHako>(
  createHako: (context) => SongDetailHako(
    // This album comes from the parent Hako's state.
    // When the parent updates, this entire provider rebuilds.
    album: parentAlbum,
    interactor: context.resolveDependency<SongDetailInteractor>(),
    reactor: SongDetailReactor(...),
  ),
  builder: (context) => const SongDetailView(),
)
```

#### When Constructor Parameters Are Dangerous ❌

The danger arises when the **parent Hako** already projects Repository data via `connectStream`, passes that data to a **child Hako** through its constructor, and the **child also subscribes** to the same Repository stream via its own `connectStream`. This creates two competing update paths for the same data:

1. The Repository emits a change → the parent's projection updates → the parent View rebuilds → the child's `KondoProvider` is destroyed and recreated with the new constructor value.
2. The same Repository emission → the child's own `connectStream` fires → tries to update state on a Hako that is simultaneously being destroyed and recreated.

This is both **confusing** (unclear which path "owns" the update) and **dangerous** (race conditions between destruction and stream updates).

```dart
// ❌ Anti-pattern: Two competing update paths for the same data
// Parent Hako projects the favorite status from the Repository
class PlaylistHako extends IRKondoHako<PlaylistInteractor, PlaylistReactor> {
  PlaylistHako(...) : super((register) {
    register(const PlaylistContentState());
  }) {
    // Parent subscribes to favorites — its projection includes isFavorited
    connectStream<PlaylistContentState>(
      stream: interactor.getPlaylistStream().map(PlaylistContentState.fromDomain),
    );
  }
}

// Parent passes the projected data to the child via constructor
KondoProvider<SongDetailHako>(
  createHako: (context) => SongDetailHako(
    // This comes from the parent's projection — when it changes,
    // this entire provider is destroyed and recreated.
    song: parentPlaylistState.selectedSong,
    ...
  ),
  ...
)

// Child ALSO subscribes to the same Repository — competing with the parent rebuild!
class SongDetailHako extends IRKondoHako<SongDetailInteractor, SongDetailReactor> {
  SongDetailHako({required this.song, ...}) : super((register) {
    register(SongHeaderState.fromDomain(song));
  }) {
    // 💥 This stream fires at the same time the parent destroys this Hako!
    connectStream<SongHeaderState>(
      stream: interactor.getSongStream(song.id).map(SongHeaderState.fromDomain),
    );
  }
}
```

**The fix:** Choose **one** update path. Either:

* **Constructor only:** The parent projects the data and passes it down. The child does *not* subscribe to the same source. When the parent updates, the child is cleanly recreated.
* **Stream only:** The child subscribes to the Repository stream via its own Interactor. The parent does *not* pass the same data as a constructor parameter—it passes only stable identifiers (e.g., an ID) that the child uses to set up its own `connectStream`.

```dart
// ✅ Correct: Child subscribes independently using a stable identifier
KondoProvider<SongDetailHako>(
  createHako: (context) => SongDetailHako(
    // Only the ID is passed — stable, won't trigger parent rebuilds
    songId: selectedSongId,
    ...
  ),
  ...
)

class SongDetailHako extends IRKondoHako<SongDetailInteractor, SongDetailReactor> {
  SongDetailHako({required this.songId, ...}) : super((register) {
    register(const SongHeaderState());
  }) {
    // Single update path: the child owns its own projection
    connectStream<SongHeaderState>(
      stream: interactor.getSongStream(songId).map(SongHeaderState.fromDomain),
    );
  }

  final String songId;
}
```

#### The Decision Matrix

| Data Source | Approach | Rationale |
|---|---|---|
| Ancestor Hako (parent projection) | **Constructor parameter** — child does not subscribe to the same source | Parent rebuild recreates the child cleanly |
| Repository (child needs live updates) | **`connectStream` projection** — pass only stable identifiers via constructor | Child owns its own update path |
| Repository (static for this screen) | **Constructor parameter** (e.g., an ID, a route argument) | Value never changes during the child's lifetime |
| Leaf Hako itself | **`set<T>()` internally** | Standard local state management |

**The Rule:** Never create two competing update paths for the same data. If the parent projects it, the child receives it via constructor and trusts the parent. If the child needs to subscribe independently, the parent passes only stable identifiers—not the projected data itself.

---

### Applying the Principles: Common Scenarios

#### 1. The Shared Badge Count 🔴

A notification badge appears in the bottom navigation bar *and* inside a notification list screen. Where does the count live?

* **Scenario A: The Source of Truth**
  The raw `unreadCount` is **App State**. It originates from a push notification service or a database query.
  * *Owner:* `NotificationRepository` (singleton).
  * *Why:* It must survive tab switches and screen pops.

* **Scenario B: The Display Projection**
  The shell's bottom bar needs a `BadgeState` (maybe formatted as "99+" for large counts). The notification list screen needs a `NotificationListState`.
  * *Owner:* Each Hako creates its own **local projection** from the same Repository stream.
  * *Why:* The *shape* of the data differs per feature (a badge string vs. a list of items), but the *source* is shared.

**The Rule:** When multiple features display the *same truth* differently, the Repository holds the truth and each Leaf Hako projects its own view via `connectStream`. Do **not** hoist a "shared display state" into an Ancestor Hako unless the ancestor itself needs to orchestrate based on it.

#### 2. The Tab Selection 🗂️

A `ShellFeature` manages a bottom navigation bar with three tabs. Which tab is currently selected?

* **Scenario A: Pure Navigation State**
  If tab selection is handled entirely by the router (e.g., `GoRouter` with `StatefulShellRoute`), then the selection state lives **in the router**, not in any Hako.
  * *Owner:* The routing framework.
  * *Why:* The router already manages this lifecycle natively.

* **Scenario B: Orchestrated Tab State**
  If the shell needs to react to tab changes—e.g., resetting a child feature's scroll position, triggering an analytics event, or conditionally showing a FAB—then the selection is **Feature State** in the Shell Hako.
  * *Owner:* `ShellHako` with a `NavigationBarState`.
  * *Why:* The Hako needs to *orchestrate* based on the selection, not just render it.

**The Rule:** If the ancestor only *renders* the selection, let the router own it. If the ancestor needs to *react* to the selection (orchestrate children, trigger side effects), promote it to a `SectionState` in the Ancestor Hako.

#### 3. The Favorite Heart ❤️

A user can "favorite" a song. The heart icon appears on the song detail screen, in a playlist view, and in the player bar. Where does `isFavorited` live?

* **Scenario A: The Source of Truth**
  The definitive list of favorited song IDs is **App State**.
  * *Owner:* `FavoritesRepository`.
  * *Why:* Favoriting must persist across screens, app restarts, and sync to a backend.

* **Scenario B: The Local Reflections**
  Each feature subscribes independently via its own Interactor.
  * *Song Detail Hako:* `connectStream` maps `FavoritesRepository.isFavorited(songId)` into `SongHeaderState(isFavorited: ...)`.
  * *Playlist Hako:* `connectStream` maps the full favorites list into each `PlaylistItemState`.
  * *Player Bar Hako:* `connectStream` maps the current track's favorite status into `NowPlayingState`.

**The Rule:** When siblings need the same truth, they each subscribe independently to the Repository. Do **not** create an Ancestor Hako just to "broadcast" the favorite state downward—that's the Repository's job.

#### 4. The Cross-Feature Filter 🔍

A search screen has a filter panel. When a filter is applied, both a "Results List" tab and a "Results Map" tab should update.

* **Scenario A: Ancestor Owns the Filter**
  The filter is shared state that two child features consume.
  * *Owner:* `SearchHako` (the parent that contains both the filter panel and the tab views) with a `FilterPanelState`.
  * *Why:* The filter's lifecycle is tied to the search screen, not to either child tab individually.

* **Scenario B: Each Tab Applies Independently**
  If the tabs can have *different* filters (e.g., the Map tab adds a "radius" filter), then each tab has its own filter state.
  * *Owner:* `ResultsListHako` and `ResultsMapHako`, each with their own `FilterState`.
  * *Why:* The filters diverge—they are not truly shared.

**The Rule:** If two features need the *exact same* state instance, hoist it to their nearest common ancestor. If they need *similar but divergent* state, keep it local.

---

### The Roommate Test 🏘️

Following Kondo's house metaphor (Features are rooms), use this mental model to validate your placement:

> *"If I remove this room from the house, should this piece of furniture disappear too?"*

* **Yes, and no other room needs it** → Leaf Hako (it's furniture in a private room).
* **Yes, but the hallway and other rooms reference it** → Ancestor Hako (it's shared furniture in the hallway).
* **No, it should survive even if the entire floor is demolished** → Repository (it's part of the house's foundation).

**If your Hako looks like this:**

```dart
// ❌ Bad: Leaf Hako hoarding shared state
class SongDetailHako extends IRKondoHako<SongDetailInteractor, SongDetailReactor> {
  SongDetailHako(...) : super((register) {
    register(SongHeaderState(...));
    register(GlobalPlayerState(...));  // Why is this here? Other screens need it too!
  });
}
```

* *Critique:* `GlobalPlayerState` outlives this screen. When the user pops back, the player should keep playing. This state belongs in a Repository or an Ancestor Hako.

```dart
// ✅ Good: Each level owns its natural scope
// Repository: FavoritesRepository (persists across everything)
// ShellHako: register(PlayerBarState(...))  (shared across tabs)
// SongDetailHako: register(SongHeaderState(...))  (dies with this screen)
```

---

### An Important Note: Projections Are Not Duplication ⚠️

A common concern: "If three Leaf Hakos each `connectStream` the same Repository data, isn't that state duplication?"

**No.** Each Hako holds a **projection**—a view-specific transformation of the shared truth. The Repository holds `List<FavoriteSong>`. One Hako holds `SongHeaderState(isFavorited: true)`. Another holds `PlaylistState(items: [...])`. These are different shapes serving different UI sections.

Duplication would be two Hakos holding the *same* `List<FavoriteSong>` for the *same* visual purpose. If that happens, you've missed an Ancestor Hako.

**The Rule:** Multiple projections of the same source = correct architecture. Multiple copies of the same projection = missed abstraction.

---

### Summary Checklist

Use this checklist when reviewing state placement:

- [ ] **Is this state just UI mechanics?** (If yes, isolate it into a dedicated custom widget—do not manage it with Kondo).
- [ ] **Are Kondo state and widget-level state mixed in the same widget?** (They shouldn't be—separate them into distinct widgets).
- [ ] **Does the state outlive all features?** (If yes, it belongs in a Repository, not a Hako).
- [ ] **Does more than one child feature consume this state?** (If yes, consider an Ancestor Hako or independent Repository subscriptions).
- [ ] **Is the Leaf Hako holding state that other screens also need?** (If yes, extract to the appropriate scope).
- [ ] **Are siblings subscribing independently to the same Repository stream?** (This is correct—do not hoist a "broadcast Hako" unnecessarily).
- [ ] **Does the Ancestor Hako only render the state, or does it orchestrate based on it?** (If only rendering, the state might belong in a simpler scope like the router).
- [ ] **Does the state pass the Roommate Test?** (Can you justify the owner by asking "who disappears when this room is removed?").
