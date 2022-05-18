/// A property wrapper type that captures the lifecycle of state that can be presented and dismissed.
///
/// This type captures each phase of that lifecycle, vs. nil and non-nil states.
//@dynamicMemberLookup
@propertyWrapper
public struct Presented<State> {
    var presentedState: PresentationPhase<State>

    public init() {
        self.presentedState = .dismissed
    }
    public var wrappedValue: State? {
        get { self.presentedState.state }
        set { self.presentedState.activate(with: newValue) }
    }
    public var projectedValue: PresentationPhase<State> {
        get { self.presentedState }
        set { self.presentedState = newValue }
    }
//    public subscript<Subject>(
//        dynamicMember keyPath: WritableKeyPath<State, Subject>
//    ) -> BindableState<Subject> {
//        get { .init(wrappedValue: self.wrappedValue.state?[keyPath: keyPath]) }
//        set { self.wrappedValue.state?[keyPath: keyPath] = newValue.wrappedValue }
//    }
}

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

extension Presented: Equatable where State: Equatable {}

extension PresentationPhase: Equatable where State: Equatable {}
