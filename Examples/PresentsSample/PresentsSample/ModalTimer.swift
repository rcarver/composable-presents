import Combine
import ComposableArchitecture
import ComposablePresents
import SwiftUI

struct ModalTimerView: View {
    let store: Store<ModalTimerState, ModalTimerAction> = .init(
        initialState: .init(),
        reducer: modalTimerReducer,
        environment: .init(
            fastTicks: {
                Timer.publish(every: 0.25, on: .main, in: .default)
                    .autoconnect()
                    .map { _ in () }
                    .eraseToEffect()
            },
            slowTicks: {
                Timer.publish(every: 1, on: .main, in: .default)
                    .autoconnect()
                    .map { _ in () }
                    .eraseToEffect()
            },
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
        ))
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                Button {
                    viewStore.send(.startFast)
                } label: {
                    Text("Fast Timer")
                }
                Button {
                    viewStore.send(.startSlow)
                } label: {
                    Text("Slow Timer")
                }
            }
        }
        .sheet(
            store: store,
            state: \.$timer,
            action: ModalTimerAction.timerOption,
            caseState: /TimerOption.fast,
            caseAction: TimerOptionAction.fast
        ) { sheetStore in
            NavigationView {
                TimerView(store: sheetStore)
            }
        }
        .sheet(
            store: store,
            state: \.$timer,
            action: ModalTimerAction.timerOption,
            caseState: /TimerOption.slow,
            caseAction: TimerOptionAction.slow
        ) { sheetStore in
            NavigationView {
                TimerView(store: sheetStore)
            }
        }
    }
}
extension View {
    public func sheet<State, Action, EnumState, EnumAction, CaseState, CaseAction, Content>(
        store: Store<State, Action>,
        state toEnumState: WritableKeyPath<State, ExclusivePresentationPhase<EnumState>>,
        action toEnumAction: @escaping (EnumAction) -> Action,
        caseState toCaseState: CasePath<EnumState, CaseState>,
        caseAction toCaseAction: @escaping (CaseAction) -> EnumAction,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Store<CaseState, CaseAction>) -> Content
    ) -> some View
    where Content: View, Action: PresentableAction, Action.State == State, EnumState: CaseIdentifiable {
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
                                viewStore.send(.presents(.dismiss(toEnumState, id: \.caseIdentity)))
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

fileprivate struct TimerView: View {
    let store: Store<TimerState, TimerAction>
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack {
                Text(viewStore.count.formatted())
                    .monospacedDigit()
                    .font(.headline)
            }
            .navigationTitle(Text(viewStore.name))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewStore.send(.finished, animation: .default)
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle.fill")
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
    }
}

struct ModalTimer_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ModalTimerView()
        }
    }
}

struct ModalTimerState: Equatable {
    @PresentsCase var timer: TimerOption?
}

enum ModalTimerAction: PresentableAction {
    case presents(PresentingAction<ModalTimerState>)
    case startFast
    case startSlow
    case timerOption(TimerOptionAction)
}

struct ModalTimerEnvironment {
    var fastTicks: () -> Effect<Void, Never>
    var slowTicks: () -> Effect<Void, Never>
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var timerOption: TimerOptionEnvironment {
        .init(mainQueue: mainQueue, fastTicks: fastTicks, slowTicks: slowTicks)
    }
}

let modalTimerReducer = Reducer<ModalTimerState, ModalTimerAction, ModalTimerEnvironment>.combine(
    timerOptionReducer.optional().pullback(
        state: \.timer,
        action: /ModalTimerAction.timerOption,
        environment: \.timerOption
    ),
    Reducer { state, action, environment in
        switch action {
        case .presents:
            return .none
        case .startFast:
            state.timer = .fast(.init(name: "Fast", count: 10))
            return .none
        case .startSlow:
            state.timer = .slow(.init(name: "Slow", count: 10))
            return .none
        case .timerOption(.fast(.finished)):
            state.timer = nil
            return .none
        case .timerOption(.slow(.finished)):
            state.timer = nil
            return .none
        case .timerOption:
            return .none
        }
    }
        .presents(
            state: \.$timer,
            action: /ModalTimerAction.timerOption,
            environment: \.timerOption,
            presenter: .init { state, action, environment in
                switch (action, state) {
                case (.present, .fast): return Effect(value: .fast(.begin))
                case (.present, .slow): return Effect(value: .slow(.begin))
                case (.dismiss, .fast): return Effect(value: .fast(.cancel))
                case (.dismiss, .slow): return Effect(value: .slow(.cancel))
                }
            }
        )
        .presentable()
)
    .debugActions()
