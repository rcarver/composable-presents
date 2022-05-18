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
            let presentationEffects = presenter.run(
                &globalState[keyPath: toLocalState],
                toLocalEnvironment(globalEnvironment)
            ).map(toLocalAction.embed)
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
            let presentationEffects = globalState[keyPath: toLocalState].array.ids.map { id in
                presenter.run(
                    &globalState[keyPath: toLocalState].array[id: id]!.phase,
                    toLocalEnvironment(globalEnvironment)
                ).map { toLocalAction.embed((id, $0)) }
            }
            return .merge(
                globalEffects,
                .merge(presentationEffects)
            )
        }
    }
}
