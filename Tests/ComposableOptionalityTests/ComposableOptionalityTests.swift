import ComposableArchitecture
import Combine
import XCTest

import ComposableOptionality

final class ComposableOptionalityTests: XCTestCase {

    struct PersonState: Equatable, Identifiable {
        var id: String { name }
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

    struct PersonEffect: Hashable { let id: AnyHashable }

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
                    .cancellable(id: PersonEffect(id: state.id))
            case .cancel:
                return .cancel(id: PersonEffect(id: state.id))
            }
        }
    )

    func yearsEffect<S: Scheduler>(_ mainQueue: S) -> Effect<Int, Never> {
        (1..<10).publisher
            .flatMap(maxPublishers: .max(1)) {
                Just($0).delay(for: 1, scheduler: mainQueue)
            }
            .eraseToEffect()
    }

    func test_optional() {
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
                years: { self.yearsEffect(mainQueue) },
                mainQueue: mainQueue.eraseToAnyScheduler()
            )
        )

        store.send(.born) {
            $0.$person = .presented(.init(name: "John", age: 0))
        }
        store.receive(.person(.begin))

        mainQueue.advance(by: 1)
        store.receive(.person(.setAge(1))) {
            $0.person?.age = 1
        }

        mainQueue.advance(by: 1)
        store.receive(.person(.setAge(2))) {
            $0.person?.age = 2
        }

        store.send(.died) {
            $0.$person = .cancelling(.init(name: "John", age: 2))
        }
        store.receive(.person(.cancel)) {
            $0.$person = .dismissed
        }
    }

    func test_forEach() {
        struct WorldState: Equatable {
            @PresentedEach var people: IdentifiedArrayOf<PersonState> = []
        }
        enum WorldAction: Equatable {
            case born(PersonState.ID)
            case died(PersonState.ID)
            case person(id: PersonState.ID, action: PersonAction)
        }
        struct WorldEnvironment {
            var years: () -> Effect<Int, Never>
            var mainQueue: AnySchedulerOf<DispatchQueue>
            var person: PersonEnvironment {
                .init(years: years, mainQueue: mainQueue)
            }
        }
        let WorldReducer = Reducer<WorldState, WorldAction, WorldEnvironment>.combine(
            PersonReducer.forEach(
                state: \.people,
                action: /WorldAction.person,
                environment: \.person
            ),
            Reducer { state, action, environment in
                switch action {
                case .born(let name):
                    state.people.append(.init(name: name, age: 0))
                    return .none
                case .died(let name):
                    state.people.remove(id: name)
                    return .none
                case .person:
                    return .none
                }
            }
                .presentEach(
                    with: .longRunning(PersonReducer),
                    state: \.$people,
                    action: /WorldAction.person,
                    environment: \.person
                )
        )

        let mainQueue = DispatchQueue.test

        let store = TestStore(
            initialState: .init(),
            reducer: WorldReducer,
            environment: .init(
                years: { self.yearsEffect(mainQueue) },
                mainQueue: mainQueue.eraseToAnyScheduler()
            )
        )

        store.send(.born("John")) {
            $0.$people = [
                .presented(.init(name: "John", age: 0))
            ]
        }
        store.receive(.person(id: "John", action: .begin))

        mainQueue.advance(by: 1)
        store.receive(.person(id: "John", action: .setAge(1))) {
            $0.people[id: "John"]?.age = 1
        }

        store.send(.born("Mary")) {
            $0.$people = [
                .presented(.init(name: "John", age: 1)),
                .presented(.init(name: "Mary", age: 0))
            ]
        }
        store.receive(.person(id: "Mary", action: .begin))

        mainQueue.advance(by: 1)
        store.receive(.person(id: "John", action: .setAge(2))) {
            $0.people[id: "John"]?.age = 2
        }
        store.receive(.person(id: "Mary", action: .setAge(1))) {
            $0.people[id: "Mary"]?.age = 1
        }

        store.send(.died("John")) {
            $0.$people = [
                .cancelling(.init(name: "John", age: 2)),
                .presented(.init(name: "Mary", age: 1))
            ]
        }
        store.receive(.person(id: "John", action: .cancel)) {
            $0.$people = [
                .presented(.init(name: "Mary", age: 1))
            ]
        }

        mainQueue.advance(by: 1)
        store.receive(.person(id: "Mary", action: .setAge(2))) {
            $0.people[id: "Mary"]?.age = 2
        }

        store.send(.died("Mary")) {
            $0.$people = [
                .cancelling(.init(name: "Mary", age: 2))
            ]
        }
        store.receive(.person(id: "Mary", action: .cancel)) {
            $0.$people = []
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
