import ComposableArchitecture

/// An action type that defines a convention for actions that perform
/// long-running effects as part of their reducer lifecycle.
public protocol LongRunningAction {
    static func longRunning(_ event: LongRunningEvent) -> Self
}

/// The events performed for `LongRunningAction`.
public enum LongRunningEvent {

    /// Start running long-running effects.
    ///
    /// Long-running effects are anything that is performed on a scheduler,
    /// and thus outside a single loop of the reducer process.
    ///
    /// The reducer is responsible for cancellation of any effects started here.
    case start

    /// Stop running long-running effects.
    ///
    /// Cancel all long-running effects performed by the reducer, including
    /// those from `begin` and any others that may be in-flight.
    case stop
}

extension Presenter where Action: LongRunningAction {
    /// Construct a `Presenter` from a `Reducer` of `LongRunningAction`.
    public static func longRunning(_ reducer: Reducer<State, Action, Environment>) -> Self {
        .init { _, action, _ in
            switch action {
            case .present: return .action(Effect(value: .longRunning(.start)))
            case .dismiss: return .action(Effect(value: .longRunning(.stop)))
            }
        }
    }
}
