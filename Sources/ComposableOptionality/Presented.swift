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
}

extension PresentedState {
    public var state: State? {
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
            case (.dismissed, .some(let value)): self = .presenting(value)
            case (.presenting, .some(let value)): self = .presenting(value)
            case (.presented, .some(let value)): self = .presented(value)
            case (.dismissing, .some(let value)): self = .dismissing(value)
            case (.dismissed, .none): self = .dismissed
            case (.presenting(let state), .none): self = .dismissing(state)
            case (.presented(let state), .none): self = .dismissing(state)
            case (.dismissing, .none): self = .dismissed
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

extension Reducer {
    public func present<LocalState, LocalAction, LocalEnvironment>(
        reducer: Reducer<LocalState, LocalAction, LocalEnvironment>,
        state toLocalState: WritableKeyPath<State, PresentedState<LocalState>>,
        action toLocalAction: CasePath<Action, LocalAction>,
        onPresent: @escaping (LocalState, LocalEnvironment) -> Effect<LocalAction, Never>,
        onDismiss: @escaping (LocalState, LocalEnvironment) -> Effect<Never, Never>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
    ) -> Self {
        let presentedStateReducer = makePresentedStateReducer(
            reducer: reducer,
            onPresent: onPresent,
            onDismiss: onDismiss
        )
        return Reducer { globalState, globalAction, globalEnvironment in
            let globalEffects: Effect<Action, Never> = self.run(
                &globalState,
                globalAction,
                globalEnvironment
            )
            let presentationEffects: Effect<PresentedAction<LocalAction>, Never> = presentedStateReducer.run(
                &globalState[keyPath: toLocalState],
                .noop,
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
                presentationEffects
                    .compactMap((/PresentedAction<LocalAction>.pass).extract)
                    .map(toLocalAction.embed)
                    .eraseToEffect(),
                localEffects
                    .map(toLocalAction.embed)
            )
        }
    }
}

func makePresentedStateReducer<State, Action, Environment>(
    reducer: Reducer<State, Action, Environment>,
    state: State.Type = State.self,
    environment: Environment.Type = Environment.self,
    onPresent: @escaping (State, Environment) -> Effect<Action, Never>,
    onDismiss: @escaping (State, Environment) -> Effect<Never, Never>
) -> Reducer<PresentedState<State>, PresentedAction<Action>, Environment> {
    .init { state, _, environment in
        switch state {
        case .dismissed:
            return .none
        case .presenting(let wrappedState):
            state = .presented(wrappedState)
            return onPresent(wrappedState, environment).map(PresentedAction.pass)
        case .presented:
            return .none
        case .dismissing(let wrappedState):
            state = .dismissed
            return onDismiss(wrappedState, environment).fireAndForget()
        }
    }
}
