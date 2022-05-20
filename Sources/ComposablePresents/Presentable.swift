import CustomDump
import SwiftUI
import ComposableArchitecture

/// An action type that enables presentation and dismissal, allowing
/// state to be modified outside of a reducer.
///
/// Adopting this protocol lets you use the SwiftUI navigation helpers
/// with @Presents property wrappers.
public protocol PresentableAction {
    associatedtype State
    static func presents(_ action: PresentsAction<State>) -> Self
}

/// An action that describes changes to presented state.
public struct PresentsAction<Root> {
    let keyPath: PartialKeyPath<Root>
    let set: (inout Root) -> Void
    let value: Any?
    let valueIsEqualTo: (Any?) -> Bool
}

extension PresentsAction: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.keyPath == rhs.keyPath && lhs.valueIsEqualTo(rhs.value)
    }
}

extension PresentsAction {
    /// Set the state, triggering new presentation.
    public static func set<Value>(
        _ keyPath: WritableKeyPath<Root, PresentationPhase<Value>>,
        value: Value
    ) -> Self
    where Value: Equatable, Value: Identifiable {
        .init(
            keyPath: keyPath,
            set: { $0[keyPath: keyPath].activate(with: value) },
            value: value,
            valueIsEqualTo: { $0 as? Value == value }
        )
    }
    /// Dismiss the state.
    public static func dismiss<Value>(
        _ keyPath: WritableKeyPath<Root, PresentationPhase<Value>>
    ) -> Self
    where Value: Identifiable {
        .init(
            keyPath: keyPath,
            set: { $0[keyPath: keyPath].activate(with: nil) },
            value: nil,
            valueIsEqualTo: { _ in true }
        )
    }
}

extension PresentsAction {
    /// Set the state, triggering new presentation.
    public static func set<Value>(
        _ keyPath: WritableKeyPath<Root, ExclusivePresentationPhase<Value>>,
        value: Value
    ) -> Self
    where Value: Equatable, Value: Identifiable {
        .init(
            keyPath: keyPath,
            set: { $0[keyPath: keyPath].activate(with: value) },
            value: value,
            valueIsEqualTo: { $0 as? Value == value }
        )
    }
    /// Dismiss the state.
    public static func dismiss<Value>(
        _ keyPath: WritableKeyPath<Root, ExclusivePresentationPhase<Value>>
    ) -> Self
    where Value: Identifiable {
        .init(
            keyPath: keyPath,
            set: { $0[keyPath: keyPath].activate(with: nil) },
            value: nil,
            valueIsEqualTo: { _ in true }
        )
    }
}

extension Reducer where Action: PresentableAction, State == Action.State {
    /// Returns a Reducer that applies `PresentsAction` mutations before running this reducer's logic.
    ///
    /// Note that the `presents()` reducer adds this functionality when appropriate, so
    /// you don't generally need to use it directly.
    func presentable() -> Self {
        Self { state, action, environment in
            guard let presentsAction = (/Action.presents).extract(from: action)
            else {
                return self.run(&state, action, environment)
            }

            presentsAction.set(&state)
            return self.run(&state, action, environment)
        }
    }
}
