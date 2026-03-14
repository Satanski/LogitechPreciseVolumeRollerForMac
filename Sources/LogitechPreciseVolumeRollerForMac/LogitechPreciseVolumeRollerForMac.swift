import Foundation
import Cocoa
import CoreGraphics

@main
@MainActor
class PreciseVolumeRollerApp: NSObject, NSApplicationDelegate {
    static var delegate: PreciseVolumeRollerApp?
    var controller: VolumeRollerController?
    var settingsWindowController: SettingsWindowController?

    static func main() {
        AppLogger.log("--- App Starting ---")
        let bundleID = "com.satanski.LogitechPreciseVolumeRoller"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        
        AppLogger.log("Running instances found: \(runningApps.count)")
        let isBackground = CommandLine.arguments.contains("--background")
        
        // If there is more than 1 instance running, signal it to show its window and quit this one
        if runningApps.count > 1 {
            let logMsg = "⚠️ Another instance is already running. Signalling to show window and quitting."
            AppLogger.log(logMsg)
            
            DistributedNotificationCenter.default().postNotificationName(
                Notification.Name("\(bundleID).ShowSettings"),
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
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showSettingsNotificationReceived),
            name: Notification.Name("com.satanski.LogitechPreciseVolumeRoller.ShowSettings"),
            object: nil
        )

        // Decide whether to show window on launch
        let isBackground = CommandLine.arguments.contains("--background")
        if !isBackground {
            showSettingsWindow()
        }
    }
    
    @objc func showSettingsNotificationReceived() {
        showSettingsWindow()
    }
    
    func showSettingsWindow() {
        AppLogger.log("Attempting to show settings window...")
        if settingsWindowController == nil {
            AppLogger.log("Creating SettingsWindowController...")
            settingsWindowController = SettingsWindowController()
        }
        
        // Ensure app can take focus to show window
        AppLogger.log("Setting activation policy to .regular")
        NSApp.setActivationPolicy(.regular)
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        let success = NSApp.activate(ignoringOtherApps: true)
        AppLogger.log("App activation successful: \(success)")
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
            selector: #selector(refreshMenuBarNotification),
            name: Notification.Name("com.satanski.LogitechPreciseVolumeRoller.RefreshMenuBar"),
            object: nil
        )

        // Sprawdzamy uprawnienia Accessibility
        let trusted = AXIsProcessTrustedWithOptions(
            ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        )
        if !trusted {
            AppLogger.log("⚠️ Brak uprawnień Accessibility.")
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

        AppLogger.log("🎛️ Nasłuchiwanie aktywne.")
    }

    @objc private func refreshMenuBarNotification() {
        setupMenuBar()
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
        
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }

    @objc private func openSettings() {
        if let appDelegate = NSApp.delegate as? PreciseVolumeRollerApp {
            appDelegate.showSettingsWindow()
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            AppLogger.log("⚠️ Event tap disabled (\(type.rawValue)). Re-enabling...")
            if let tap = self.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let nsEvent = NSEvent(cgEvent: event)
        guard let ns = nsEvent, ns.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }

        let data1 = ns.data1
        let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
        let keyFlags = (data1 & 0x0000FFFF)
        let keyState = ((keyFlags & 0xFF00) >> 8)
        let isDown = (keyState == 0x0a)

        switch keyCode {
        case 0, 1:
            let flags = event.flags
            if flags.contains(.maskAlternate) && flags.contains(.maskShift) {
                return Unmanaged.passUnretained(event)
            }
            
            if isDown {
                let isUp = (keyCode == 0)
                if processVolumeEvent(isUp: isUp) {
                    simulateMediaKey(keyCode: keyCode, withOptionShift: true)
                    return nil
                }
            }
            return nil

        case 7, 16:
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func processVolumeEvent(isUp: Bool) -> Bool {
        let now = Date().timeIntervalSince1970
        guard now - lastEventTime > debounceInterval else { return false }

        if let dir = lastDirection, now - lastDirectionTime < directionLockWindow, dir != isUp {
            pendingNewDirectionCount += 1
            if pendingNewDirectionCount < directionConfirmCount { return false }
            pendingNewDirectionCount = 0
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

class SettingsWindowController: NSWindowController {
    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: 320, height: 180)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
        
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.delegate = self
        
        let contentView = NSView(frame: contentRect)
        window.contentView = contentView
        
        let titleLabel = NSTextField(labelWithString: "Logitech Precise Volume Roller")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 14)
        titleLabel.frame = NSRect(x: 20, y: 130, width: 280, height: 20)
        contentView.addSubview(titleLabel)
        
        let iconCheckbox = NSButton(checkboxWithTitle: "Show icon in menu bar", target: nil, action: #selector(toggleIcon))
        iconCheckbox.frame = NSRect(x: 20, y: 90, width: 280, height: 20)
        iconCheckbox.state = SettingsManager.isMenuBarIconHidden ? .off : .on
        iconCheckbox.target = self
        contentView.addSubview(iconCheckbox)
        
        let launchCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: #selector(toggleLaunch))
        launchCheckbox.frame = NSRect(x: 20, y: 60, width: 280, height: 20)
        launchCheckbox.state = LaunchAtLoginManager.isEnabled ? .on : .off
        launchCheckbox.target = self
        contentView.addSubview(launchCheckbox)
        
        let infoLabel = NSTextField(labelWithString: "The app runs in the background to improve volume control.")
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.frame = NSRect(x: 20, y: 20, width: 280, height: 30)
        contentView.addSubview(infoLabel)
    }
    
    @objc func toggleIcon(_ sender: NSButton) {
        SettingsManager.isMenuBarIconHidden = (sender.state == .off)
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.satanski.LogitechPreciseVolumeRoller.RefreshMenuBar"),
            object: nil
        )
    }
    
    @objc func toggleLaunch(_ sender: NSButton) {
        LaunchAtLoginManager.isEnabled = (sender.state == .on)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        AppLogger.log("Settings window closing, switching to .accessory")
        NSApp.setActivationPolicy(.accessory)
    }
}

class LaunchAtLoginManager {
    static let label = "com.satanski.LogitechPreciseVolumeRoller"
    static let plistPath = ("~/Library/LaunchAgents/\(label).plist" as NSString).expandingTildeInPath
    
    static var isEnabled: Bool {
        get { FileManager.default.fileExists(atPath: plistPath) }
        set { newValue ? enable() : disable() }
    }
    
    private static func enable() {
        let executablePath = Bundle.main.bundlePath.hasSuffix(".app") 
            ? (Bundle.main.executablePath ?? Bundle.main.bundlePath)
            : Bundle.main.bundlePath
        
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath, "--background"],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        
        let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try? data?.write(to: URL(fileURLWithPath: plistPath))
    }
    
    private static func disable() {
        try? FileManager.default.removeItem(atPath: plistPath)
    }
}

class AppLogger {
    static func log(_ message: String) {
        let logPath = ("~/Library/Logs/PreciseVolumeRoller.log" as NSString).expandingTildeInPath
        let logMessage = "[\(Date().description)] \(message)\n"
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
