import ComposableArchitecture

extension Reducer {

    /// Manage presentation and dismissal lifecycle for optional state.
    public func presents<LocalState, LocalAction, LocalEnvironment>(
        state toLocalState: WritableKeyPath<State, PresentationPhase<LocalState>>,
        action toLocalAction: CasePath<Action, LocalAction>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment,
        presenter: Presenter<LocalState, LocalAction, LocalEnvironment>
    ) -> Self {
        self._presents(state: toLocalState, action: toLocalAction, environment: toLocalEnvironment, presenter: presenter)
    }

    /// Manage presentation and dismissal lifecycle for optional state.
    public func presents<LocalState, LocalAction, LocalEnvironment>(
        state toLocalState: WritableKeyPath<State, PresentationPhase<LocalState>>,
        action toLocalAction: CasePath<Action, LocalAction>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment,
        presenter: Presenter<LocalState, LocalAction, LocalEnvironment>
    ) -> Self where Action: PresentableAction, Action.State == State {
        self._presents(state: toLocalState, action: toLocalAction, environment: toLocalEnvironment, presenter: presenter).presentable()
    }

    private func _presents<LocalState, LocalAction, LocalEnvironment>(
        state toLocalState: WritableKeyPath<State, PresentationPhase<LocalState>>,
        action toLocalAction: CasePath<Action, LocalAction>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment,
        presenter: Presenter<LocalState, LocalAction, LocalEnvironment>
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
}

extension Reducer {

    /// Manage presentation and dismissal lifecycle for mutually exclusive state.
    public func presents<LocalState, LocalAction, LocalEnvironment>(
        state toLocalState: WritableKeyPath<State, ExclusivePresentationPhase<LocalState>>,
        action toLocalAction: CasePath<Action, LocalAction>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment,
        presenter: Presenter<LocalState, LocalAction, LocalEnvironment>
    ) -> Self {
        self._presents(state: toLocalState, action: toLocalAction, environment: toLocalEnvironment, presenter: presenter)
    }

    /// Manage presentation and dismissal lifecycle for mutually exclusive state.
    public func presents<LocalState, LocalAction, LocalEnvironment>(
        state toLocalState: WritableKeyPath<State, ExclusivePresentationPhase<LocalState>>,
        action toLocalAction: CasePath<Action, LocalAction>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment,
        presenter: Presenter<LocalState, LocalAction, LocalEnvironment>
    ) -> Self where Action: PresentableAction, Action.State == State {
        self._presents(state: toLocalState, action: toLocalAction, environment: toLocalEnvironment, presenter: presenter).presentable()
    }

    private func _presents<LocalState, LocalAction, LocalEnvironment>(
        state toLocalState: WritableKeyPath<State, ExclusivePresentationPhase<LocalState>>,
        action toLocalAction: CasePath<Action, LocalAction>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment,
        presenter: Presenter<LocalState, LocalAction, LocalEnvironment>
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
}


extension Reducer {

    /// Manage presentation and dismissal lifecycle for each state.
    public func presents<LocalState, LocalAction, LocalEnvironment, ID>(
        state toLocalState: WritableKeyPath<State, IdentifiedArrayOfPresentationPhase<ID, LocalState>>,
        action toLocalAction: CasePath<Action, (ID, LocalAction)>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment,
        presenter: Presenter<LocalState, LocalAction, LocalEnvironment>
    ) -> Self {
        self._presents(state: toLocalState, action: toLocalAction, environment: toLocalEnvironment, presenter: presenter)
    }


    /// Manage presentation and dismissal lifecycle for each state.
    public func presents<LocalState, LocalAction, LocalEnvironment, ID>(
        state toLocalState: WritableKeyPath<State, IdentifiedArrayOfPresentationPhase<ID, LocalState>>,
        action toLocalAction: CasePath<Action, (ID, LocalAction)>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment,
        presenter: Presenter<LocalState, LocalAction, LocalEnvironment>
    ) -> Self where Action: PresentableAction, Action.State == State {
        self._presents(state: toLocalState, action: toLocalAction, environment: toLocalEnvironment, presenter: presenter).presentable()
    }

    public func _presents<LocalState, LocalAction, LocalEnvironment, ID>(
        state toLocalState: WritableKeyPath<State, IdentifiedArrayOfPresentationPhase<ID, LocalState>>,
        action toLocalAction: CasePath<Action, (ID, LocalAction)>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment,
        presenter: Presenter<LocalState, LocalAction, LocalEnvironment>
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
                presentationEffects
            )
        }
    }
}

fileprivate extension PresentationPhase {
    mutating func run<Action, GlobalAction, Environment>(
        presenter: Presenter<State, Action, Environment>,
        environment: Environment,
        mapAction: @escaping (Action) -> GlobalAction
    ) -> Effect<GlobalAction, Never> {
        switch self {
        case .dismissed:
            return .none
        case .shouldPresent(let state):
            self = .presented(state)
            return presenter(state, .present, environment).effect.map(mapAction)
        case .presented:
            return .none
        case .shouldDismiss(let state):
            switch presenter(state, .dismiss, environment) {
            case .action(let effect):
                self = .dismissing(state)
                return effect.map(mapAction)
            case .immediate(let effect):
                self = .dismissed
                return effect.map(mapAction)
            }
        case .dismissing:
            self = .dismissed
            return .none
        }
    }
}

fileprivate extension ExclusivePresentationPhase {
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
                var phase = PresentationPhase.shouldPresent(to)
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

fileprivate extension IdentifiedArrayOfPresentationPhase {
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
