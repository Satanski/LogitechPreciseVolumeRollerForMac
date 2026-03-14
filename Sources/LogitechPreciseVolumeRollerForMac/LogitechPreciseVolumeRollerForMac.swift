import Foundation
import Cocoa
import CoreGraphics

@main
@MainActor
class PreciseVolumeRollerApp: NSObject, NSApplicationDelegate {
    static var delegate: PreciseVolumeRollerApp?
    var controller: VolumeRollerController?

    static func main() {
        let bundleID = "com.satanski.LogitechPreciseVolumeRoller"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        
        // If there is more than 1 instance running, signal it to show its icon and quit this one
        if runningApps.count > 1 {
            let logMsg = "⚠️ Another instance is already running. Signalling to show icon and quitting."
            print(logMsg)
            AppLogger.log(logMsg)
            
            DistributedNotificationCenter.default().postNotificationName(
                Notification.Name("\(bundleID).ShowIcon"),
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            return
        }

        let app = NSApplication.shared
        let delegate = PreciseVolumeRollerApp()
        self.delegate = delegate
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = VolumeRollerController()
        controller?.start()
    }
}

@MainActor
class VolumeRollerController {
    // Menu Bar
    private var statusItem: NSStatusItem?

    // Debounce
    private var lastEventTime: TimeInterval = 0
    private let debounceInterval: TimeInterval = 0.03

    // Direction Lock
    private var lastDirection: Bool? = nil
    private var lastDirectionTime: TimeInterval = 0
    private let directionLockWindow: TimeInterval = 0.30
    private var pendingNewDirectionCount = 0
    private let directionConfirmCount = 2
    
    // Tap reference for re-enabling
    private var eventTap: CFMachPort?

    func start() {
        setupMenuBar()
        AppLogger.log("Starting Precise Volume Roller (CGEventTap)...")

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showIconNotificationReceived),
            name: Notification.Name("com.satanski.LogitechPreciseVolumeRoller.ShowIcon"),
            object: nil
        )

        // Sprawdzamy uprawnienia Accessibility
        let trusted = AXIsProcessTrustedWithOptions(
            ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        )
        if !trusted {
            AppLogger.log("⚠️  Brak uprawnień Accessibility.")
            AppLogger.log("   Przejdź do: Ustawienia systemowe → Prywatność i bezpieczeństwo → Dostępność")
            AppLogger.log("   Usuń starą wersję, dodaj nową i uruchom ponownie.")
        } else {
            AppLogger.log("✅ Uprawnienia Accessibility OK.")
        }

