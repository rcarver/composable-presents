import Combine
import ComposableArchitecture
import ComposablePresents
import SwiftUI

struct ModalTimerIdView: View {
    let store: Store<ModalTimerIdState, ModalTimerIdAction> = .init(
        initialState: .init(),
        reducer: modalTimerIdReducer,
        environment: .init(
            ticks: {
                Timer.publish(every: 1, on: .main, in: .default)
                    .autoconnect()
                    .map { _ in () }
                    .eraseToEffect()
            },
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
        ))
    let foodTimer = TimerState(name: "Food", count: 10)
    let workoutTimer = TimerState(name: "Workout", count: 10)
    var body: some View {
        WithViewStore(store) { viewStore in
            VStack(spacing: 20) {
                Button {
                    viewStore.send(.presents(.set(\.$timer, value: foodTimer)))
                } label: {
                    Text("Food Timer")
                }
                Button {
                    viewStore.send(.presents(.set(\.$timer, value: workoutTimer)))
                } label: {
                    Text("Workout Timer")
                }
            }
        }
        .sheet(
            store: store,
            state: \.$timer,
            action: ModalTimerIdAction.timer
        ) { sheetStore in
            NavigationView {
                VStack {
                    TimerView(store: sheetStore)
                    WithViewStore(store.stateless) { outerViewStore in
                        WithViewStore(sheetStore) { viewStore in
                            switch viewStore.id {
                            case foodTimer.id:
                                Button {
                                    outerViewStore.send(.presents(.set(\.$timer, value: workoutTimer)))
                                } label: {
                                    Text("Switch to Workout Timer")
                                }
                            case workoutTimer.id:
                                Button {
                                    outerViewStore.send(.presents(.set(\.$timer, value: foodTimer)))
                                } label: {
                                    Text("Switch to Food Timer")
                                }
                            default:
                                EmptyView()
                            }
                        }
                    }
                }
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

struct ModalTimerId_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ModalTimerIdView()
        }
    }
}

struct ModalTimerIdState: Equatable {
    @PresentsOne var timer: TimerState?
}

enum ModalTimerIdAction: PresentableAction {
    case presents(PresentsAction<ModalTimerIdState>)
    case timer(TimerAction)
}

struct ModalTimerIdEnvironment {
    var ticks: () -> Effect<Void, Never>
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var timer: TimerEnvironment {
        .init(ticks: ticks, mainQueue: mainQueue)
    }
}

let modalTimerIdReducer = Reducer<ModalTimerIdState, ModalTimerIdAction, ModalTimerIdEnvironment>.combine(
    timerReducer.optional().pullback(
        state: \.timer,
        action: /ModalTimerIdAction.timer,
        environment: \.timer
    ),
    Reducer { state, action, environment in
        switch action {
        case .presents:
            return .none
        case .timer(.finished):
            state.timer = nil
            return .none
        case .timer:
            return .none
        }
    }
        .presents(
            state: \.$timer,
            action: /ModalTimerIdAction.timer,
            environment: \.timer,
            presenter: .longRunning(timerReducer)
        )
)
    .debugActions()
