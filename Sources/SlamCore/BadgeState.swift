import Foundation

public enum BadgeState: Equatable {
    case numeric(String)
    case activityOnly
    case clear
    case unavailable(String)

    public var hasActivity: Bool {
        switch self {
        case .numeric(let count): return count.contains { ($0.wholeNumberValue ?? 0) > 0 }
        case .activityOnly: return true
        case .clear, .unavailable: return false
        }
    }

    public var title: String {
        switch self {
        case .numeric(let count): return count
        case .activityOnly: return "•"
        case .clear: return "0"
        case .unavailable: return "?"
        }
    }

    public var explanation: String {
        switch self {
        case .numeric(let count): return "Slack Dock badge: \(count)"
        case .activityOnly: return "Slack reports activity without a numeric count"
        case .clear: return "Slack's Dock badge is clear"
        case .unavailable(let reason): return reason
        }
    }
}

/// Keep successful empty reads distinct from failed or unsupported reads.
public enum BadgeRead {
    case label(String)
    case empty
    case unavailable(String)

    public var state: BadgeState {
        switch self {
        case .empty: return .clear
        case .unavailable(let reason): return .unavailable(reason)
        case .label(let raw):
            guard raw.count <= 64,
                  !raw.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                return .unavailable("Slack returned a malformed Dock badge")
            }
            let label = raw.trimmingCharacters(in: .whitespaces)
            guard !label.isEmpty else { return .clear }
            if label.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) }) {
                return .numeric(label)
            }
            return .activityOnly
        }
    }
}
