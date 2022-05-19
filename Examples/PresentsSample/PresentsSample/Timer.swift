import ComposableArchitecture
import ComposablePresents

struct TimerState: Equatable, Identifiable {
    var id = UUID()
    var name: String
    var count: Int
}

enum TimerAction: Equatable, LongRunningAction {
    case begin
    case cancel
    case tick
    case finished
}

struct TimerEnvironment {
    var ticks: () -> Effect<Void, Never>
    var mainQueue: AnySchedulerOf<DispatchQueue>
}

struct TimerEffect: Hashable { let id: AnyHashable }

let timerReducer = Reducer<TimerState, TimerAction, TimerEnvironment>.combine(
    Reducer { state, action, environment in
        switch action {
        case .tick:
            state.count -= 1
            if state.count <= 0 {
                return Effect(value: .finished)
                    .receive(on: environment.mainQueue.animation(.default))
                    .eraseToEffect()
            } else {
                return .none
            }
        case .begin:
            return environment.ticks()
                .receive(on: environment.mainQueue)
                .eraseToEffect { TimerAction.tick }
                .cancellable(id: TimerEffect(id: state.id))
        case .cancel:
            return .cancel(id: TimerEffect(id: state.id))
        case .finished:
            return .none
        }
    }
)
