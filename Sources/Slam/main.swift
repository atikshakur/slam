import AppKit

if CommandLine.arguments.contains("--diagnose") {
    let reader = DockBadgeReader()
    let state = reader.read()
    print("Menu bar: \(state.title)")
    print(reader.diagnostic)
    if case .unavailable = state { exit(1) }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
