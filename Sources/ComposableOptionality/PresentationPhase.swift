import IdentifiedCollections

/// Each phase of the presentation lifecycle.
public enum PresentationPhase<State> {

    /// The state is dismissed, there is no state.
    case dismissed

    /// The state has begun presenting, it is not yet fully presented.
    case presenting(State)

    /// The state is fully presented.
    case presented(State)

    /// The state is being dismissed.
    case dismissing(State)

    /// The state is performing cleanup work.
    case cancelling(State)
}

extension PresentationPhase {
    /// Get or set the underlying state.
    ///
    /// Getting the value returns nil if the phase is `dismissed`.
    /// Setting the value to non-nil updates the state in the current phase.
    /// Setting the value to `nil` has no effect.
    public var state: State? {
        get {
            switch self {
            case .dismissed: return nil
            case .presenting(let state): return state
            case .presented(let state): return state
            case .dismissing(let state): return state
            case .cancelling(let state): return state
            }
        }
        set {
            switch (self, newValue) {
            case (.presenting, .some(let value)): self = .presenting(value)
            case (.presented, .some(let value)): self = .presented(value)
            case (.dismissing, .some(let value)): self = .dismissing(value)
            case (.cancelling, .some(let value)): self = .cancelling(value)
            case (.dismissed, _): self = .dismissed
            case (_, _): break
            }
        }
    }
}

extension PresentationPhase {
    /// Activate or deactivate the presentation.
    ///
    /// * A non-nil state will move the pahse from `dismissed` to `presenting`.
    /// * A nil state will move to to the next logical dismissal phase.
    /// * All other permutations will update the stored state with no change of phase.
    mutating func activate(with newValue: State?) {
        switch (self, newValue) {

        case (.dismissed, .some(let value)): self = .presenting(value)
        case (.dismissed, .none): self = .dismissed

        case (.presenting, .some(let value)): self = .presenting(value)
        case (.presented, .some(let value)): self = .presented(value)
        case (.dismissing, .some(let value)): self = .dismissing(value)
        case (.cancelling, .some(let value)): self = .cancelling(value)

        case (.presenting(let state), .none): self = .dismissing(state)
        case (.presented(let state), .none): self = .dismissing(state)
        case (.dismissing(let state), .none): self = .cancelling(state)
        case (.cancelling(let state), .none): self = .cancelling(state)
        }
    }
}

/// Maintains an ID for the presentation phase, allowing the identification of `dismissed` phase.
public struct IdentifiedPresentationPhase<ID: Hashable, State>: Identifiable {
    public let id: ID
    public var phase: PresentationPhase<State>
}

/// Wraps IdentifiedArray for conversion into and out of presentation phases.
public struct IdentifiedArrayOfPresentationPhase<ID: Hashable, State> {
    var array: IdentifiedArray<ID, IdentifiedPresentationPhase<ID, State>>
}

extension IdentifiedArrayOfPresentationPhase {
    /// Initialize from states, setting the initial presentation phase.
    init(identifiedStates states: IdentifiedArray<ID, State>, initialPhase: (State) -> PresentationPhase<State>) {
        let values = states.ids.compactMap { id -> IdentifiedPresentationPhase<ID, State>? in
            guard let state = states[id: id] else { return nil }
            return IdentifiedPresentationPhase(id: id, phase: initialPhase(state))
        }
        self.array = .init(uncheckedUniqueElements: values)
    }
    /// Initialize from presentation phases.
    init(identifiedPhases phases: IdentifiedArray<ID, PresentationPhase<State>>) {
        let values = phases.ids.compactMap { id -> IdentifiedPresentationPhase<ID, State>? in
            guard let state = phases[id: id] else { return nil }
            return IdentifiedPresentationPhase(id: id, phase: state)
        }
        self.array = .init(uncheckedUniqueElements: values)
    }
    /// Activate each state by merging with current state.
    mutating func activate(with newValue: IdentifiedArray<ID, State>) {
        for (index, id) in newValue.ids.enumerated() {
            self.array.insert(.init(id: id, phase: .dismissed), at: index)
        }
        for id in Set(self.array.ids).union(newValue.ids) {
            self.array[id: id]?.phase.activate(with: newValue[id: id])
        }
        for id in self.array.ids {
            if case .dismissed = self.array[id: id]?.phase {
                self.array.remove(id: id)
            }
        }
    }
    /// Take the new value, and clean up any lingering `dismissed` values.
    mutating func merge(_ newValue: Self) {
        self = newValue
        for id in self.array.ids {
            if case .dismissed = self.array[id: id]?.phase {
                self.array.remove(id: id)
            }
        }
    }
}

extension IdentifiedArrayOfPresentationPhase where State: Identifiable, ID == State.ID {
    /// Initialize from an array of phases.
    init(phases: [PresentationPhase<State>]) {
        let values = phases.compactMap { phase -> IdentifiedPresentationPhaseOf<State>? in
            guard let id = phase.state?.id else { return nil }
            return IdentifiedPresentationPhase(id: id, phase: phase)
        }
        self.array = .init(uncheckedUniqueElements: values)
    }
    /// Unwrap just the states from their presentation.
    var identifiedStates: IdentifiedArrayOf<State> {
        let unwrappedStates = self.array.compactMap(\.phase.state)
        return .init(uncheckedUniqueElements: unwrappedStates)
    }
}

extension IdentifiedArrayOfPresentationPhase: ExpressibleByArrayLiteral where State: Identifiable, ID == State.ID {
    public init(arrayLiteral phases: PresentationPhase<State>...) {
        self.init(phases: phases)
    }
}

public typealias IdentifiedPresentationPhaseOf<State> = IdentifiedPresentationPhase<State.ID, State> where State: Identifiable

public typealias IdentifiedArrayOfPresentationPhaseOf<State> = IdentifiedArrayOfPresentationPhase<State.ID, State> where State: Identifiable

extension PresentationPhase: Equatable where State: Equatable {}

extension IdentifiedPresentationPhase: Equatable where State: Equatable {}

extension IdentifiedArrayOfPresentationPhase: Equatable where State: Equatable {}
