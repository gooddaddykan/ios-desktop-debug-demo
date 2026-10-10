import SwiftUI

@main
struct DesktopDebugDemoApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "desktopcomputer").font(.system(size: 64)).foregroundStyle(.blue)
            Text("iOS Desktop Debug Demo").font(.title2.bold())
            Text("A public demo running on an iOS simulator.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Text("\(count)").font(.system(size: 64, weight: .semibold, design: .rounded))
                .accessibilityIdentifier("counter")
            Button("Add one") { count += 1 }.buttonStyle(.borderedProminent)
                .accessibilityIdentifier("increment")
            Button("Reset") { count = 0 }.buttonStyle(.bordered)
        }
        .padding(28)
    }
}
