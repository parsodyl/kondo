# Kondo Hakos: Naming Event Handlers

In Kondo, the **Hako** serves as the contract between your View and your Logic. It defines *what* the user can do, not *how* the UI is implemented or exactly *how* the app backend processes it. Choosing the right names for your event handlers is critical for ensuring your code remains readable, resilient to design changes, and clearly separated from business rules.

The golden rule: **Name handlers based on User Intent or Logical Element, avoiding both Widget Implementation details and abstract Business Logic terms.**

---

### The Three Levels of Naming

When naming a method in your Hako, you generally face three options. In Kondo, we aim for the "Sweet Spot" in the middle.

#### 1. Component-Oriented (Too Specific) ❌

* **Examples:** `onFabTap`, `onRedButtonPress`, `onTextFieldChanged`
* **The Problem:** These names couple your logic to specific Flutter widgets. If a designer changes a Floating Action Button (FAB) to an IconButton in the AppBar, your method name `onFabTap` becomes a lie. You either live with confusing code or suffer through tedious refactoring.
* **Verdict:** Avoid. This creates "technical debt" instantly.

#### 2. Business-Oriented (Too Abstract) ❌

* **Examples:** `createAlbum`, `deleteUser`, `updateSearch`
* **The Problem:** These sound like API calls or internal logic functions, not user interactions. They obscure the *cause* of the action. Was the album created because the user tapped a button, or was it an automatic background process? Did the search update because of a debounce timer or a "Submit" key press?
* **Verdict:** Avoid in the Hako public interface. These names usually belong in the **Interactor**, not the Hako's event handlers.

#### 3. Intent-Oriented (The Sweet Spot) ✅

* **Examples:** `onAddTap`, `onShowHiddenToggled`, `onQueryChanged`
* **The Why:** These names describe the **User's Intent** (`Add`, `Show Hidden`, `Query`) and the **Interaction Type** (`Tap`, `Toggled`, `Changed`). They tell you exactly what the user did without revealing which widget they touched or assuming the underlying business complexity.
* **Verdict:** **Preferred.** This style is robust. Whether `onAddTap` is triggered by a FAB, a Menu Item, or even a Keyboard Shortcut, the name remains accurate.

---

### The Naming Formula

To achieve consistency, use this simple formula for your Hako methods:

> `on` + **[Subject]** + **[Trigger suffix]**

* **Subject:** The logical thing the user is interacting with. This could be:
  - The **user intent** being performed (`Add`, `Save`, `Delete`)
  - The **data entity** being manipulated (`Album`, `Track`, `Query`)
  - The **UI affordance** abstracted from its widget (`ShowHidden`, `Filter`, `Sort`)
  - *For Lifecycle events, the subject is the **View** and it is usually implicit.*
* **Trigger suffix:** The abstract interaction (Tap, Swipe, Toggle, Initialization, etc.), declined according to the nature of the interaction:


| Interaction Type | Suffix Style | Use Case | Examples                                                  |
| --- | --- | --- |-----------------------------------------------------------|
| **Stateless Command** | **Interaction Noun** | Buttons, Icons, FABs. The user is saying "Do this." | `onAddTap` `onSaveTap` `onArchiveSwipe`                   |
| **Value Update** | **Past-Tense Verb** | Text Fields, Sliders. The user is modifying data. | `onQueryChanged` `onVolumeChanged` `onNameChanged`        |
| **Selection / Switch** | **Past-Tense Verb** | Lists, Checkboxes, Switches. The user picks or flips an option. | `onFilterToggled` `onAlbumSelected` `onSortOrderSelected` |
| **Lifecycle Event** | **Lifecycle Verb** | System Triggered. When the View is created, resumed, or destroyed. | `onInit` `onDispose` `onResume`                           |


#### Examples:

| Context                 | **❌ Component** (Avoid) | **❌ Business** (Avoid)      | **✅ Intent / Logical** (Use)            |
|-------------------------| --- |-----------------------------|-----------------------------------------|
| **Adding an Item**      | `onFabTap` | `addAlbum`                  | **`onAddTap`**                          |
| **Typing Search**       | `onTextFieldChange` | `search`                    | **`onQueryChanged`**                    |
| **Selecting List Item** | `onInkWellTap` | `openDetails`               | **`onItemTap`** / **`onAlbumSelected`** |
| **Filter Toggle**       | `onCheckboxChanged` | `updateFilter`              | **`onFilterToggled`**                   |
| **Grid vs. List** | `onGridButtonTap` | `changeAlbumCollectionView` | **`onViewModeToggled`**                 |

---

### Handling Duplicate Actions

Sometimes, the same "Business Action" can be triggered from two different places in the UI (e.g., "Liking" a song from a list vs. "Liking" from the player bar).

* **Don't** name them by widget: `onListItemLikeTap` vs `onPlayerBarLikeTap`.
* **Do** name them by **Context**:
* `onTrackLikeTap(TrackId id)` (Implies selection from a collection)
* `onNowPlayingLikeTap()` (Implies the currently active context)

---

### The "Wireframe Test" 📝

You should be able to reconstruct the UI structure in your head just by reading the Hako's public methods. This is called the "Wireframe Test."

**If your Hako looks like this:**

```dart
// ❌ Bad: Implementation details leak in
void onFabTap();
void onTextFieldChange();
void onSwitchToggled();

// ❌ Bad: Business logic obscures the UI
void createAlbum();
void search();
void updateSettings();
```

* *Critique:* When I read the code, I know I used a FAB and a Switch, or that I am calling certain APIs, but I have no idea what this screen *looks like* or how the user interacts with it.

**It should look like this:**

```dart
// ✅ Good: Describes the Interface Contract
// I can "see" this UI: A list of items, a search bar, and a filter toggle.
void onSearchQueryChanged(String query); // -> Needs an Input
void onShowHiddenToggled(bool value);    // -> Needs a Toggle/Checkbox
void onAlbumSelected(Album album);       // -> Needs a List/Grid
void onAddAlbumTap();                    // -> Needs a Trigger Action
```

---

### Summary Checklist

Use this checklist when reviewing Hako code:

* [ ] **Does it start with `on`?** (Indicates an event handler, distinguishing it from helper methods).
* [ ] **Is the widget name removed?** (No `Fab`, `Button`, `InkWell`, `GestureDetector`).
* [ ] **Is the business logic name avoided?** (It shouldn't act as a direct alias for an API call like `saveUser()`; it should reflect the interaction `onSaveTap()`).
* [ ] **Does it pass the Wireframe Test?** (Can you visualize the UI element—like a list, input, or toggle—just by reading the name?).
