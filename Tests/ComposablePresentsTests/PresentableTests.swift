import ComposableArchitecture
import ComposablePresents
import XCTest

final class PresentableIntegrationTests: XCTestCase {

    struct ChildState: Equatable, Identifiable {
        var id: String { name }
        var name: String
        var age: Int
    }

    enum ChildAction: Equatable {
        case setAge(Int)
    }

    let childReducer = Reducer<ChildState, ChildAction, Void>.combine(
        Reducer { state, action, _ in
            switch action {
            case .setAge(let age):
                state.age = age
                return .none
            }
        }
    )

    func testPresentsAny() {
        struct ParentState: Equatable {
            @PresentsAny var child: ChildState?
        }
        enum ParentAction: Equatable, PresentableAction {
            case presents(PresentsAction<ParentState>)
            case child(ChildAction)
        }
        let reducer = Reducer<ParentState, ParentAction, ()>.combine(
            childReducer.optional().pullback(
                state: \.child,
                action: /ParentAction.child,
                environment: { _ in () }
            ),
            Reducer { state, action, environment in
                switch action {
                case .presents:
                    return .none
                case .child:
                    return .none
                }
            }
                .presents(
                    state: \.$child,
                    action: /ParentAction.child,
                    environment: { _ in () },
                    presenter: .immediate()
                )
        )
        let mary = ChildState(name: "Mary", age: 3)
        let store = TestStore(
            initialState: .init(),
            reducer: reducer,
            environment: ()
        )
        store.send(.presents(.set(\.$child, value: mary))) {
            $0.$child = .presented(mary)
        }
        store.send(.presents(.dismiss(\.$child))) {
            $0.$child = .dismissed
        }
    }

    func testPresentsOne() {
        struct ParentState: Equatable {
            @PresentsOne var child: ChildState?
        }
        enum ParentAction: Equatable, PresentableAction {
            case presents(PresentsAction<ParentState>)
            case child(ChildAction)
        }
        let reducer = Reducer<ParentState, ParentAction, ()>.combine(
            childReducer.optional().pullback(
                state: \.child,
                action: /ParentAction.child,
                environment: { _ in () }
            ),
            Reducer { state, action, environment in
                switch action {
                case .presents:
                    return .none
               case .child:
                    return .none
                }
            }
                .presents(
                    state: \.$child,
                    action: /ParentAction.child,
                    environment: { _ in () },
                    presenter: .immediate()
                )
        )
        let mary = ChildState(name: "Mary", age: 3)
        let store = TestStore(
            initialState: .init(),
            reducer: reducer,
            environment: ()
        )
        store.send(.presents(.set(\.$child, value: mary))) {
            $0.$child = .presented(mary)
        }
        store.send(.presents(.dismiss(\.$child))) {
            $0.$child = .dismissed
        }
    }
}
