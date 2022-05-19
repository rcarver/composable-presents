import ComposableArchitecture
import Combine
import XCTest

import ComposableOptionality

final class IntegrationTests: XCTestCase {

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

    func testPresentedOptional() {
        struct WorldState: Equatable {
            @PresentedOptional var person: PersonState?
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
                years: { yearsEffect(mainQueue) },
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
            $0.$person = .dismissing(.init(name: "John", age: 2))
        }
        store.receive(.person(.cancel)) {
            $0.$person = .dismissed
        }
    }
}

final class IdentifiableIntegrationTests: XCTestCase {

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

    func testPresentedID() {
        struct WorldState: Equatable {
            @PresentedID var person: PersonState?
        }
        enum WorldAction: Equatable {
            case johnBorn
            case maryBorn
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
                case .johnBorn:
                    state.person = .init(name: "John", age: 0)
                    return .none
                case .maryBorn:
                    state.person = .init(name: "Mary", age: 0)
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
                years: { yearsEffect(mainQueue) },
                mainQueue: mainQueue.eraseToAnyScheduler()
            )
        )

        store.send(.johnBorn) {
            $0.$person = .single(.presented(.init(name: "John", age: 0)))
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

        store.send(.maryBorn) {
            $0.$person = .transition(
                from: .dismissing(.init(name: "John", age: 2)),
                to: .init(name: "Mary", age: 0)
            )
        }
        store.receive(.person(.cancel)) {
            $0.$person = .single(.presented(.init(name: "Mary", age: 0)))
        }
        store.receive(.person(.begin))

        mainQueue.advance(by: 1)
        store.receive(.person(.setAge(1))) {
            $0.person?.age = 1
        }

        store.send(.died) {
            $0.$person = .single(.dismissing(.init(name: "Mary", age: 1)))
        }
        store.receive(.person(.cancel)) {
            $0.$person = .single(.dismissed)
        }
    }

    func testPresentedEach() {
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
                .present(
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
                years: { yearsEffect(mainQueue) },
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
                .dismissing(.init(name: "John", age: 2)),
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
                .dismissing(.init(name: "Mary", age: 2))
            ]
        }
        store.receive(.person(id: "Mary", action: .cancel)) {
            $0.$people = []
        }
    }

    func testPresentedCase() {
        enum PeopleState: Equatable, CaseIdentifiable {
            case one(PersonState)
            case two(PersonState)
            var caseIdentity: AnyHashable {
                switch self {
                case .one(let value): return value.id
                case .two(let value): return value.id
                }
            }
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
            ),
            PersonReducer.pullback(
                state: /PeopleState.two,
                action: /PeopleAction.two,
                environment: { $0 }
            )
        )
        struct WorldState: Equatable {
            @PresentedCase var people: PeopleState?
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
                years: { yearsEffect(mainQueue) },
                mainQueue: mainQueue.eraseToAnyScheduler()
            )
        )

        store.send(.firstBorn) {
            $0.$people = .single(.presented(.one(.init(name: "John", age: 0))))
        }
        store.receive(.people(.one(.begin)))

        mainQueue.advance(by: 1)
        store.receive(.people(.one(.setAge(1)))) {
            $0.people = .one(.init(name: "John", age: 1))
        }

        store.send(.secondBorn) {
            $0.$people = .transition(
                from: .dismissing(.one(.init(name: "John", age: 1))),
                to: .two(.init(name: "Mary", age: 0))
            )
        }
        store.receive(.people(.one(.cancel))) {
            $0.$people = .single(.presented(.two(.init(name: "Mary", age: 0))))
        }
        store.receive(.people(.two(.begin)))

        mainQueue.advance(by: 1)
        store.receive(.people(.two(.setAge(1)))) {
            $0.people = .two(.init(name: "Mary", age: 1))
        }

        store.send(.died) {
            $0.$people = .single(.dismissing(.two(.init(name: "Mary", age: 1))))
        }
        store.receive(.people(.two(.cancel))) {
            $0.$people = .single(.dismissed)
        }
    }
}

fileprivate func yearsEffect<S: Scheduler>(_ mainQueue: S) -> Effect<Int, Never> {
    (1..<10).publisher
        .flatMap(maxPublishers: .max(1)) {
            Just($0).delay(for: 1, scheduler: mainQueue)
        }
        .eraseToEffect()
}
