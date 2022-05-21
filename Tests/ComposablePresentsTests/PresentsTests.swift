import ComposableArchitecture
import ComposablePresents
import Combine
import XCTest

final class PresentsAnyTests: XCTestCase {
    func testDoesNotRequireIdentifiable() {
        struct Child: Equatable {}
        struct Parent {
            @PresentsAny var child: Child?
        }
        let parent = Parent()
        XCTAssertEqual(parent.$child, .dismissed)
    }
}

final class PresentsImmediateIntegrationTests: XCTestCase {

    struct PersonState: Equatable, Identifiable {
        var id: String { name }
        var name: String
        var age: Int
    }

    enum PersonAction: Equatable {
        case setAge(Int)
    }

    let personReducer = Reducer<PersonState, PersonAction, ()> { state, action, environment in
        switch action {
        case .setAge(let age):
            state.age = age
            return .none
        }
    }

    func testPresentsAny() {
        struct WorldState: Equatable {
            @PresentsAny var person: PersonState?
        }
        enum WorldAction: Equatable {
            case born
            case died
            case person(PersonAction)
        }
        let reducer = Reducer<WorldState, WorldAction, ()>.combine(
            personReducer.optional().pullback(
                state: \.person,
                action: /WorldAction.person,
                environment: { _ in () }
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
                .presents(
                    state: \.$person,
                    action: /WorldAction.person,
                    environment: { _ in () },
                    presenter: .immediate()
                )
        )
        let store = TestStore(
            initialState: .init(),
            reducer: reducer,
            environment: ()
        )
        store.send(.born) {
            $0.$person = .presented(.init(name: "John", age: 0))
        }
        store.send(.person(.setAge(1))) {
            $0.person?.age = 1
        }
        store.send(.died) {
            $0.$person = .dismissed
        }
    }

    func testPresentsAny_presenter_returns_action() {
        struct WorldState: Equatable {
            @PresentsAny var person: PersonState?
        }
        enum WorldAction: Equatable {
            case born
            case died
            case person(PersonAction)
        }
        let reducer = Reducer<WorldState, WorldAction, ()>.combine(
            personReducer.optional().pullback(
                state: \.person,
                action: /WorldAction.person,
                environment: { _ in () }
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
                .presents(
                    state: \.$person,
                    action: /WorldAction.person,
                    environment: { _ in () },
                    presenter: .init { _, _, _ in
                        // a nonsensical response that leaves us in a bad state
                            .action(.none)
                    }
                )
        )
        let store = TestStore(
            initialState: .init(),
            reducer: reducer,
            environment: ()
        )
        store.send(.born) {
            $0.$person = .presented(.init(name: "John", age: 0))
        }
        store.send(.person(.setAge(1))) {
            $0.person?.age = 1
        }
        store.send(.died) {
            $0.$person = .dismissing(.init(name: "John", age: 1))
        }
    }

    func testPresentsOne() {
        struct WorldState: Equatable {
            @PresentsOne var person: PersonState?
        }
        enum WorldAction: Equatable {
            case johnBorn
            case maryBorn
            case died
            case person(PersonAction)
        }
        let reducer = Reducer<WorldState, WorldAction, ()>.combine(
            personReducer.optional().pullback(
                state: \.person,
                action: /WorldAction.person,
                environment: { _ in () }
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
                .presents(
                    state: \.$person,
                    action: /WorldAction.person,
                    environment: { _ in () },
                    presenter: .immediate()
                )
        )
        let store = TestStore(
            initialState: .init(),
            reducer: reducer,
            environment: ()
        )
        store.send(.johnBorn) {
            $0.$person = .single(.presented(.init(name: "John", age: 0)))
        }
        store.send(.person(.setAge(1))) {
            $0.person?.age = 1
        }
        store.send(.maryBorn) {
            $0.$person = .single(.presented(.init(name: "Mary", age: 0)))
        }
        store.send(.person(.setAge(1))) {
            XCTAssertEqual($0.person?.name, "Mary")
            $0.person?.age = 1
        }
        store.send(.died) {
            $0.$person = .single(.dismissed)
        }
    }
}

final class PresentsLongRunningIntegrationTests: XCTestCase {

    struct PersonState: Equatable, Identifiable {
        var id: String { name }
        var name: String
        var age: Int
    }

    enum PersonAction: Equatable, LongRunningAction {
        case longRunning(LongRunningEvent)
        case setAge(Int)
    }

    struct PersonEnvironment {
        var years: () -> Effect<Int, Never>
        var mainQueue: AnySchedulerOf<DispatchQueue>
    }

    struct PersonEffect: Hashable { let id: AnyHashable }

    let personReducer = Reducer<PersonState, PersonAction, PersonEnvironment>.combine(
        Reducer { state, action, environment in
            switch action {
            case .longRunning(.start):
                return environment.years()
                    .receive(on: environment.mainQueue)
                    .eraseToEffect(PersonAction.setAge)
                    .cancellable(id: PersonEffect(id: state.id))
            case .longRunning(.stop):
                return .cancel(id: PersonEffect(id: state.id))
            case .setAge(let age):
                state.age = age
                return .none
            }
        }
    )

    func testPresentsAny() {
        struct WorldState: Equatable {
            @PresentsAny var person: PersonState?
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
        let reducer = Reducer<WorldState, WorldAction, WorldEnvironment>.combine(
            personReducer.optional().pullback(
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
                .presents(
                    state: \.$person,
                    action: /WorldAction.person,
                    environment: \.person,
                    presenter: .longRunning(personReducer)
                )
        )

        let mainQueue = DispatchQueue.test

        let store = TestStore(
            initialState: .init(),
            reducer: reducer,
            environment: .init(
                years: { yearsEffect(mainQueue) },
                mainQueue: mainQueue.eraseToAnyScheduler()
            )
        )

        store.send(.born) {
            $0.$person = .presented(.init(name: "John", age: 0))
        }
        store.receive(.person(.longRunning(.start)))

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
        store.receive(.person(.longRunning(.stop))) {
            $0.$person = .dismissed
        }
    }

    func testPresentsOne() {
        struct WorldState: Equatable {
            @PresentsOne var person: PersonState?
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
        let reducer = Reducer<WorldState, WorldAction, WorldEnvironment>.combine(
            personReducer.optional().pullback(
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
                .presents(
                    state: \.$person,
                    action: /WorldAction.person,
                    environment: \.person,
                    presenter: .longRunning(personReducer)
                )
        )

        let mainQueue = DispatchQueue.test

        let store = TestStore(
            initialState: .init(),
            reducer: reducer,
            environment: .init(
                years: { yearsEffect(mainQueue) },
                mainQueue: mainQueue.eraseToAnyScheduler()
            )
        )

        store.send(.johnBorn) {
            $0.$person = .single(.presented(.init(name: "John", age: 0)))
        }
        store.receive(.person(.longRunning(.start)))

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
        store.receive(.person(.longRunning(.stop))) {
            $0.$person = .single(.presented(.init(name: "Mary", age: 0)))
        }
        store.receive(.person(.longRunning(.start)))

        mainQueue.advance(by: 1)
        store.receive(.person(.setAge(1))) {
            $0.person?.age = 1
        }

        store.send(.died) {
            $0.$person = .single(.dismissing(.init(name: "Mary", age: 1)))
        }
        store.receive(.person(.longRunning(.stop))) {
            $0.$person = .single(.dismissed)
        }
    }

    func testPresentsOne_enum() {
        enum PeopleState: Equatable, Identifiable {
            case one(PersonState)
            case two(PersonState)
            var id: AnyHashable {
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
            personReducer.pullback(
                state: /PeopleState.one,
                action: /PeopleAction.one,
                environment: { $0 }
            ),
            personReducer.pullback(
                state: /PeopleState.two,
                action: /PeopleAction.two,
                environment: { $0 }
            )
        )
        struct WorldState: Equatable {
            @PresentsOne var people: PeopleState?
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
        let reducer = Reducer<WorldState, WorldAction, WorldEnvironment>.combine(
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
                .presents(
                    state: \.$people,
                    action: /WorldAction.people,
                    environment: \.person,
                    presenter: .init { state, action, environment in
                        switch (action, state) {
                        case (.present, .one): return .action(.one(.longRunning(.start)))
                        case (.present, .two): return .action(.two(.longRunning(.start)))
                        case (.dismiss, .one): return .action(.one(.longRunning(.stop)))
                        case (.dismiss, .two): return .action(.two(.longRunning(.stop)))
                        }
                    }
                )
        )

        let mainQueue = DispatchQueue.test

        let store = TestStore(
            initialState: .init(),
            reducer: reducer,
            environment: .init(
                years: { yearsEffect(mainQueue) },
                mainQueue: mainQueue.eraseToAnyScheduler()
            )
        )

        store.send(.firstBorn) {
            $0.$people = .single(.presented(.one(.init(name: "John", age: 0))))
        }
        store.receive(.people(.one(.longRunning(.start))))

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
        store.receive(.people(.one(.longRunning(.stop)))) {
            $0.$people = .single(.presented(.two(.init(name: "Mary", age: 0))))
        }
        store.receive(.people(.two(.longRunning(.start))))

        mainQueue.advance(by: 1)
        store.receive(.people(.two(.setAge(1)))) {
            $0.people = .two(.init(name: "Mary", age: 1))
        }

        store.send(.died) {
            $0.$people = .single(.dismissing(.two(.init(name: "Mary", age: 1))))
        }
        store.receive(.people(.two(.longRunning(.stop)))) {
            $0.$people = .single(.dismissed)
        }
    }

    func testPresentsEach() {
        struct WorldState: Equatable {
            @PresentsEach var people: IdentifiedArrayOf<PersonState> = []
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
        let reducer = Reducer<WorldState, WorldAction, WorldEnvironment>.combine(
            personReducer.forEach(
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
                .presents(
                    state: \.$people,
                    action: /WorldAction.person,
                    environment: \.person,
                    presenter: .longRunning(personReducer)
                )
        )

        let mainQueue = DispatchQueue.test

        let store = TestStore(
            initialState: .init(),
            reducer: reducer,
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
        store.receive(.person(id: "John", action: .longRunning(.start)))

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
        store.receive(.person(id: "Mary", action: .longRunning(.start)))

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
        store.receive(.person(id: "John", action: .longRunning(.stop))) {
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
        store.receive(.person(id: "Mary", action: .longRunning(.stop))) {
            $0.$people = []
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
