import AppKit
import ApplicationServices
import SlamCore

protocol BadgeReading {
    func read() -> BadgeState
}

/// Called exclusively on the monitor's serial queue. Never modifies Dock or Slack.
final class DockBadgeReader: BadgeReading {
    static let slackBundleID = "com.tinyspeck.slackmacgap"
    private let statusAttribute = "AXStatusLabel" as CFString
    private(set) var diagnostic = "Not inspected"

    func read() -> BadgeState {
        guard AXIsProcessTrusted() else {
            return unavailable("Accessibility access is required. Right-click for Accessibility Setup.")
        }
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return unavailable("Dock is not available; waiting for it to start")
        }
        // Rediscover the process and element on every read, so Dock restarts and
        // Slack Dock item replacements cannot leave us with stale AX references.
        let root = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.2)
        guard let item = findSlack(in: root) else {
            return unavailable("Slack's Dock item could not be read. Open Slack and check Accessibility access.")
        }
        AXUIElementSetMessagingTimeout(item, 0.2)

        // AXStatusLabel is a Dock-exposed attribute, not a documented constant.
        // Verify its presence at runtime rather than treating unsupported as empty.
        var names: CFArray?
        let namesResult = AXUIElementCopyAttributeNames(item, &names)
        guard namesResult == .success, let attributes = names as? [String] else {
            return unavailable("Could not inspect Slack's Dock attributes (AX \(namesResult.rawValue))")
        }
        guard attributes.contains(statusAttribute as String) else {
            return unavailable("This Dock item does not expose AXStatusLabel; badge mirroring is unavailable")
        }

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(item, statusAttribute, &value)
        if result == .noValue || (result == .success && value == nil) {
            diagnostic = "AXStatusLabel supported; empty badge"
            return BadgeRead.empty.state
        }
        guard result == .success else {
            return unavailable("Slack's Dock badge read failed (AX \(result.rawValue))")
        }
        guard let label = value as? String else {
            return unavailable("Slack's Dock badge has an unexpected value type")
        }
        let state = BadgeRead.label(label).state
        diagnostic = "AXStatusLabel supported; \(state.explanation)"
        return state
    }

    private func unavailable(_ reason: String) -> BadgeState {
        diagnostic = reason
        return .unavailable(reason)
    }

    private func findSlack(in root: AXUIElement) -> AXUIElement? {
        var pending: [(AXUIElement, Int)] = [(root, 0)]
        var visited = 0
        while !pending.isEmpty, visited < 256 {
            let (element, depth) = pending.removeFirst()
            visited += 1
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &value) == .success,
               value as? String == kAXApplicationDockItemSubrole {
                var rawURL: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &rawURL) == .success,
                   let url = rawURL as? URL,
                   Bundle(url: url)?.bundleIdentifier == Self.slackBundleID {
                    return element
                }
            }
            guard depth < 4 else { continue }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
               let elements = children as? [AXUIElement] {
                pending.append(contentsOf: elements.prefix(256 - visited).map { ($0, depth + 1) })
            }
        }
        return nil
    }
}
