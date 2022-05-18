import ComposableArchitecture

@propertyWrapper
public struct Presented<State> {
    var presentedState: PresentedState<State>

    public init() {
        self.presentedState = .dismissed
    }
    public var wrappedValue: State? {
        get { self.presentedState.state }
        set { self.presentedState.state = newValue }
    }
    public var projectedValue: PresentedState<State> {
        get { self.presentedState }
        set { self.presentedState = newValue }
    }
}

public enum PresentedState<State> {
    case dismissed
    case presenting(State)
    case presented(State)
    case dismissing(State)
    case cancelling(State)
}

extension PresentedState {
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
            case (.dismissed, .some(let value)): self = .presenting(value)
            case (.presenting, .some(let value)): self = .presenting(value)
            case (.presented, .some(let value)): self = .presented(value)
            case (.dismissing, .some(let value)): self = .dismissing(value)
            case (.cancelling, .some(let value)): self = .cancelling(value)
            case (.dismissed, .none): self = .dismissed
            case (.presenting(let state), .none): self = .dismissing(state)
            case (.presented(let state), .none): self = .dismissing(state)
            case (.dismissing, .none): self = .dismissed
            case (.cancelling(let state), .none): self = .cancelling(state)
            }
        }
    }
}

extension Presented: Equatable where State: Equatable {}

extension PresentedState: Equatable where State: Equatable {}

enum PresentedAction<Action> {
    case noop
    case pass(Action)
}

public protocol LongRunningAction {
    static var begin: Self { get }
    static var cancel: Self { get }
}

extension Reducer {
    public func present<LocalState, LocalAction, LocalEnvironment>(
        reducer: Reducer<LocalState, LocalAction, LocalEnvironment>,
        state toLocalState: WritableKeyPath<State, PresentedState<LocalState>>,
        action toLocalAction: CasePath<Action, LocalAction>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
    ) -> Self where LocalAction: LongRunningAction {
        present(
            reducer: reducer,
            presenter: Presenter { state, action, environment in
                switch action {
                case .present: return Effect(value: .begin)
                case .dismiss: return Effect(value: .cancel)
                }
            },
            state: toLocalState,
            action: toLocalAction,
            environment: toLocalEnvironment
        )
    }
    public func present<LocalState, LocalAction, LocalEnvironment>(
        reducer: Reducer<LocalState, LocalAction, LocalEnvironment>,
        state toLocalState: WritableKeyPath<State, PresentedState<LocalState>>,
        action toLocalAction: CasePath<Action, LocalAction>,
        onPresent: @escaping (LocalState, LocalEnvironment) -> Effect<LocalAction, Never>,
        onDismiss: @escaping (LocalState, LocalEnvironment) -> Effect<LocalAction, Never>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
    ) -> Self {
        present(
            reducer: reducer,
            presenter: Presenter { state, action, environment in
                switch action {
                case .present: return onPresent(state, environment)
                case .dismiss: return onDismiss(state, environment)
                }
            },
            state: toLocalState,
            action: toLocalAction,
            environment: toLocalEnvironment
        )
    }
    public func present<LocalState, LocalAction, LocalEnvironment>(
        reducer: Reducer<LocalState, LocalAction, LocalEnvironment>,
        presenter: Presenter<LocalState, LocalAction, LocalEnvironment>,
        state toLocalState: WritableKeyPath<State, PresentedState<LocalState>>,
        action toLocalAction: CasePath<Action, LocalAction>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
    ) -> Self {
        return Reducer { globalState, globalAction, globalEnvironment in
            let globalEffects = self.run(
                &globalState,
                globalAction,
                globalEnvironment
            )
            let presentationEffects = presenter.present(
                &globalState[keyPath: toLocalState],
                toLocalEnvironment(globalEnvironment)
            )
            var localEffects = Effect<LocalAction, Never>.none
            if let action = toLocalAction.extract(from: globalAction) {
                if var state = globalState[keyPath: toLocalState].state {
                    localEffects = reducer.run(
                        &state,
                        action,
                        toLocalEnvironment(globalEnvironment)
                    )
                    globalState[keyPath: toLocalState].state = state
                } else {
                    print("WARNING: action `\(action)` was received while state is not presented")
                }
            }
            let dismisssalEffects = presenter.dismiss(
                &globalState[keyPath: toLocalState],
                toLocalEnvironment(globalEnvironment)
            )
            return .merge(
                globalEffects,
                presentationEffects.map(toLocalAction.embed),
                localEffects.map(toLocalAction.embed),
                dismisssalEffects.map(toLocalAction.embed)
            )
        }
    }
}

extension Presenter {
    func present(_ state: inout PresentedState<State>, _ environment: Environment) -> Effect<Action, Never> {
        switch state {
        case .dismissed:
            return .none
        case .presenting(let wrappedState):
            state = .presented(wrappedState)
            return self.presenter(wrappedState, .present, environment)
        case .presented:
            return .none
        case .dismissing:
            return .none
        case .cancelling:
            return .none
        }
    }
    func dismiss(_ state: inout PresentedState<State>, _ environment: Environment) -> Effect<Action, Never> {
        switch state {
        case .dismissed:
            return .none
        case .presenting:
            return .none
        case .presented:
            return .none
        case .dismissing(let wrappedState):
            state = .cancelling(wrappedState)
            return self.presenter(wrappedState, .dismiss, environment)
        case .cancelling:
            state = .dismissed
            return .none
        }
    }
}
