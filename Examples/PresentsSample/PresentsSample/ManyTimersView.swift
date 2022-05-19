import Combine
import ComposableArchitecture
import ComposablePresents
import SwiftUI

struct ManyTimersView: View {
    let store: Store<ManyTimersState, ManyTimersAction> = .init(
        initialState: .init(),
        reducer: manyTimersReducer,
        environment: .init(
            ticks: {
                Timer.publish(every: 1, on: .main, in: .default)
                    .autoconnect()
                    .map { _ in () }
                    .eraseToEffect()
            },
            mainQueue: DispatchQueue.main.eraseToAnyScheduler()
        ))
    var body: some View {
        List {
            ForEachStore(store.scope(
                state: \.timers,
                action: ManyTimersAction.timer
            )) { eachStore in
                TimerView(store: eachStore)
            }
        }
        .safeAreaInset(edge: .bottom) {
            WithViewStore(store) { viewStore in
                VStack {
                    Button {
                        viewStore.send(.startTimer(
                            name: names.randomElement()!,
                            limit: (2...10).randomElement()!
                        ), animation: .default)
                    } label: {
                        Text("New Timer")
                    }
                    Text("^[\(viewStore.timers.count) timers](inflect: true)")
                    Text("Many timers can run in parallel")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
}

fileprivate var names = [
    "Pasta",
    "Tea",
    "Coffee",
    "Workout",
    "Meditation"
]

struct ManyTimers_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ManyTimersView()
        }
    }
}

struct ManyTimersState: Equatable {
    @PresentsEach var timers: IdentifiedArrayOf<TimerState> = []
}

enum ManyTimersAction: Equatable {
    case startTimer(name: String, limit: Int)
    case timer(id: TimerState.ID, action: TimerAction)
}

struct ManyTimersEnvironment {
    var ticks: () -> Effect<Void, Never>
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var timer: TimerEnvironment {
        .init(ticks: ticks, mainQueue: mainQueue)
    }
}

let manyTimersReducer = Reducer<ManyTimersState, ManyTimersAction, ManyTimersEnvironment>.combine(
    timerReducer.forEach(
        state: \.timers,
        action: /ManyTimersAction.timer,
        environment: \.timer
    ),
    Reducer { state, action, environment in
        switch action {
        case .startTimer(let name, let limit):
            state.timers.append(
                .init(name: name, count: limit)
            )
            return .none
        case .timer(let id, action: .finished):
            state.timers.remove(id: id)
            return .none
        case .timer:
            return .none
        }
    }
        .presents(
            state: \.$timers,
            action: /ManyTimersAction.timer,
            environment: \.timer,
            presenter: .longRunning(timerReducer)
        )
)
