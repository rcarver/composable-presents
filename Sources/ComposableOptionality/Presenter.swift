import ComposableArchitecture

/// The actions for presentation.
public enum PresentationAction {
    /// Perform effects to setup state.
    case present
    /// Perform effects to tear down state.
    case dismiss
}

/// A type that describes presentation side effects.
///
/// This type is generally matched with a Reducer, and is executed by the parent domain
/// when child state moves between presented and dismissed states (generally modeled
/// as non-nil and nil values).
///
/// In contrast with a Reducer, a Presenter cannot modify state and always handles
/// `present` and `dismiss` actions. Its returned effects are always `fireAndForget`
/// and so do not come back into the system as new state.
public struct Presenter<State, Action, Environment> {
    var presenter: (State, PresentationAction, Environment) -> Effect<Action, Never>

    public init(presenter: @escaping (State, PresentationAction, Environment) -> Effect<Action, Never>) {
        self.presenter = presenter
    }
}
