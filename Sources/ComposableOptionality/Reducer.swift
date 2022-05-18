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
}
