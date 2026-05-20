# Bulletproof Orchestration Testing 🎯

Testing is notoriously the hardest part of state management. Developers often blur the lines between integrating backend APIs, rendering pixel-perfect UI, and tracking state.

Kondo solves this elegantly via the `kondo_test` package, which forces you to test **routing orchestration chronology** instead of messy Flutter widget cycles or live endpoints.

## 1. Setup

Kondo relies heavily on the `mocktail` library to cleanly sever the boundaries of the Triad. Add `kondo_test` along with `mocktail` to your `pubspec.yaml` under `dev_dependencies`:

```yaml
dev_dependencies:
  kondo_test: ^[LATEST_VERSION]
  mocktail: ^1.0.0
```

*Note: Under the hood, `kondo_test` leverages `expectHakoEmits` provided natively by the core `hako` package, combining robust Stream telemetry with opinionated `mocktail` assertions.*

## 2. Anatomy of a Kondo Test

Because the Hako is strictly an orchestrator, you never test actual HTTP requests or `BuildContext` navigation. You mock the boundaries:

1. **Mock the Interactor**: Prove that domain requests are routed correctly to the brain using `mocktail`.
2. **Mock the Reactor**: Prove that side-effects like routes or UI dialogs execute seamlessly.
3. **Assert the Event Stream**: Use the powerful `expectKondoHako` test harness to mathematically prove the chronology of State mutations (`SetEvent`) alongside telemetry markers (`ReactorEvent` / `InteractorEvent`).

## 3. The `expectKondoHako` Test Harness

Below is a complete, realistic example of testing a complex asynchronous Login flow. Notice how we validate everything chronologically, without spinning up a single Flutter Widget tree!

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kondo_test/kondo_test.dart';
import 'package:mocktail/mocktail.dart';

// 1. Declare strict boundary Mocks
class MockAuthInteractor extends Mock implements AuthInteractor {}
class MockAuthReactor extends Mock implements AuthReactor {}

void main() {
  late WelcomeHako hako;
  late MockAuthInteractor mockInteractor;
  late MockAuthReactor mockReactor;

  setUp(() {
    mockInteractor = MockAuthInteractor();
    mockReactor = MockAuthReactor();
    
    // Inject the pure mocked dependencies into the Orchestrator
    hako = WelcomeHako(
      interactor: mockInteractor, 
      reactor: mockReactor
    );
  });
  
  test('successfully completes user login flow', () async {
      // 2. Arrange our mock boundaries
      when(() => mockInteractor.checkConnection()).thenAnswer((_) async => true);
      when(() => mockReactor.goToDashboard()).thenAnswer((_) async => true);
      
      // 3. Execute and Trace the Timeline!
      await expectKondoHako(
        hako: hako,
        action: (h) => h.onLoginTap(),
        
        // A) Validate the precise chronological telemetry of the stream
        eventMatchers: [
          const InteractorEvent.withLabel('Check connection'),
          const SetEvent(
            WelcomeState(isLoading: false),
            WelcomeState(isLoading: true),
          ),
          const InteractorEvent.withLabel('Log success event'),
          const ReactorEvent.withLabel('Go to dashboard'),
        ],
        
        // B) Validate the exact methods executed on the boundary classes
        recordedMockInvocations: [
          () => mockInteractor.checkConnection(),
          () => mockInteractor.logEvent('auth_success'),
          () => mockReactor.goToDashboard(),
        ],
        
        // C) Guarantee that failure routes were explicitly avoided
        neverRecordedInvocations: [
          () => mockReactor.goToError(),
        ],
      );
  });
}
```

## 4. Why `expectKondoHako` is Powerful

The beauty of `expectKondoHako` lies in its three-pronged validation checks:

*   **`eventMatchers:`** Because Hako natively tracks all mutations and Triad interactions, this acts as a true time-lapse recording. You aren't just asserting that "a mock method was called"—you are mathematically proving that `MockInteractor.checkConnection()` finished *before* the `WelcomeState(isLoading: true)` boolean flipped! This eliminates flaky asynchronous testing.
*   **`recordedMockInvocations:`** Ensures that the inputs and outputs passed across your Triad boundaries were precisely correct.
*   **`neverRecordedInvocations:`** The ultimate safety net. It explicitly verifies that during a "Success Path" test, fatal side-effects (like popping up an Error Dialog inside the Reactor) absolutely did not trigger.

## 5. Mocking Hako for Widget Testing (UI Testing)

While `expectKondoHako` is used for testing Orchestration/Logic independently of Flutter, you will inevitably need to test your Flutter Widget tree mapping (e.g. "Does the Spinner render when loading?").

Because Kondo tightly maps State to views via `KondoProvider`, `kondo_test` exports an insanely powerful `MockHako` wrapper. This allows you to aggressively stub state transitions for your `testWidgets` routines, so you never have to boot up a real database or Interactor class!

```dart
// 1. Declare a MockHako
class MyMockHako extends MockHako implements WelcomeHako {}

testWidgets('Welcome Widget updates on state change', (tester) async {
  final mockHako = MyMockHako();
  
  // 2. Seed the precise initial state into the mock
  mockHako.seed<WelcomeState>(const WelcomeState(isLoading: false));

  // 3. Define transitions! When a UI interaction happens, cleanly shift the state!
  when(() => mockHako.onLoginTap())
      .thenHakoSet(mockHako, const WelcomeState(isLoading: true));

  await tester.pumpWidget(
    KondoProvider<WelcomeHako>.value(
      value: mockHako,
      builder: (context) => const WelcomePage(),
    ),
  );

  // Assert default state
  expect(find.byType(CircularProgressIndicator), findsNothing);

  // 4. Trigger UI interaction
  await tester.tap(find.text('Login'));
  await tester.pump();

  // 5. Assert the UI reacted cleanly to the `thenHakoSet` mocked mutation!
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```
This guarantees your Feature views are 100% resilient and visually accurate without dragging raw implementations or HTTP requests into your UI tests!
