# Internal State Structure: Composing Data & Interaction 🧩

While Kondo mandates **Semantic Sectioning** (the outer structure), the *internal structure* of those State Objects is flexible.

Crucially, a UI Section is often a cocktail of three ingredients:

1. **Domain Data:** Coming from the Interactor (e.g., `Album`, `User`).
2. **User Input:** Coming from the User (e.g., `searchQuery`, `password`).
3. **Transient Status:** Coming from some UI Logic (e.g., `isExpanded`, `isFocused`, `isLoading`).

Your State Objects must be the container for **all three**.

---

#### Key Principles

**State Object Cohesion:**
Since the Interactor is stateless and the Hako is stateful, State Objects must be **cohesive** containers that hold everything needed for their UI section. A state object is primarily used for a piece of UI, but it can also contain data needed by the Interactor to produce logic.

**Transient UI Fields:**
Transient UI state (like `isExpanded`, `isFocused`, `isLoading`) can be added to **any** of the state structure patterns below. The choice of pattern depends on your data source and use case, not on whether you need transient fields.

**Types of State Objects:**
- **Smart Wrapper:** Wraps a domain entity (optionally adding transient UI fields)
- **Pure State:** Defines explicit fields for every input and flag
- **Pure Mapping:** Defines a final shape from multiple sources

Choose the pattern that balances type safety with developer velocity, keeping in mind that **heavy business logic belongs in the Interactor**, while **UI formatting (Colors, Icons) belongs in the View.**

---

#### 1. The Smart Wrapper (Mixed State) 🍬

**Best For:** Interactive Content displaying domain data (e.g., A Product Card, A Music Player, An Album Detail).

The State Object holds the **Raw Domain Entity** (for logic/data) *plus* optional **Transient Fields** (for interaction).

* **Structure:** `Raw Object` + `Optional UI Fields`.
* **When to use:**
    * The section displays data from a domain entity (`Album`, `User`, `Track`).
    * The Hako needs the raw object for business logic (e.g., passing IDs to Interactor methods).
    * The UI structure mostly mirrors the data structure.
    * (Optionally) The section has interactive elements requiring local state (`isExpanded`, `isLoading`).

* **Pros:** Low boilerplate; easy to maintain; combines data access with UI state.
* **Cons:** Couples UI State to Domain Entities (acceptable in Feature components).

---

#### 2. Pure State (Inputs & Forms) 📝

**Best For:** User Input (e.g., Search Bar, Login Form, Filters).

There is no "Domain Object" yet. The Source of Truth *is* the State Object itself. The data originates from user interaction.

* **Structure:** Explicit fields for every input and flag.
* **When to use:**
    * The section captures user input before sending it to an Interactor.
    * There's no backing domain entity (the form *creates* the entity).
    * You need validation state, focus state, or input-specific flags.

* **Pros:** Clear "what you see is what you get"; no coupling to domain.
* **Cons:** More boilerplate for complex forms.

---

#### 3. Pure Mapping (Read-Only Projection) 🧊

**Best For:** Complex Aggregation or Derived Views (e.g., Dashboard Header, Summary Statistics).

The State Object is a rigid, read-only snapshot containing *only* specific fields needed for display.

* **Structure:** Final primitive fields (`String`, `int`, `bool`) only.
* **When to use:**
    * **Lightweight State:** The section only needs a few specific fields (e.g., `count`, `statusLabel`), so wrapping a heavy object is overkill.
    * **Structure Mismatch:** The UI structure is very different from the raw data (e.g., flattening nested objects or combining multiple sources).
    * **No Logic Requirement:** The Hako doesn't need the raw object for this specific section (or it's held by a different state object).
    * **Multiple Sources:** The data comes from multiple domain entities (`User` + `Config` + `Status`).

* **Pros:** Total decoupling; minimal memory footprint; explicit contract.
* **Cons:** Higher boilerplate; rigid to refactor; must update mapping when domain changes.

---

#### The Decision Matrix 🧭

| Scenario | Ingredients | Recommended Pattern |
| --- | --- | --- |
| **Interactive Feature**<br>(Product Card, Player, Album Detail) | Domain Data +<br>Optional UI Flags | **Smart Wrapper**<br>*(Wrap the entity, optionally add `isExpanded`/`isLoading` fields)* |
| **User Input**<br>(Search, Login, Filters) | User Input +<br>Validation Flags | **Pure State**<br>*(Define explicit fields: `query`, `email`, `isValid`)* |
| **Static / Read-Only**<br>(Dashboard Header, Summary Stats) | Multiple Data Sources<br>or Derived Data | **Pure Mapping**<br>*(Map fields in a factory constructor)* |

---

#### Coherence with the Interactor

As stated in the Interactor documentation, **Feature State (Transient)** lives in the Hako and dies when the screen closes. This includes:
- User input currently being edited
- Transient UI flags (`isExpanded`, `isFocused`, `isLoading`)
- The specific view-ready data prepared by the Interactor for display

In contrast, **App State (Persistent)** lives in the data layer and outlives any specific screen (e.g., authentication data, saved albums list).

Furthermore, the Interactor serves the Hako by transforming App State from the data layer into "ready to consume" domain objects, but it never holds state itself—it's purely a transformation layer.
