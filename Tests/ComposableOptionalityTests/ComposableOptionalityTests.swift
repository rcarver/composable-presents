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

    func test_casePath() {
        enum PeopleState: Equatable {
            case one(PersonState)
            case two(PersonState)
        }
        enum PeopleAction: Equatable {
            case one(PersonAction)
            case two(PersonAction)
        }
        let PeopleReducer = Reducer<PeopleState, PeopleAction, PersonEnvironment>.combine(
            PersonReducer.pullback(
                state: /PeopleState.one,
                action: /PeopleAction.one,
                environment: { $0 }
            )
        )
        struct WorldState: Equatable {
            @Presented var people: PeopleState?
        }
        enum WorldAction: Equatable {
            case firstBorn
            case secondBorn
            case died
            case people(PeopleAction)
        }
        struct WorldEnvironment {
            var years: () -> Effect<Int, Never>
            var mainQueue: AnySchedulerOf<DispatchQueue>
            var person: PersonEnvironment {
                .init(years: years, mainQueue: mainQueue)
            }
        }
        let WorldReducer = Reducer<WorldState, WorldAction, WorldEnvironment>.combine(
            PeopleReducer.optional().pullback(
                state: \.people,
                action: /WorldAction.people,
                environment: \.person
            ),
            Reducer { state, action, environment in
                switch action {
                case .firstBorn:
                    state.people = .one(.init(name: "John", age: 0))
                    return .none
                case .secondBorn:
                    state.people = .two(.init(name: "Mary", age: 0))
                    return .none
                case .died:
                    state.people = nil
                    return .none
                case .people:
                    return .none
                }
            }
                .present(
                    with: .init(presenter: { state, action, environment in
                        switch (action, state) {
                        case (.present, .one): return Effect(value: .one(.begin))
                        case (.present, .two): return Effect(value: .two(.begin))
                        case (.dismiss, .one): return Effect(value: .one(.cancel))
                        case (.dismiss, .two): return Effect(value: .two(.cancel))
                        }
                    }),
                    state: \.$people,
                    action: /WorldAction.people,
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

        store.send(.firstBorn) {
            $0.$people = .presented(.one(.init(name: "John", age: 0)))
        }
        store.receive(.people(.one(.begin)))

        store.send(.died) {
            $0.$people = .cancelling(.one(.init(name: "John", age: 0)))
        }
        store.receive(.people(.one(.cancel))) {
            $0.$people = .dismissed
        }
    }
}
