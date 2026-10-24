## 0.0.4

* **KondoProvider**: Added full support for `onReady` callbacks when used inside `MultiProvider`.
* **KondoHako**: Added optional `name` parameter to `connectStream` and `mapStream` for targeting named state containers.
* **Dependencies**: Upgraded `hako` dependency constraint to `^0.1.1`.
* **Testing**: Modernized test suite using `hako_test` and expanded test coverage to 100% (covering lazy loading, assert guards, and multi-stream cancellation).
* **Documentation**: Replaced PNG architectural diagrams with sanitized SVGs and updated state ownership guides.

## 0.0.3

* Added `mapStream<T, S>` method to `KondoHako` for mapping stream events directly to state mutations with automated subscription management.
* Removed unused `collection` dependency.
* Added comprehensive unit tests for `mapStream` lifecycle and transformations.
* Overhauled architecture and triad documentation (`triad_hako.md`, `triad_interactor.md`, `triad_reactor.md`, `architecture_flow.md`, `state_ownership.md`) and updated diagrams.

## 0.0.2

* Updated documentation links in README to absolute GitHub URLs.
* Refined inline `Interactor` construction guidelines.

## 0.0.1

* Initial release.
