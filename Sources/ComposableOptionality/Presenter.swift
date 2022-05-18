import ComposableArchitecture

/// A type that describes presentation side effects.
///
/// This type is generally matched with a `Reducer`, and is executed by the parent domain
/// when child state moves between presented and dismissed states.
///
/// In contrast with a `Reducer`, a `Presenter` cannot modify state and always uses the
/// action type `PresentationAction`.
public struct Presenter<State, Action, Environment> {
    private let presenter: (State, PresentationAction, Environment) -> Effect<Action, Never>

    public init(presenter: @escaping (State, PresentationAction, Environment) -> Effect<Action, Never>) {
        self.presenter = presenter
    }
}

/// The actions for presentation.
public enum PresentationAction {
    /// Perform effects to setup state.
    case present
    /// Perform effects to tear down state.
    case dismiss
}

extension Presenter {
    /// Run the presenter, mutating the presenatation phase and executing presentation hooks.
    func run(_ phase: inout PresentationPhase<State>, _ environment: Environment) -> Effect<Action, Never> {
        switch phase {
        case .dismissed:
            return .none
        case .presenting(let state):
            phase = .presented(state)
            return self.presenter(state, .present, environment)
        case .presented:
            return .none
        case .dismissing(let state):
            phase = .cancelling(state)
            return self.presenter(state, .dismiss, environment)
        case .cancelling:
            phase = .dismissed
            return .none
        }
    }
}
