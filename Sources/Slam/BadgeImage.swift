import AppKit

enum BadgeImage {
    static func make(title: String) -> NSImage {
        let label = NSAttributedString(string: title, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white
        ])
        let textSize = label.size()
        let size = NSSize(width: max(20, ceil(textSize.width) + 8), height: 20)
        let image = NSImage(size: size, flipped: false) { bounds in
            NSColor(srgbRed: 1, green: 0.23, blue: 0.19, alpha: 1).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()
            label.draw(at: NSPoint(x: (size.width - textSize.width) / 2,
                                   y: (size.height - textSize.height) / 2))
            return true
        }
        // Preserve the red fill in both light and dark menu bars.
        image.isTemplate = false
        return image
    }
}
