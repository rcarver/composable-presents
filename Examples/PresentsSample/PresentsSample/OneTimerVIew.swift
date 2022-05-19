import Combine
import ComposableArchitecture
import ComposablePresents
import SwiftUI

struct OneTimerView: View {
    let store: Store<OneTimerState, OneTimerAction> = .init(
        initialState: .init(),
        reducer: oneTimerReducer,
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
        VStack {
            IfLetStore(store.scope(state: \.timer, action: OneTimerAction.timerOption)) { ifStore in
                SwitchStore(ifStore) {
                    CaseLet(state: /TimerOption.fast, action: TimerOptionAction.fast) { store in
                        TimerView(store: store)
                    }
                    CaseLet(state: /TimerOption.slow, action: TimerOptionAction.slow) { store in
                        TimerView(store: store)
                    }
                }
            } else: {
                Text("No Timer")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            WithViewStore(store) { viewStore in
                VStack {
                    Button {
                        viewStore.send(.startFast, animation: .default)
                    } label: {
                        Text("Fast Timer")
                    }
                    Button {
                        viewStore.send(.startSlow, animation: .default)
                    } label: {
                        Text("Slow Timer")
                    }
                    Text("One timer at a time.\nSwitching timers cancels one if running.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.thinMaterial)
            }
        }
        .navigationBarTitle("Timers")
    }
}

fileprivate struct TimerView: View {
    let store: Store<TimerState, TimerAction>
    var body: some View {
        GroupBox {
            WithViewStore(store) { viewStore in
                HStack {
                    Text(viewStore.name)
                    Spacer()
                    Text(viewStore.count.formatted())
                    Button {
                        viewStore.send(.finished, animation: .default)
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle")
                    }
                    .labelStyle(.iconOnly)
                }
            }
        }
        .padding()
    }
}

struct OneTimer_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OneTimerView()
        }
    }
}

struct OneTimerState: Equatable {
    @PresentsOne var timer: TimerOption?
}

enum OneTimerAction {
    case startFast
    case startSlow
    case timerOption(TimerOptionAction)
}

struct OneTimerEnvironment {
    var fastTicks: () -> Effect<Void, Never>
    var slowTicks: () -> Effect<Void, Never>
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var timerOption: TimerOptionEnvironment {
        .init(mainQueue: mainQueue, fastTicks: fastTicks, slowTicks: slowTicks)
    }
}

let oneTimerReducer = Reducer<OneTimerState, OneTimerAction, OneTimerEnvironment>.combine(
    timerOptionReducer.optional().pullback(
        state: \.timer,
        action: /OneTimerAction.timerOption,
        environment: \.timerOption
    ),
    Reducer { state, action, environment in
        switch action {
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
            action: /OneTimerAction.timerOption,
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
)
