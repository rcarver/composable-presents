import ComposableArchitecture
import ComposablePresents
import SwiftUI

extension View {
    /// Present a sheet using identifiable state.
    public func sheet<State, Action, LocalState, LocalAction, Content>(
        store: Store<State, Action>,
        state toLocalState: WritableKeyPath<State, ExclusivePresentationPhase<LocalState>>,
        action toLocalAction: @escaping (LocalAction) -> Action,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Store<LocalState, LocalAction>) -> Content
    ) -> some View
    where Content: View, Action: PresentableAction, Action.State == State, LocalState: Identifiable {
        func getLocalState(_ state: State) -> LocalState? {
            state[keyPath: toLocalState].currentState
        }
        return self.background(
            WithViewStore(store.scope(state: { getLocalState($0) != nil })) { viewStore in
                EmptyView().sheet(
                    isPresented: Binding(
                        get: { viewStore.state },
                        set: {
                            if !$0 && viewStore.state {
                                viewStore.send(.presents(.dismiss(toLocalState)))
                            }
                        }
                    )
                ) {
                    IfLetStore(
                        store.scope(state: getLocalState, action: { toLocalAction($0) }),
                        then: content
                    )
                }
            }
        )
    }
}

extension View {
    /// Present a sheet of a specific case of an enum.
    public func sheet<State, Action, EnumState, EnumAction, CaseState, CaseAction, Content>(
        store: Store<State, Action>,
        state toEnumState: WritableKeyPath<State, ExclusivePresentationPhase<EnumState>>,
        action toEnumAction: @escaping (EnumAction) -> Action,
        caseState toCaseState: CasePath<EnumState, CaseState>,
        caseAction toCaseAction: @escaping (CaseAction) -> EnumAction,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Store<CaseState, CaseAction>) -> Content
    ) -> some View
    where Content: View, Action: PresentableAction, Action.State == State, EnumState: Identifiable {
        func getCaseState(_ state: State) -> CaseState? {
            guard let enumState = state[keyPath: toEnumState].currentState else { return nil }
            return toCaseState.extract(from: enumState)
        }
        return self.background(
            WithViewStore(store.scope(state: { getCaseState($0) != nil })) { viewStore in
                EmptyView().sheet(
                    isPresented: Binding(
                        get: { viewStore.state },
                        set: {
                            if !$0 && viewStore.state {
                                viewStore.send(.presents(.dismiss(toEnumState)))
                            }
                        }
                    )
                ) {
                    IfLetStore(
                        store.scope(state: getCaseState, action: { toEnumAction(toCaseAction($0)) }),
                        then: content
                    )
                }
            }
        )
    }
}
