import ComposableArchitecture

/// A type that describes presentation side effects.
///
/// This type is generally matched with a `Reducer`, and is executed by the parent domain
/// when child state moves between presented and dismissed states.
///
/// In contrast with a `Reducer`, a `Presenter` cannot modify state and always uses the
/// action type `PresentationAction`.
public struct Presenter<State, Action, Environment> {
    private let presenter: (State, PresentationAction, Environment) -> PresenterEffect<Action>

    public init(presenter: @escaping (State, PresentationAction, Environment) -> PresenterEffect<Action>) {
        self.presenter = presenter
    }
}

/// The actions for presentation.
public enum PresentationAction {

    /// The state is moving to the `presented` phase,
    /// you should return effects to support it.
    ///
    /// You may perform any other side effects here as well.
    case present

    /// The state is moving the `dismissed` phase,
    /// you should cancel any running effects
    ///
    /// You may perform any other side effects here as well.
    case dismiss
}

/// The effect type returned by a Presenter.
public enum PresenterEffect<Action> {

    /// Dismissal waits for an action to be performed.
    ///
    /// Dismissal will move to the `dismissing` phase while
    /// performing the action, then move to the `dismissed` phase.
    case action(Effect<Action, Never>)

    /// Dismissal happens immediately. The effects have no impact
    /// on downstream actions or state.
    ///
    /// Dismissal will skip the `dismissing` phase,
    /// moving to the `dismissed` phase immediately,
    case immediate(Effect<Action, Never>)
}

extension Presenter {
    /// Construct a presenter that transitions immediately with no side effects.
    public static func immediate<State, Action, Environment>(
        _ state: State.Type = State.self,
        _ action: Action.Type = Action.self,
        _ environment: Environment.Type = Environment.self
    ) -> Presenter<State, Action, Environment> {
        .init { _, _, _ in .immediate }
    }
}

extension PresenterEffect {
    /// Dismiss immediately, performing no effects in this presentation action.
    public static var immediate: Self { .immediate(.none) }

    /// Dismiss by performing an action.
    public static func action(_ value: Action) -> Self {
        .action(Effect(value: value))
    }
}

extension PresenterEffect {
    var effect: Effect<Action, Never> {
        switch self {
        case .action(let effect): return effect
        case .immediate(let effect): return effect
        }
    }
}

extension Presenter {
    func callAsFunction(
        _ state: State,
        _ action: PresentationAction,
        _ environment: Environment
    ) -> PresenterEffect<Action> {
        self.presenter(state, action, environment)
    }
}
