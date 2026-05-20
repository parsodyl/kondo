## Global vs. Local State: The Scope Decision 🎯

One of the most critical decisions when structuring UI state is: **"Does this state belong to a specific section, or does it affect the entire screen?"**

The golden rule: **Model state at the narrowest scope that can visualize it.**

---

### The Core Principle

Ask yourself: *"If I drew a box around the UI elements affected by this state change, would that box cover a single section or the entire screen?"*

* **Local State (Section-Scoped):** The state affects only one semantic region. Other sections remain interactive and unaffected.
* **Global State (Screen-Scoped):** The state affects the entire screen or prevents interaction with multiple sections simultaneously.

---

### Scenario 1: Loading States 🔄

#### Local Loading (Section State)
The operation is fetching data for **one section**, but the rest of the screen remains usable.

**Example:** Loading album tracks while the header and player controls remain visible and interactive.

```dart
// State
register(AlbumHeaderState(...));        // ✅ Still visible
register(TracklistState.loading());     // 🔄 Loading indicator here
register(PlayerBarState(...));          // ✅ Still interactive
```


**Visualization:**
```
┌─────────────────────────┐
│   Album Header          │ ← Still visible
├─────────────────────────┤
│   [Spinner/Shimmer]     │ ← Only this section loading
│   Loading tracks...     │
├─────────────────────────┤
│   Player Controls       │ ← Still interactive
└─────────────────────────┘
```


#### Global Loading (Overlay State)
The operation blocks **all interaction** across the entire screen.

**Example:** Initial app setup, critical data sync, or destructive operations requiring confirmation.

```dart
// State
register(AlbumHeaderState(...));
register(TracklistState(...));
register(PlayerBarState(...));
register(PageOverlayState.loading());   // 🚫 Blocks everything
```


**Visualization:**
```
┌─────────────────────────┐
│ ╔═══════════════════╗   │
│ ║   [Spinner]       ║   │ ← Modal overlay
│ ║   Loading...      ║   │
│ ╚═══════════════════╝   │
│  (Everything dimmed)    │
└─────────────────────────┘
```


**The Rule:** If users can interact with other sections, keep loading state **local**. If the entire screen must wait, use a **global overlay state**.

---

### Scenario 2: Error States ❌

#### Local Error (Section State)
One section fails to load, but other sections display successfully.

**Example:** Track list fails to fetch, but album metadata and player are fine.

```dart
// State
register(AlbumHeaderState.loaded(...));
register(TracklistState.error('Network timeout'));
register(PlayerBarState(...));
```


**Visualization:**
```
┌─────────────────────────┐
│   Album: "Dark Side"    │ ← Loaded successfully
│   Artist: Pink Floyd    │
├─────────────────────────┤
│   ⚠ Failed to load      │ ← Error in this section
│   [Retry Button]        │
├─────────────────────────┤
│   Player Controls       │ ← Still works
└─────────────────────────┘
```


#### Global Error (Overlay State)
A critical failure requires user attention before continuing.

**Example:** Authentication expired, critical API unavailable, or unrecoverable error.

```dart
// State
register(AlbumHeaderState(...));
register(TracklistState(...));
register(PageOverlayState.error(
  message: 'Session expired',
  action: ErrorAction.relogin
));
```


**Visualization:**
```
┌─────────────────────────┐
│ ╔═══════════════════╗   │
│ ║   ⚠ Error         ║   │
│ ║   Session expired ║   │ ← Modal dialog
│ ║   [Re-login]      ║   │
│ ╚═══════════════════╝   │
│  (Screen dimmed)        │
└─────────────────────────┘
```


---

### Scenario 3: Empty States 📭

#### Local Empty (Section State)
One section has no data, but the screen context remains meaningful.

**Example:** Album loaded, but no tracks available yet (new album, pre-release, etc.).

```dart
// State
register(AlbumHeaderState.loaded(...));
register(TracklistState.empty());       // Empty state here
register(PlayerBarState.disabled());
```


**Visualization:**
```
┌─────────────────────────┐
│   Album: "Unreleased"   │ ← Has metadata
│   Coming Soon: 2026     │
├─────────────────────────┤
│   📭 No tracks yet      │ ← Empty illustration
│   Check back later!     │
├─────────────────────────┤
│   [Player Disabled]     │ ← Contextual state
└─────────────────────────┘
```


#### Global Empty (Full Screen State)
The entire screen context is empty (e.g., first-time user, no data at all).

**Example:** User opens "Favorites" but hasn't favorited anything yet.

