import SwiftUI

@main
struct PresentsSampleApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ManyTimersView()
                    .tabItem {
                        Label("Many", systemImage: "timer")
                    }
                OneTimerView()
                    .tabItem {
                        Label("One", systemImage: "timer.square")
                    }
            }
        }
    }
}

