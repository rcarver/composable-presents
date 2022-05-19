import ComposableArchitecture

extension Reducer {

    /// Manage presentation and dismissal lifecycle for the state.
    public func present<LocalState, LocalAction, LocalEnvironment>(
        with presenter: Presenter<LocalState, LocalAction, LocalEnvironment>,
        state toLocalState: WritableKeyPath<State, PresentationPhase<LocalState>>,
        action toLocalAction: CasePath<Action, LocalAction>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
    ) -> Self {
        .init { globalState, globalAction, globalEnvironment in
            let globalEffects = self.run(
                &globalState,
                globalAction,
                globalEnvironment
            )
            let presentationEffects = globalState[keyPath: toLocalState].run(
                presenter: presenter,
                environment: toLocalEnvironment(globalEnvironment),
                mapAction: toLocalAction.embed
            )
            return .merge(
                globalEffects,
                presentationEffects
            )
        }
    }

    /// Manage presentation and dismissal lifecycle for mutually exclusive case state.
    public func presentCase<LocalState, LocalAction, LocalEnvironment>(
        with presenter: Presenter<LocalState, LocalAction, LocalEnvironment>,
        state toLocalState: WritableKeyPath<State, ExclusivePresentationPhase<LocalState>>,
        action toLocalAction: CasePath<Action, LocalAction>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
    ) -> Self {
        .init { globalState, globalAction, globalEnvironment in
            let globalEffects = self.run(
                &globalState,
                globalAction,
                globalEnvironment
            )
            let presentationEffects = globalState[keyPath: toLocalState].run(
                presenter: presenter,
                environment: toLocalEnvironment(globalEnvironment),
                mapAction: toLocalAction.embed
            )
            return .merge(
                globalEffects,
                presentationEffects
            )
        }
    }

    /// Manage presentation and dismissal lifecycle for each state.
    public func presentEach<LocalState, LocalAction, LocalEnvironment, ID>(
        with presenter: Presenter<LocalState, LocalAction, LocalEnvironment>,
        state toLocalState: WritableKeyPath<State, IdentifiedArrayOfPresentationPhase<ID, LocalState>>,
        action toLocalAction: CasePath<Action, (ID, LocalAction)>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment
    ) -> Self {
        .init { globalState, globalAction, globalEnvironment in
            let globalEffects = self.run(
                &globalState,
                globalAction,
                globalEnvironment
            )
            let presentationEffects = globalState[keyPath: toLocalState].run(
                presenter: presenter,
                environment: toLocalEnvironment(globalEnvironment),
                mapAction: { toLocalAction.embed(($0, $1)) }
            )
            return .merge(
                globalEffects,
                .merge(presentationEffects)
            )
        }
    }
}

extension PresentationPhase {
    mutating func run<Action, GlobalAction, Environment>(
        presenter: Presenter<State, Action, Environment>,
        environment: Environment,
        mapAction: @escaping (Action) -> GlobalAction
    ) -> Effect<GlobalAction, Never> {
        switch self {
        case .dismissed:
            return .none
        case .presenting(let state):
            self = .presented(state)
            return presenter(state, .present, environment).map(mapAction)
        case .presented:
            return .none
        case .dismissing(let state):
            self = .cancelling(state)
            return presenter(state, .dismiss, environment).map(mapAction)
        case .cancelling:
            self = .dismissed
            return .none
        }
    }
}

extension ExclusivePresentationPhase {
    mutating func run<Action, GlobalAction, Environment>(
        presenter: Presenter<State, Action, Environment>,
        environment: Environment,
        mapAction: @escaping (Action) -> GlobalAction
    ) -> Effect<GlobalAction, Never> {
        switch self {
        case .single(var phase):
            let effects = phase.run(presenter: presenter, environment: environment, mapAction: mapAction)
            self = .single(phase)
            return effects
        case .transition(from: var from, to: let to):
            let fromEffects = from.run(presenter: presenter, environment: environment, mapAction: mapAction)
            switch from {
            case .dismissed:
                var phase = PresentationPhase.presenting(to)
                let toEffects = phase.run(presenter: presenter, environment: environment, mapAction: mapAction)
                self = .single(phase)
                return toEffects
            default:
                self = .transition(from: from, to: to)
                return fromEffects
            }
        }
    }
}

extension IdentifiedArrayOfPresentationPhase {
    mutating func run<Action, GlobalAction, Environment>(
        presenter: Presenter<State, Action, Environment>,
        environment: Environment,
        mapAction: @escaping (ID, Action) -> GlobalAction
    ) -> Effect<GlobalAction, Never> {
        let effects = self.array.ids.map { id in
            self.array[id: id]!.phase.run(
                presenter: presenter,
                environment: environment,
                mapAction: { mapAction(id, $0) }
            )
        }
        return .merge(effects)
    }
}
