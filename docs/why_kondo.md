# Why Kondo? 💡

Flutter gives you complete freedom in how you organize your code. That freedom is powerful—but without discipline, it leads to tangled logic, untestable features, and codebases that become harder to maintain as they grow.

Kondo provides that discipline:

* **Feature-oriented structure.** Code is organized by what the user can do, not by technical aspects. Every feature follows the same predictable pattern, making navigation immediate.
* **Strict separation of concerns.** Each component has exactly one role. Business logic never touches the UI. Side effects never mix with state. There is no ambiguity about where code belongs.
* **Automatic stream lifecycle management.** Stream subscriptions are bound to the feature's lifecycle and cleaned up when the user navigates away. No manual cancellation, no orphaned listeners.
* **Context-safe side effects.** Kondo provides built-in protection against the common "deactivated widget" crash, ensuring side effects only execute when the UI is still alive.
* **Testable at every boundary.** Because Kondo enforces clear interfaces between components, each piece can be tested in isolation with standard mocking—no widget tree required for logic tests.
* **Convention over configuration.** Predictable folder structures, naming schemes, and state patterns mean that anyone (or any tool) can understand and extend the codebase without prior context.
