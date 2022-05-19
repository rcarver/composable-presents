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
            VStack(spacing: 20) {
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
                Button {
                    viewStore.send(.presents(.set(\.$timer, value: .fast(.init(name: "Custom", count: 5)))))
                } label: {
                    Text("Custom Fast Timer")
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
    @PresentsOne var timer: TimerOption?
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
