import SwiftUI

@main
struct PresentsSampleApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                List {
                    NavigationLink {
                        ManyTimersView()
                    } label: {
                        Label("Many Timers", systemImage: "timer")
                    }
                    NavigationLink {
                        OneTimerView()
                    } label: {
                        Label("One Timer", systemImage: "timer.square")
                    }
                    NavigationLink {
                        ModalTimerIdView()
                    } label: {
                        Label("Modal Timer of ID", systemImage: "timer.square")
                    }
                    NavigationLink {
                        ModalTimerOptionView()
                    } label: {
                        Label("Modal Timer Option", systemImage: "timer.square")
                    }
                }
            }
        }
    }
}

