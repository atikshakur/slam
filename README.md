# Slam

When the macOS Dock is hidden, Slack's notification badge disappears with it—making new activity easy to miss. I built Slam to keep that badge visible in the menu bar, so I can keep the Dock hidden and still see when Slack needs my attention.

A native Swift/AppKit menu bar app that mirrors the Slack desktop app's Dock badge. No Slack tokens, server, or workspace integration. Requires macOS 13+ and Accessibility permission.

## Download and install

Download **Slam-1.0.0.dmg** from the [latest GitHub release](https://github.com/atikshakur/slam/releases/latest). The app supports **Apple Silicon and Intel Macs running macOS 13 or later**.

1. Open the DMG and drag **Slam** into **Applications**.
2. Eject the disk image and open Slam from Applications.
3. This release is **ad-hoc signed and not notarized by Apple**. If macOS blocks it, open **System Settings → Privacy & Security**, choose **Open Anyway** for Slam, and confirm. Managed Macs may restrict this option.
4. Grant Slam **Accessibility** access using the setup window, then open Slack and enable its Dock notification badge.

To update, quit Slam before replacing the app in Applications. Because ad-hoc signing changes the app's identity on each build, you may need to remove and re-add Slam in Accessibility settings after an update.

## Build and run

Install Apple's command-line tools (`xcode-select --install`) if Swift is not already available. Full Xcode and external packages are not required.

```sh
bash scripts/build-app.sh
open dist/Slam.app
```

To build the universal app and a drag-to-Applications disk image:

```sh
bash scripts/build-dmg.sh
```

This produces `dist/Slam-1.0.0.dmg` and a SHA-256 checksum file. Generated apps and disk images are excluded from Git and uploaded as GitHub release assets.

For regular use, copy `dist/Slam.app` to `~/Applications` using Finder and launch that copy. Grant permission to the copy you actually run. Quit before replacing it on rebuild. The local ad-hoc signature identifies the exact build by its code hash. Rebuilding changes that identity and can leave an enabled Accessibility entry referring to an older build. Remove and re-add the current app in Accessibility, enable it, then relaunch. This build is not signed or notarized for distribution.

## Setup and use

1. Open Slam's first-launch setup window and click **Request Accessibility Access**.
2. In **System Settings → Privacy & Security → Accessibility**, enable **Slam**. If it isn't listed, add the `.app` with the `+` button. The monitor retries automatically.
3. Open Slack. In Slack's notification preferences enable **Show a badge on Slack's icon to indicate new activity**; also allow application icon badges in macOS notification settings where available.

Unread activity displays white text inside a red circle, widening into a rounded badge for multiple digits. A clear badge displays plain `0`, without a red background. Nonnumeric activity displays a red `•` badge. Permission or read failures display plain `?`, without red; hover over it for the reason. Left-click opens Slack. Right-click offers **Open Slack**, **Accessibility Setup**, and **Quit Slam**.

Opening Slack refreshes the badge; it never forces a local reset. Slack controls the badge meaning and aggregation across workspaces, so the value is not necessarily the total number of unread messages. Slack must have an accessible Dock item. Slam does not need notification banner permission, capture banners, or store message content. Automatic login startup is not included.

## Badge access and limitations

Slam reads the Dock's Accessibility tree, matches an application Dock item by its URL and Slack bundle identifier (`com.tinyspeck.slackmacgap`), and checks that it exposes `AXStatusLabel` before reading. This attribute is Dock implementation behavior, not a documented cross-app notification API. Unsupported attributes, failed reads, and missing Dock items display `?`, never zero. No alternative data source is substituted.

Reads run off the UI thread every two seconds, with refreshes on activation, launch, termination, and wake. Each read rediscovers the Dock process and Slack item so it recovers after restarts. Slow or unavailable Accessibility services can delay updates beyond two seconds; reads are coalesced instead of queued.

To validate the attribute in your logged-in desktop session:

```sh
dist/Slam.app/Contents/MacOS/Slam --diagnose
```

This prints the interpreted badge and whether the attribute was readable; it exits with status 1 if unavailable. A terminal-launched diagnostic may use permissions attributed to its launching terminal or agent rather than the GUI app, so a successful diagnostic does not prove the running menu bar app has permission. For normal use, inspect the app's tooltip or setup window.

Live badge capture could not be validated in the build environment: Accessibility permission was absent and no Dock or Slack process was visible. Validate on your Mac with both an empty and a nonempty badge. If either reports an unsupported attribute, this macOS configuration cannot be mirrored by the implemented reader.

The release app was built and launched successfully, its bundle and ad-hoc signature verified, and its setup window visually checked. The test runner also covers notification-only red styling. A desktop diagnostic subsequently confirmed that `AXStatusLabel` was supported and Slack's empty badge read as `0`. Live nonempty badge comparison and restart/wake checks remain unverified.

## Tests and desktop acceptance

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" swift run --cache-path "$PWD/.build/spm-cache" SlamCoreTests
```

The dependency-free Swift test runner works without XCTest or full Xcode. Tests cover numeric, empty, activity-only, malformed, and unavailable inputs. In a restricted environment that cannot launch SwiftPM's nested build sandbox, add `--disable-sandbox` to the test command and set `SLAM_DISABLE_BUILD_SANDBOX=1` for the build script. Desktop checks requiring a logged-in session:

- With Accessibility denied, see `?`; grant access and verify automatic recovery.
- Compare a numeric Slack Dock badge with the menu bar; changes should appear within two seconds under normal conditions.
- Clear Slack's badge and verify `0`; check activity-only badges show `•`.
- Click the count to activate Slack; verify remaining unread activity stays mirrored.
- Quit and reopen Slack, restart Dock, and sleep/wake; verify unavailable state and recovery without stale counts.
- Check the right-click menu and setup window in light and dark appearances.

No App Sandbox is enabled: cross-application Accessibility inspection requires running this local utility outside the sandbox.
