import ComposableArchitecture
import XCTest

import ComposableOptionality

final class ComposableOptionalityTests: XCTestCase {

    func test_design_single() {

        struct ChildState: Equatable {
            var name: String
            var age: Int
        }

        enum ChildAction: Equatable {
            case aged
        }

        let ChildReducer = Reducer<ChildState, ChildAction, ()>.combine(
            Reducer { state, action, environment in
                switch action {
                case .aged:
                    state.age += 1
                    return .none
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

        let ParentReducer = Reducer<ParentState, ParentAction, ()>{ state, action, environment in
            switch action {
            case .born:
                state.child = .init(name: "John", age: 0)
                return .none
            case .died:
                return .none
            case .child:
                return .none
            }
        }
            .present(
                reducer: ChildReducer,
                state: \.$child,
                action: /ParentAction.child,
                onPresent: { state, environment in
                    print("PRESENT")
                    return .none
                },
                onDismiss: { state, environment in
                    print("DISMISS")
                    return .none
                },
                environment: { _ in () }
            )

        let store = TestStore(
            initialState: .init(),
            reducer: ParentReducer,
            environment: ()
        )

        store.send(.born) {
            print($0)
            $0.$child = .presented(.init(name: "John", age: 0))
        }

        store.send(.child(.aged)) {
            $0.$child = .presented(.init(name: "John", age: 1))
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
