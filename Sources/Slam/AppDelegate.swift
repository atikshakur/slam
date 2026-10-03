import AppKit
import ApplicationServices
import SlamCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let reader = DockBadgeReader()
    private let readQueue = DispatchQueue(label: "local.slam.badge-reader", qos: .utility)
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var reading = false
    private var refreshPending = false
    private var state: BadgeState = .unavailable("Starting Slack badge monitor")
    private var setupWindow: NSWindow?
    private var setupStatus: NSTextField?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        }
        render()
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            })
        }
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
        if !UserDefaults.standard.bool(forKey: "hasShownAccessibilitySetup") {
            UserDefaults.standard.set(true, forKey: "hasShownAccessibilitySetup")
            showSetup()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    private func refresh() {
        // Coalesce reads instead of queuing stale snapshots when AX is slow.
        guard !reading else { refreshPending = true; return }
        reading = true
        readQueue.async { [weak self] in
            guard let self = self else { return }
            let result = self.reader.read()
            DispatchQueue.main.async {
                self.reading = false
                self.state = result
                self.render()
                if self.refreshPending {
                    self.refreshPending = false
                    self.refresh()
                }
            }
        }
    }

    private func render() {
        statusItem.button?.title = state.hasActivity ? "" : state.title
        statusItem.button?.image = state.hasActivity ? BadgeImage.make(title: state.title) : nil
        statusItem.button?.toolTip = "Slam — \(state.explanation). Click to open Slack; right-click for options."
        statusItem.button?.setAccessibilityLabel("Slam: \(state.explanation)")
        setupStatus?.stringValue = state.explanation
    }

    @objc private func statusClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            for (title, action) in [("Open Slack", #selector(openSlack)),
                                    ("Accessibility Setup…", #selector(showSetup)),
                                    ("Quit Slam", #selector(quit))] {
                let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            }
            // Attach only for this click, retaining the left-click open action.
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            openSlack()
        }
    }

    @objc private func openSlack() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: DockBadgeReader.slackBundleID) else {
            let alert = NSAlert()
            alert.messageText = "Slack is not installed"
            alert.informativeText = "Install the Slack desktop app to mirror its Dock badge."
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.state = .unavailable("Could not open Slack: \(error.localizedDescription)")
                    self?.render()
                } else {
                    self?.refresh()
                }
            }
        }
    }

    @objc private func showSetup() {
        if let window = setupWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 470, height: 320),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Slam — Accessibility Setup"
        window.isReleasedWhenClosed = false
        let heading = NSTextField(labelWithString: "Slack's badge, in your menu bar")
        heading.font = .systemFont(ofSize: 19, weight: .semibold)
        let explanation = NSTextField(wrappingLabelWithString:
            "Slam uses macOS Accessibility to read Slack's Dock badge. It does not read or store messages.\n\nGrant access to Slam in System Settings → Privacy & Security → Accessibility. Keep Slack running and enable its Dock badge in Slack's notification preferences.\n\n0 means clear, • means activity without a number, and ? means the badge cannot be read. Clicking the count opens Slack.")
        let status = NSTextField(wrappingLabelWithString: state.explanation)
        explanation.preferredMaxLayoutWidth = 422
        status.preferredMaxLayoutWidth = 422
        status.textColor = .secondaryLabelColor
        setupStatus = status
        let grant = NSButton(title: "Request Accessibility Access", target: self, action: #selector(requestAccess))
        let settings = NSButton(title: "Open Accessibility Settings", target: self, action: #selector(openAccessibilitySettings))
        let stack = NSStackView(views: [heading, explanation, status, grant, settings])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = window.contentView!
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24)
        ])
        // Use fitting size to accommodate wrapping text and accessibility fonts.
        window.setContentSize(NSSize(width: 470, height: max(320, stack.fittingSize.height + 48)))
        window.center()
        setupWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
