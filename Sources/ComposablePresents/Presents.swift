import Foundation
import IdentifiedCollections

/// A property wrapper type that captures the presentation lifecycle of state
/// that is nil or non-nil.
///
/// This type should only be used when the non-nil value always has the same identity.
/// If the identity of the non-nil value can change, use `PresentsOne`.
@propertyWrapper
public struct PresentsAny<State> {
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

/// A property wrapper type that captures the presentation lifecycle of mutually
/// exclusive states differentiated by their `ID`.
@propertyWrapper
public struct PresentsOne<State> where State: Identifiable {
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

/// A property wrapper type that captures the lifecycle of an any number of states that
/// can each be presented and dismissed individually.
@propertyWrapper
public struct PresentsEach<State> where State: Identifiable {
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

extension PresentsAny: Equatable where State: Equatable {}

extension PresentsOne: Equatable where State: Equatable {}

extension PresentsEach: Equatable where State: Equatable {}
