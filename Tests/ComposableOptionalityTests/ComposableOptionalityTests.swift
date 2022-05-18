import ComposableArchitecture
import Combine
import XCTest

import ComposableOptionality

final class ComposableOptionalityTests: XCTestCase {

    func test_design_single() {

        struct ChildState: Equatable {
            var name: String
            var age: Int
        }

        enum ChildAction: Equatable, LongRunningAction {
            case begin
            case cancel
            case setAge(Int)
        }

        struct ChildEnvironment {
            var years: () -> Effect<Int, Never>
            var mainQueue: AnySchedulerOf<DispatchQueue>
        }

        enum ChildEffect {}

        let ChildReducer = Reducer<ChildState, ChildAction, ChildEnvironment>.combine(
            Reducer { state, action, environment in
                switch action {
                case .setAge(let age):
                    state.age = age
                    return .none
                case .begin:
                    return environment.years()
                        .receive(on: environment.mainQueue)
                        .eraseToEffect(ChildAction.setAge)
                        .cancellable(id: ChildEffect.self)
                case .cancel:
                    return .cancel(id: ChildEffect.self)
                }
            }
        )

        struct ParentState: Equatable {
            @Presented var child: ChildState?
        }

        enum ParentAction: Equatable {
            case born
            case died
            case child(ChildAction)
        }

        struct ParentEnvironment {
            var years: () -> Effect<Int, Never>
            var mainQueue: AnySchedulerOf<DispatchQueue>
        }

        let ParentReducer = Reducer<ParentState, ParentAction, ParentEnvironment>{ state, action, environment in
            switch action {
            case .born:
                state.child = .init(name: "John", age: 0)
                return .none
            case .died:
                state.child = nil
                return .none
            case .child:
                return .none
            }
        }
            .present(
                reducer: ChildReducer,
                state: \.$child,
                action: /ParentAction.child,
                environment: { .init(years: $0.years, mainQueue: $0.mainQueue) }
            )

        let mainQueue = DispatchQueue.test

        let store = TestStore(
            initialState: .init(),
            reducer: ParentReducer,
            environment: .init(
                years: {
                    (1..<10).publisher
                        .flatMap(maxPublishers: .max(1)) {
                            Just($0).delay(for: 1, scheduler: mainQueue)
                        }
                        .eraseToEffect()
                },
                mainQueue: mainQueue.eraseToAnyScheduler()
            )
        )

        store.send(.born) {
            $0.$child = .presented(.init(name: "John", age: 0))
        }

        store.receive(.child(.begin))

        mainQueue.advance(by: 1)
        store.receive(.child(.setAge(1))) {
            $0.$child.state?.age = 1
        }

        mainQueue.advance(by: 1)
        store.receive(.child(.setAge(2))) {
            $0.$child.state?.age = 2
        }

        store.send(.died) {
            $0.$child = .cancelling(.init(name: "John", age: 2))
        }
        store.receive(.child(.cancel)) {
            $0.$child = .dismissed
        }
    }

    func test_design() {

        struct ParentState: Equatable {
            var children: IdentifiedArrayOf<ChildState> = []
        }

        struct ChildState: Equatable, Identifiable {
            var id: String { name }
            var name: String
            var age: Int
        }

        enum ParentAction: Equatable {
            case child(id: ChildState.ID, action: ChildAction)
        }

        enum ChildAction: Equatable {
            case birthday
        }

        let ParentReducer = Reducer<ParentState, ParentAction, ()> { state, action, environment in
                .none
        }

    }
}
