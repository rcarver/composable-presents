import Foundation
import IdentifiedCollections

/// A property wrapper type that captures the lifecycle of state that can be presented and dismissed.
///
/// This type maintains each phase of that lifecycle, vs. nil and non-nil states.
@propertyWrapper
public struct Presented<State> {
    private var value: PresentationPhase<State>

    public init() {
        self.value = .dismissed
    }
    public var wrappedValue: State? {
        get { self.value.state }
        set { self.value.activate(with: newValue) }
    }
    public var projectedValue: PresentationPhase<State> {
        get { self.value }
        set { self.value = newValue }
    }
}

/// A property wrapper type that captures the lifecycle of an enum of mutually exclusive states.
///
/// This type maintains each phase of that lifecycle, vs. nil and non-nil states.
@propertyWrapper
public struct PresentedCase<State> where State: Identifiable {
    private var value: ExclusivePresentationPhase<State>

    public init(wrappedValue: State?) {
        self.value = .init(wrappedValue, initialPhase: PresentationPhase.shouldPresent)
    }
    public var wrappedValue: State? {
        get { value.currentState }
        set { value.activate(with: newValue) }
    }
    public var projectedValue: ExclusivePresentationPhase<State>  {
        get { self.value }
        set { self.value = newValue }
    }
}

/// A property wrapper type that captures the lifecycle of an array of states that can be presented and dismissed.
///
/// This type maintains each phase of that lifecycle, vs. nil and non-nil states.
@propertyWrapper
public struct PresentedEach<State> where State: Identifiable {
    private var value: IdentifiedArrayOfPresentationPhaseOf<State>

    public init(wrappedValue: IdentifiedArrayOf<State>) {
        self.value = .init(identifiedStates: wrappedValue, initialPhase: PresentationPhase.shouldPresent)
    }
    public var wrappedValue: IdentifiedArrayOf<State> {
        get { value.identifiedStates }
        set { value.activate(with: newValue) }
    }
    public var projectedValue: IdentifiedArrayOfPresentationPhaseOf<State>  {
        get { self.value }
        set { self.value.merge(newValue) }
    }
}

extension Presented: Equatable where State: Equatable {}

extension PresentedCase: Equatable where State: Equatable {}

extension PresentedEach: Equatable where State: Equatable {}
