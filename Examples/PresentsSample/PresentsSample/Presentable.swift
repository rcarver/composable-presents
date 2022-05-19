import CustomDump
import SwiftUI
import ComposablePresents
import ComposableArchitecture

public typealias PresentableState = PresentsCase

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
    public static func set<Value, ID: Hashable>(
        _ keyPath: WritableKeyPath<Root, ExclusivePresentationPhase<Value>>,
        value: Value,
        id: KeyPath<Value, ID>
    ) -> Self
    where Value: Equatable {
        .init(
            keyPath: keyPath,
            set: { $0[keyPath: keyPath].activate(with: value, id: id) },
            value: value,
            valueIsEqualTo: { $0 as? Value == value }
        )
    }
    public static func dismiss<Value, ID: Hashable>(
        _ keyPath: WritableKeyPath<Root, ExclusivePresentationPhase<Value>>,
        id: KeyPath<Value, ID>
    ) -> Self {
        .init(
            keyPath: keyPath,
            set: { $0[keyPath: keyPath].activate(with: nil, id: id) },
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
