import CustomDump
import SwiftUI
import ComposablePresents
import ComposableArchitecture

public typealias PresentableState = PresentsOne

public protocol PresentableAction {
    associatedtype State
    static func presents(_ action: PresentingAction<State>) -> Self
}

public struct PresentingAction<Root>: Equatable {
    public let keyPath: PartialKeyPath<Root>

    let set: (inout Root) -> Void
    let value: Any?
    let valueIsEqualTo: (Any?) -> Bool

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.keyPath == rhs.keyPath && lhs.valueIsEqualTo(rhs.value)
    }
}

extension PresentingAction {
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
    public func presentable() -> Self {
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
