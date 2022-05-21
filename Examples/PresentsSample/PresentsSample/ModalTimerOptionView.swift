import Combine
import ComposableArchitecture
import ComposablePresents
import SwiftUI

struct ModalTimerOptionView: View {
    let store: Store<ModalTimerOptionState, ModalTimerOptionAction> = .init(
        initialState: .init(),
        reducer: modalTimerOptionReducer,
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
            action: ModalTimerOptionAction.timerOption,
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
            action: ModalTimerOptionAction.timerOption,
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

struct ModalTimerOption_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ModalTimerOptionView()
        }
    }
}

struct ModalTimerOptionState: Equatable {
    @PresentsOne var timer: TimerOption?
}

enum ModalTimerOptionAction: PresentableAction {
    case presents(PresentsAction<ModalTimerOptionState>)
    case startFast
    case startSlow
    case timerOption(TimerOptionAction)
}

struct ModalTimerOptionEnvironment {
    var fastTicks: () -> Effect<Void, Never>
    var slowTicks: () -> Effect<Void, Never>
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var timerOption: TimerOptionEnvironment {
        .init(mainQueue: mainQueue, fastTicks: fastTicks, slowTicks: slowTicks)
    }
}

let modalTimerOptionReducer = Reducer<ModalTimerOptionState, ModalTimerOptionAction, ModalTimerOptionEnvironment>.combine(
    timerOptionReducer.optional().pullback(
        state: \.timer,
        action: /ModalTimerOptionAction.timerOption,
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
            action: /ModalTimerOptionAction.timerOption,
            environment: \.timerOption,
            presenter: .init { state, action, environment in
                switch (action, state) {
                case (.present, .fast): return .action(.fast(.start))
                case (.present, .slow): return .action(.slow(.start))
                case (.dismiss, .fast): return .action(.fast(.stop))
                case (.dismiss, .slow): return .action(.slow(.stop))
                }
            }
        )
)
    .debugActions()
