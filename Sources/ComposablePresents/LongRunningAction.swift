import ComposableArchitecture

/// Defines a convention for actions that perform long-running effects as
/// part of their reducer lifecycle.
public protocol LongRunningAction {

    /// Begin performing long-running effects.
    ///
    /// Long-running effects are anything that is performed on a scheduler,
    /// and thus outside a single loop of the reducer process.
    ///
    /// The reducer is responsible for cancellation of any effects started here.
    static var begin: Self { get }

    /// Cancel long-running effects.
    ///
    /// Cancel all long-running effects performed by the reducer, including
    /// those from `begin` and any others that may be in-flight.
    static var cancel: Self { get }
}

extension Presenter where Action: LongRunningAction {
    /// Construct a `Presenter` from a `Reducer` of `LongRunningAction`.
    public static func longRunning(_ reducer: Reducer<State, Action, Environment>) -> Self {
        .init { _, action, _ in
            switch action {
            case .present: return Effect(value: .begin)
            case .dismiss: return Effect(value: .cancel)
            }
        }
    }
}