        // CGEventTap przechwytuje zdarzenia systemowe (NX_SYSDEFINED = media keys)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << 14),  // NX_SYSDEFINED = 14
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let controller = Unmanaged<VolumeRollerController>.fromOpaque(refcon).takeUnretainedValue()
                return controller.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            AppLogger.log("❌ Nie udało się utworzyć CGEventTap. Sprawdź uprawnienia Accessibility.")
            return
        }

        self.eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        AppLogger.log("🎛️  Nasłuchiwanie aktywne.")
    }

    private func setupMenuBar() {
        if SettingsManager.isMenuBarIconHidden {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
            return
        }

        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        
        if let button = statusItem?.button {
            if let image = NSImage(named: "icon") ?? Bundle.main.image(forResource: "icon") ?? NSImage(contentsOfFile: "Resources/icon.png") {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            } else {
                button.image = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: "Volume Roller")
                if button.image == nil {
                    button.title = "🔊"
                }
            }
        }
        
        updateMenu()
    }

    private func updateMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Logitech Precise Volume Roller", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAtLoginManager.isEnabled ? .on : .off
        menu.addItem(launchItem)

        let hideItem = NSMenuItem(title: "Hide Menu Bar Icon", action: #selector(toggleHideIcon), keyEquivalent: "")
        hideItem.target = self
        menu.addItem(hideItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }

    @objc private func toggleHideIcon() {
        let alert = NSAlert()
        alert.messageText = "Hide Menu Bar Icon?"
        alert.informativeText = "The icon will be hidden. To show it again, launch the application again from the Applications folder."
        alert.addButton(withTitle: "Hide")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            SettingsManager.isMenuBarIconHidden = true
            setupMenuBar()
        }
    }

    @objc private func showIconNotificationReceived() {
        SettingsManager.isMenuBarIconHidden = false
        setupMenuBar()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLoginManager.isEnabled.toggle()
        updateMenu()
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Obsługa odłączenia tapa (system go wyłącza np. pod obciążeniem)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            AppLogger.log("⚠️ Event tap disabled (\(type.rawValue)). Re-enabling...")
            if let tap = self.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // NX_SYSDEFINED events: subtype 8 = media keys
        let nsEvent = NSEvent(cgEvent: event)
        guard let ns = nsEvent, ns.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }

        let data1 = ns.data1
        let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
        let keyFlags = (data1 & 0x0000FFFF)
        let keyState = ((keyFlags & 0xFF00) >> 8)  // 0xa = down, 0xb = up
        let isDown = (keyState == 0x0a)

        // keyCode: 0 = Sound Up, 1 = Sound Down, 7 = Mute, 16 = Play/Pause
        switch keyCode {
        case 0, 1:  // Volume Up / Down
            // Przepuść nasze własne zdarzenia (mają flagi Option+Shift)
            let flags = event.flags
            if flags.contains(.maskAlternate) && flags.contains(.maskShift) {
                return Unmanaged.passUnretained(event)
            }
            
            if isDown {
                let isUp = (keyCode == 0)
                if processVolumeEvent(isUp: isUp) {
                    simulateMediaKey(keyCode: keyCode, withOptionShift: true)
                    return nil  // blokujemy oryginalne zdarzenie
                }
            }
            return nil  // blokujemy zarówno key-down jak i key-up

        case 7:  // Mute
            return Unmanaged.passUnretained(event)

        case 16:  // Play/Pause
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func processVolumeEvent(isUp: Bool) -> Bool {
        let now = Date().timeIntervalSince1970

        // Debounce
        guard now - lastEventTime > debounceInterval else {
            return false
        }

        // Filtr kierunku z potwierdzeniem
        if let dir = lastDirection, now - lastDirectionTime < directionLockWindow, dir != isUp {
            pendingNewDirectionCount += 1
            if pendingNewDirectionCount < directionConfirmCount {
                return false
            } else {
                pendingNewDirectionCount = 0
            }
        } else if lastDirection != nil {
            pendingNewDirectionCount = 0
        }

        lastEventTime = now
        lastDirection = isUp
        lastDirectionTime = now

        AppLogger.log("🎚️ \(isUp ? "↑" : "↓") (1/4 notch)")
        return true
    }

    private func simulateMediaKey(keyCode: Int32, withOptionShift: Bool = false) {
        let optShiftBits: UInt = withOptionShift ? 0x80000 | 0x20000 : 0

        let eventDown = NSEvent.otherEvent(with: .systemDefined,
                                           location: NSPoint.zero,
                                           modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00 | optShiftBits),
                                           timestamp: 0,
                                           windowNumber: 0,
                                           context: nil,
                                           subtype: 8,
                                           data1: Int((keyCode << 16) | (0xa << 8)),
                                           data2: -1)
        let eventUp = NSEvent.otherEvent(with: .systemDefined,
                                         location: NSPoint.zero,
                                         modifierFlags: NSEvent.ModifierFlags(rawValue: 0xb00 | optShiftBits),
                                         timestamp: 0,
                                         windowNumber: 0,
                                         context: nil,
                                         subtype: 8,
                                         data1: Int((keyCode << 16) | (0xb << 8)),
                                         data2: -1)
        
        eventDown?.cgEvent?.post(tap: .cghidEventTap)
        eventUp?.cgEvent?.post(tap: .cghidEventTap)
    }
}

class LaunchAtLoginManager {
    static let label = "com.satanski.LogitechPreciseVolumeRoller"
    static let plistPath = ("~/Library/LaunchAgents/\(label).plist" as NSString).expandingTildeInPath
    
    static var isEnabled: Bool {
        get {
            FileManager.default.fileExists(atPath: plistPath)
        }
        set {
            if newValue {
                enable()
            } else {
                disable()
            }
        }
    }
    
    private static func enable() {
        let executablePath: String
        if Bundle.main.bundlePath.hasSuffix(".app") {
            executablePath = Bundle.main.executablePath ?? Bundle.main.bundlePath
        } else {
            executablePath = Bundle.main.bundlePath
        }
        
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        
        let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try? data?.write(to: URL(fileURLWithPath: plistPath))
        AppLogger.log("✅ LaunchAgent created at \(plistPath)")
    }
    
    private static func disable() {
        try? FileManager.default.removeItem(atPath: plistPath)
        AppLogger.log("🗑️ LaunchAgent removed.")
    }
}

class AppLogger {
    static func log(_ message: String) {
        let logPath = ("~/Library/Logs/PreciseVolumeRoller.log" as NSString).expandingTildeInPath
        let timestamp = Date().description
        let logMessage = "[\(timestamp)] \(message)\n"
        print(message)
        
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logPath) {
                if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }
    }
}
class SettingsManager {
    static let hideIconKey = "hideMenuBarIcon"
    
    static var isMenuBarIconHidden: Bool {
        get { UserDefaults.standard.bool(forKey: hideIconKey) }
        set { UserDefaults.standard.set(newValue, forKey: hideIconKey) }
    }
}
