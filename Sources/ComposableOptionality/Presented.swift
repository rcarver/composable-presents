import ComposableArchitecture

@propertyWrapper
public struct Presented<State> {

    public init() {
        self.presentedState = .dismissed
    }

    public init(state: State) {
        self.presentedState = .presented(state)
    }

    var presentedState: PresentedState<State>

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
}

extension PresentedState {
    var state: State? {
        get {
            switch self {
            case .dismissed: return nil
            case .presenting(let state): return state
            case .presented(let state): return state
            case .dismissing(let state): return state
            }
        }
        set {
            switch (self, newValue) {
            case (.presenting, .some(let value)): self = .presenting(value)
            case (.presented, .some(let value)): self = .presented(value)
            case (.dismissing, .some(let value)): self = .dismissing(value)
            case (.dismissed, .some(let value)): self = .presenting(value)
            case (_, .none): self = .dismissed
            }
        }
    }
    mutating func next(with state: State?) {
        switch (self, state) {
        case (.dismissed, .some(let value)):
            self = .presenting(value)
        case (.dismissed, .none):
            self = .dismissed

        case (.presenting, .some(let value)):
            self = .presented(value)
        case (.presenting(let value), .none):
            self = .dismissing(value)

        case (.presented, .some(let value)):
            self = .presented(value)
        case (.presented(let value), .none):
            self = .dismissing(value)

        case (.dismissing, .some(let value)):
            self = .presenting(value)
        case (.dismissing, .none):
            self = .dismissed
        }
    }
}

extension Presented: Equatable where State: Equatable {}

extension PresentedState: Equatable where State: Equatable {}

//public enum PresenterAction<Action> {
//    case present
//    case onDismiss
//    case onDismissComplete
//    case wrapped(Action)
//}

extension Reducer {
    public func present<LocalState, LocalAction, LocalEnvironment>(
        reducer: Reducer<LocalState, LocalAction, LocalEnvironment>,
        state toLocalState: WritableKeyPath<State, PresentedState<LocalState>>,
        action toLocalAction: CasePath<Action, LocalAction>,
        onPresent: @escaping (LocalState, LocalEnvironment) -> Effect<Never, Never>,
        onDismiss: @escaping (LocalState, LocalEnvironment) -> Effect<Never, Never>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
    ) -> Self {
        let presentedStateReducer = makePresentedStateReducer(
            reducer: reducer,
            onPresent: onPresent,
            onDismiss: onDismiss
        )
        return Reducer { globalState, globalAction, globalEnvironment in
            let globalEffects = self.run(
                &globalState,
                globalAction,
                globalEnvironment
            )
            let presentationEffects = presentedStateReducer.run(
                &globalState[keyPath: toLocalState],
                Void(),
                toLocalEnvironment(globalEnvironment)
            )
            var localEffects = Effect<LocalAction, Never>.none
            if let action = toLocalAction.extract(from: globalAction), var state = globalState[keyPath: toLocalState].state {
                localEffects = reducer.run(
                    &state,
                    action,
                    toLocalEnvironment(globalEnvironment)
                )
                globalState[keyPath: toLocalState].state = state
            }
            return .merge(
                globalEffects,
                presentationEffects.fireAndForget(),
                localEffects.map(toLocalAction.embed)
            )
        }
    }
}

func makePresentedStateReducer<State, Action, Environment>(
    reducer: Reducer<State, Action, Environment>,
    state: State.Type = State.self,
    environment: Environment.Type = Environment.self,
    onPresent: @escaping (State, Environment) -> Effect<Never, Never>,
    onDismiss: @escaping (State, Environment) -> Effect<Never, Never>
) -> Reducer<PresentedState<State>, Void, Environment> {
    .init { state, _, environment in
        switch state {
        case .dismissed:
            return .none
        case .presenting(let wrappedState):
            state = .presented(wrappedState)
            return onPresent(wrappedState, environment).fireAndForget()
        case .presented:
            return .none
        case .dismissing(let wrappedState):
            state = .dismissed
            return onDismiss(wrappedState, environment).fireAndForget()
        }
    }
}
