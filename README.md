# ComposablePresents

Presentation and dismissal for [ComposableArchitecture](https://github.com/pointfreeco/swift-composable-architecture/).

⚠️ Status: experimental, incomplete!

## Purpose

This package attempts to provide a simple to use and complete solution to 
managing presentation and dismissal of state and long running effects.

For our purposes, *presentation* is defined as creating some non-nil state
for the purpose for working in a new domain, then destroying that state
(setting to nil) to end work in tha domain. In TCA, creating this new domain 
is often paired with kicking off long-running effects which must be carefully 
cancelled before the state becomes nil. 

This dance of cancelling effects, then setting state to nil is error-prone
and requires additional lifecycle actions to get right.

Presentation is often coupled with *navigation* but they're two separate issues.
Navigation is a related change of the UI state, often modal, but not always. 
`ComposablePresents` provides a set of SwiftUI navigation helpers modeled 
after [SwiftUINavigation](https://github.com/pointfreeco/swiftui-navigation).

## Basics

To make this easier, `ComposablePresents` provides a set of property wrappers
that model the full lifecycle of presentation and dismissal. Paired with
a higher-order reducer that performs presentation state transitions along
with managing effects.

The property wrapper comes in flavors for `Optional` state, `Identified` state, 
`enum` state, and `IdentifiedArray`s.

```swift
struct WorldState: Equatable {
  @PresentsAny var person: PersonState?
}
```

The `presents` higher-order reducer takes a `Presenter` which performs
actions when the state is presented and dismissed. A `Presenter` can be
derived from a `Reducer` in many cases.

```swift
Reducer { state, action, environment in
  ...
}
  .presents(
    state: \.$person,
    action: /Action.person,
    environment: \.person,
    presenter: .longRunning(PersonReducer)
  )
```

With these two pieces in place, you're free to use TCA as normal and set
`state.person` to an honest value or nil value and any long-running effects 
performed by the `PersonReducer` will be started and cancelled automatically.

## Types of Presentation

Variations of the property wrapper support patterns for modeling optional state.

```swift
/// Perform presentation when the value changes from nil to non-nil.
@PresentsAny var value: SomeValue?
```

```swift
/// Perform presentation when the value moves from nil to non-nil, 
/// or if the ID of the value changes. 
@PresentsOne var value: SomeIdentifiableValue?
```

```swift
/// Perform presentation any element is added or removed from the array.
@PresentsEach var value: IdentifiedArrayOf<SomeValue> = []
```

Note that `@PresentsOne` supports both enum and struct types that implement `Identifiable`.
An enum can implement `Identifiable` fairly easily, for example:

```swift
extension MyEnum: Identifiable {
  var id: AnyHashable {
    case .firstCase(let value): return value.id
    case .secondCase: return "second"
  }
}

## Example

Following is an example using all features of the library.

**The child/presented domain** —

```swift
struct PersonState: Equatable {
  var name: String
  var age: Int
}

// 🎁 Action implements `LongRunningAction`, allowing it to be used
// directly as a presenter.
enum PersonAction: Equatable, LongRunningAction {
  case begin
  case cancel
  case setAge(Int)
}

struct PersonEnvironment {
  var years: () -> Effect<Int, Never>
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

enum PersonEffect {}

let personReducer = Reducer<PersonState, PersonAction, PersonEnvironment>.combine(
  Reducer { state, action, environment in
    switch action {
    case .setAge(let age):
      state.age = age
      return .none
  
    // 🎁 For `LongRunningAction`, start any effects.
    case .begin:
      return environment.years()
        .receive(on: environment.mainQueue)
        .eraseToEffect(PersonAction.setAge)
        .cancellable(id: PersonEffect.self)
        
    // 🎁 For `LongRunningAction`, cancel any effects.
    case .cancel:
      return .cancel(id: PersonEffect.self)
    }
  }
)
```

**The parent/presenter domain** —

```swift
struct WorldState: Equatable {
  // 🎁 Property wrapper for presenting any state
  @PresentsAny var person: PersonState?
}

enum WorldAction: Equatable {
  case born
  case died
  case person(PersonAction)
}

struct WorldEnvironment {
  var years: () -> Effect<Int, Never>
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var person: PersonEnvironment { .init(years: years, mainQueue: mainQueue) }
}

let reducer = Reducer<WorldState, WorldAction, WorldEnvironment>.combine(
  // 👀 Optional pullback, independent of presentation.
  personReducer.optional().pullback(
    state: \.person,
    action: /WorldAction.person,
    environment: \.person
  ),
  Reducer { state, action, environment in
    switch action {
    case .born:
      // 🎁 Set state to an honest value, triggering presentation 
      state.person = .init(name: "John", age: 0)
      return .none
    case .died:
      // 🎁 Set state to an nil value, triggering dismissal
      state.person = nil
      return .none
    case .person:
      return .none
    }
  }
    // 🎁 Attach `presents` reducer to property wrapper.
    .presents(
      state: \.$person,
      action: /WorldAction.person,
      environment: \.person,
      // 🎁 Convert `personReducer` to `Presenter` because it 
      // implements `LongRunningAction`
      presenter: .longRunning(personReducer)
    )
)
```

### Custom Presenter

If you can't or don't want to implement `LongRunningAction`, creating
a custom or ad-hoc `Presenter` is simple.

```swift
Reducer { state, action, environment in
  ...
}
  .presents(
    state: \.$person,
    action: /Action.person,
    environment: \.person,
    presenter: .init { state, action, environment in 
      switch action {
      case .present:
        return .action(Effect(value: .your_custom_effect)) // or `.action(.your_custom_effect)`
      case .dismiss:
        return .action(Effect(value: .your_custom_effect)) // or `.immediate` if nothing to do
      }
    }
  )
```

The presenter is given the presented state (or the last honest state
when dismissed), a `PresentationAction` (`present`, `dismiss`), and the 
environment. Custom presenters can perform any additional side-effects 
beyond what the reducer defines.

**Note:** be sure that any effects sent from the `dismiss` action do
not feed back into the system (use `.fireAndforget` and `.cancel`) 
because the state will be nil. 

## Navigation

TODO: See the sample app.

## Testing

TODO: See the test suite.

## Background

In creating this library I wanted to bring consistency to effect creation and cancellation. I've found that they tend to be handled differently based on the use and context of a domain. 

* In SwiftUI, it's most convenient to start effects in `onAppear`. This works fine, but takes control of this effect out of the parent domain.
* In SwiftuI, it's most convenient to cancel effects in `onDisappear`. This only works if the associated state stays non-nil and is simply visible or hidden based on some other state.

However, it's common to use non-nil/nil state to navigate. In such cases, a view designed to cancel itself in `onDisappear` will fail because the state is by definition nil when it disappers. See [SwiftUINavigation](https://github.com/pointfreeco/swiftui-navigation) and [Point Free's Navigation](https://www.pointfree.co/collections/swiftui/navigation) for reference on modeling navigation this way.

To simplify all of this, most libraries that provide presentation/navigation tools ([ComposablePresentation](https://github.com/darrarski/swift-composable-presentation), [TCACoordinators](https://github.com/johnpatrickmorgan/TCACoordinators)) automatically cancel all effects of the presented domain when its state goes nil. This is convenient, but:

* In tests, you must *also* implement cancellation in the reducer such that no effects are running when the test ends.

All of this leads to feeling like there's no single way to set this all up, or at least not a way that's simple to use.

## Goals

I believe that to improve the ergonomics of state presentation, effects management and navigation:

* How effects are managed (started, cancelled) should be defined by the domain itself—in its reducer. There should ideally be a consistent action to perform these steps.
* The *triggering* of these steps, however, should be performed by the parent domain. This is what knows when the associated state is present or not.
* The parent domain should be able to perform *other* effects at this time
* You should only have to set state to non-nil or nil to perform presentation state transitions, including effects.
* Automatic cancellation should be avoided. It lets you forget about effect cancellation, when it's really a key part of domain design.
* All uses of a domain should follow the same pattern; when it's standalone, nested, presented, and in tests.

## Other libraries

This library builds upon incredible work such as:

* [ComposableArchitecture](https://github.com/pointfreeco/swift-composable-architecture/)
* [ComposablePresentation](https://github.com/darrarski/swift-composable-presentation)
* [SwiftUINavigation](https://github.com/pointfreeco/swiftui-navigation)
* [TCACoordinators](https://github.com/johnpatrickmorgan/TCACoordinators)

## License

Copyright © 2022 Ryan Carver

This library is released under the MIT license. See [LICENSE](LICENSE) for details.
