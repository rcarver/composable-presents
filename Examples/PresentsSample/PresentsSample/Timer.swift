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

enum TimerOption: Equatable {
    case fast(TimerState)
    case slow(TimerState)
}

extension TimerOption: CaseIdentifiable {
    var caseIdentity: AnyHashable {
        switch self {
        case .fast: return "fast"
        case .slow: return "slow"
        }
    }
}

extension TimerOption: Identifiable {
    var id: AnyHashable {
        switch self {
        case .fast: return "fast"
        case .slow: return "slow"
        }
    }
}

enum TimerOptionAction {
    case fast(TimerAction)
    case slow(TimerAction)
}

struct TimerOptionEnvironment {
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var fastTicks: () -> Effect<Void, Never>
    var slowTicks: () -> Effect<Void, Never>
}

let timerOptionReducer = Reducer<TimerOption, TimerOptionAction, TimerOptionEnvironment>.combine(
    timerReducer.pullback(
        state: /TimerOption.fast,
        action: /TimerOptionAction.fast,
        environment: { .init(ticks: $0.fastTicks, mainQueue: $0.mainQueue) }
    ),
    timerReducer.pullback(
        state: /TimerOption.slow,
        action: /TimerOptionAction.slow,
        environment: { .init(ticks: $0.slowTicks, mainQueue: $0.mainQueue) }
    )
)
