import ComposableArchitecture

extension Reducer {
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
            )
            return .merge(
                globalEffects,
                presentationEffects.map(toLocalAction.embed)
            )
        }
    }
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
            for id in globalState[keyPath: toLocalState].array.ids {
                print("aREDUC", id)
                print("a>", globalState[keyPath: toLocalState].array[id: id]!.phase)
            }
            let presentationEffects = globalState[keyPath: toLocalState].array.ids.map { id in
                presenter.run(
                    &globalState[keyPath: toLocalState].array[id: id]!.phase,
                    toLocalEnvironment(globalEnvironment)
                )
                .map { toLocalAction.embed((id, $0)) }
            }
            for id in globalState[keyPath: toLocalState].array.ids {
                print("bREDUC", id)
                print("b>", globalState[keyPath: toLocalState].array[id: id]!.phase)
            }
            return .merge(
                globalEffects,
                .merge(presentationEffects)
            )
        }
    }
}