```dart
// State
register(PageEmptyState(
  illustration: 'empty_favorites',
  message: 'No favorites yet',
  action: 'Explore music'
));
```


**Visualization:**
```
┌─────────────────────────┐
│                         │
│       🎵                │
│   No favorites yet      │ ← Full-screen empty state
│                         │
│   [Explore Music]       │
│                         │
└─────────────────────────┘
```


---

### Scenario 4: Validation States ✓

#### Local Validation (Section State)
Individual form sections or fields validate independently.

**Example:** Multi-step form where shipping details validate separately from payment.

```dart
// State
register(ShippingFormState(
  isValid: true,
  fields: {...}
));
register(PaymentFormState(
  isValid: false,               // ❌ Invalid
  errorMessage: 'Invalid card'
));
```


**Visualization:**
```
┌─────────────────────────┐
│ Shipping Details   ✓    │ ← Valid section
│ [Address fields...]     │
├─────────────────────────┤
│ Payment Info       ❌   │ ← Invalid section
│ ⚠ Invalid card number   │
│ [Card fields...]        │
└─────────────────────────┘
```


#### Global Validation (Page State)
The entire form must be valid before proceeding (e.g., enabling submit).

**Example:** Login form where both email and password must be valid.

```dart
// State
register(LoginFormState(
  email: 'user@example.com',
  password: '••••••',
  isValid: true,                // ✓ Both fields valid
  canSubmit: true
));
```


**Visualization:**
```
┌─────────────────────────┐
│   Login                 │
│   Email:    ✓           │
│   Password: ✓           │
│                         │
│   [Login] ← Enabled     │ ← Global validation state
└─────────────────────────┘
```


---

### Scenario 5: Selection/Focus States 🎯

#### Local Selection (Section State)
Selection within a specific list or section.

**Example:** Selected track in a playlist (highlights one item, doesn't affect other sections).

```dart
// State
register(TracklistState(
  tracks: [...],
  selectedTrackId: 'track-42'   // Local to this list
));
```


**Visualization:**
```
┌─────────────────────────┐
│   Track 1               │
│ ▶ Track 2 [Selected]    │ ← Highlighted row
│   Track 3               │
└─────────────────────────┘
```


#### Global Selection (Overlay State)
Selection affects the entire screen (e.g., multi-select mode with action bar).

**Example:** Bulk delete mode with floating action buttons.

```dart
// State
register(TracklistState(...));
register(SelectionModeState(
  selectedIds: ['track-1', 'track-3'],
  actions: [SelectionAction.delete, SelectionAction.share]
));
```


**Visualization:**
```
┌─────────────────────────┐
│ ☑ Track 1               │
│ ☐ Track 2               │ ← Checkboxes appear
│ ☑ Track 3               │
├─────────────────────────┤
│ [Delete] [Share] [×]    │ ← Global action bar
└─────────────────────────┘
```


---

### The Decision Tree 🌳

Use this flowchart when deciding scope:

```
Does this state change affect multiple sections?
│
├─ NO → Use LOCAL (Section State)
│       Example: TracklistState.loading()
│
└─ YES → Does it block interaction with other sections?
         │
         ├─ NO → Still use LOCAL states
         │       (multiple sections update independently)
         │
         └─ YES → Use GLOBAL (Overlay/Page State)
                 Example: PageOverlayState.loading()
```


---

### Summary: The Visualization Test 👁️

Before registering state, ask:

**"If I drew a box around the affected UI, would it be:"**
* **A single section?** → Local section state
* **Multiple independent sections?** → Multiple local states
* **The entire screen (with blocking/dimming)?** → Global overlay state
* **The entire screen (as primary content)?** → Global page state

**The Rule:** Always choose the **narrowest scope** that accurately represents what the user sees changing on screen.

---

### Examples Summary Table

| **State Type** | **Local (Section)** | **Global (Screen/Overlay)** |
|----------------|---------------------|------------------------------|
| **Loading** | `TracklistState.loading()` | `PageOverlayState.loading()` |
| **Error** | `TracklistState.error(...)` | `PageOverlayState.error(...)` |
| **Empty** | `TracklistState.empty()` | `PageEmptyState(...)` |
| **Validation** | `ShippingFormState(isValid: false)` | `LoginFormState(canSubmit: false)` |
| **Selection** | `TracklistState(selectedId: '...')` | `SelectionModeState([...])` |

---

Would you like me to:
1. Add more scenarios (e.g., **notification banners**, **modals**, **side panels**)?
2. Include anti-patterns section showing common mistakes?
3. Add code examples showing how to handle scope transitions (e.g., local error escalating to global)?