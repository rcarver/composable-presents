import ComposableArchitecture
import Combine
import XCTest

import ComposableOptionality

final class ComposableOptionalityTests: XCTestCase {

    struct PersonState: Equatable {
        var name: String
        var age: Int
    }

    enum PersonAction: Equatable, LongRunningAction {
        case begin
        case cancel
        case setAge(Int)
    }

    struct PersonEnvironment {
        var years: () -> Effect<Int, Never>
        var mainQueue: AnySchedulerOf<DispatchQueue>
    }

    enum PersonEffect {}

    let PersonReducer = Reducer<PersonState, PersonAction, PersonEnvironment>.combine(
        Reducer { state, action, environment in
            switch action {
            case .setAge(let age):
                state.age = age
                return .none
            case .begin:
                return environment.years()
                    .receive(on: environment.mainQueue)
                    .eraseToEffect(PersonAction.setAge)
                    .cancellable(id: PersonEffect.self)
            case .cancel:
                return .cancel(id: PersonEffect.self)
            }
        }
    )

    func test_design_single() {

        struct WorldState: Equatable {
            @Presented var person: PersonState?
        }
        enum WorldAction: Equatable {
            case born
            case died
            case person(PersonAction)
        }
        struct WorldEnvironment {
            var years: () -> Effect<Int, Never>
            var mainQueue: AnySchedulerOf<DispatchQueue>
            var person: PersonEnvironment {
                .init(years: years, mainQueue: mainQueue)
            }
        }
        let WorldReducer = Reducer<WorldState, WorldAction, WorldEnvironment>.combine(
            PersonReducer.optional().pullback(
                state: \.person,
                action: /WorldAction.person,
                environment: \.person
            ),
            Reducer { state, action, environment in
                switch action {
                case .born:
                    state.person = .init(name: "John", age: 0)
                    return .none
                case .died:
                    state.person = nil
                    return .none
                case .person:
                    return .none
                }
            }
                .present(
                    with: .longRunning(PersonReducer),
                    state: \.$person,
                    action: /WorldAction.person,
                    environment: \.person
                )
        )

        let mainQueue = DispatchQueue.test

        let store = TestStore(
            initialState: .init(),
            reducer: WorldReducer,
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
            $0.$person = .presented(.init(name: "John", age: 0))
        }

        store.receive(.person(.begin))

        mainQueue.advance(by: 1)
        store.receive(.person(.setAge(1))) {
            $0.$person.state?.age = 1
        }

        mainQueue.advance(by: 1)
        store.receive(.person(.setAge(2))) {
            $0.$person.state?.age = 2
        }

        store.send(.died) {
            $0.$person = .cancelling(.init(name: "John", age: 2))
        }
        store.receive(.person(.cancel)) {
            $0.$person = .dismissed
        }
    }

//    func test_design() {
//
//        struct WorldState: Equatable {
//            var children: IdentifiedArrayOf<ChildState> = []
//        }
//
//        struct ChildState: Equatable, Identifiable {
//            var id: String { name }
//            var name: String
//            var age: Int
//        }
//
//        enum WorldAction: Equatable {
//            case child(id: ChildState.ID, action: ChildAction)
//        }
//
//        enum ChildAction: Equatable {
//            case birthday
//        }
//
//        let ParentReducer = Reducer<ParentState, ParentAction, ()> { state, action, environment in
//                .none
//        }
//
//    }
}
