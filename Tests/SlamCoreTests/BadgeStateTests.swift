import Foundation
import SlamCore

/// A dependency-free runner so tests work with command-line tools alone.
@main
struct BadgeStateTests {
    private static var assertions = 0
    private static var failures = 0

    private static func check<T: Equatable>(_ actual: T, _ expected: T,
                                            file: StaticString = #filePath, line: UInt = #line) {
        assertions += 1
        if actual != expected {
            failures += 1
            fputs("\(file):\(line): expected \(expected), received \(actual)\n", stderr)
        }
    }

    static func main() {
        check(BadgeState.clear.hasActivity, false)
        check(BadgeState.numeric("0").hasActivity, false)
        check(BadgeState.numeric("000").hasActivity, false)
        check(BadgeState.numeric("1").hasActivity, true)
        check(BadgeState.numeric("42").hasActivity, true)
        check(BadgeState.activityOnly.hasActivity, true)
        check(BadgeState.unavailable("Permission denied").hasActivity, false)
        for label in ["0", "1", "42", "1000", "001"] {
            check(BadgeRead.label(label).state, .numeric(label))
            check(BadgeRead.label(label).state.title, label)
        }
        check(BadgeRead.label(" 42 ").state, .numeric("42"))
        check(BadgeRead.empty.state, .clear)
        check(BadgeRead.label("").state, .clear)
        check(BadgeRead.label("   ").state.title, "0")

        for label in ["•", "●", "!", "99+", "New activity"] {
            check(BadgeRead.label(label).state, .activityOnly)
            check(BadgeRead.label(label).state.title, "•")
        }
        for label in ["1\n2", "\u{0}", String(repeating: "1", count: 65)] {
            let state = BadgeRead.label(label).state
            check(state.title, "?")
            if case .unavailable = state { check(true, true) }
            else { check(false, true) }
        }
        for reason in ["Permission denied", "AXStatusLabel unsupported", "Dock unavailable", "AX read failed"] {
            let state = BadgeRead.unavailable(reason).state
            check(state, .unavailable(reason))
            check(state.title, "?")
            check(state.explanation, reason)
        }
        print("\(assertions) badge assertions, \(failures) failures")
        exit(failures == 0 ? 0 : 1)
    }
}
