import ComposableArchitecture

/// The actions for presentation.
enum PresentationAction {
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
struct Presenter<State, Action, Environment> {
    var presenter: (State, PresentationAction, Environment) -> Effect<Action, Never>
}

extension Presenter {

    /// Returns presentation effects for state.
    func present<NewOutput, NewFailure>(
        state: State,
        environment: Environment,
        outputType: NewOutput.Type = NewOutput.self,
        failureType: NewFailure.Type = NewFailure.self
    ) -> Effect<NewOutput, NewFailure> {
        presenter(state, .present, environment).fireAndForget()
    }

    /// Returns dismissal effects for state.
    func dismiss<NewOutput, NewFailure>(
        state: State,
        environment: Environment,
        outputType: NewOutput.Type = NewOutput.self,
        failureType: NewFailure.Type = NewFailure.self
    ) -> Effect<NewOutput, NewFailure> {
        presenter(state, .dismiss, environment).fireAndForget()
    }
}

/*
import ComposablePresentation

extension Reducer {
    func presenting<LocalState, LocalID: Hashable, LocalAction, LocalEnvironment>(
        _ localReducer: Reducer<LocalState, LocalAction, LocalEnvironment>,
        state toLocalState: ReducerPresentingToLocalState<State, LocalState>,
        id toLocalId: ReducerPresentingToLocalId<LocalState, LocalID>,
        action toLocalAction: CasePath<Action, LocalAction>,
        environment toLocalEnvironment: @escaping (Environment) -> LocalEnvironment,
        presenter: Presenter<LocalState, LocalAction, LocalEnvironment>,
        file: StaticString = #fileID,
        line: UInt = #line
    ) -> Self {
        self.presenting(
            localReducer,
            state: toLocalState,
            id: toLocalId,
            action: toLocalAction,
            environment: toLocalEnvironment,
            onPresent: .init(run: { presenter.present(state: $1, environment: toLocalEnvironment($2)) }),
            onDismiss: .init(run: { presenter.dismiss(state: $1, environment: toLocalEnvironment($2)) }),
            file: file,
            line: line
        )
    }
}
*/
