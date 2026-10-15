import AppKit
import SwiftUI
import UserNotifications

/// Watches system memory pressure (same traffic light as Activity Monitor)
/// and refreshes swap / RAM / top processes every 5 s.
@MainActor
final class PressureMonitor: ObservableObject {

    enum Level {
        case normal, warning, critical

        /// Values of `kern.memorystatus_vm_pressure_level`.
        init(kernel: Int32) {
            switch kernel {
            case 4:  self = .critical
            case 2:  self = .warning
            default: self = .normal
            }
        }

        var color: NSColor {
            switch self {
            case .normal:   return .systemGreen
            case .warning:  return .systemYellow
            case .critical: return .systemRed
            }
        }
        var label: String {
            switch self {
            case .normal:   return String(localized: "Normal")
            case .warning:  return String(localized: "Elevated")
            case .critical: return String(localized: "Critical")
            }
        }
    }

    @Published private(set) var level: Level = .normal
    @Published private(set) var swapUsed: UInt64 = 0
    @Published private(set) var memory: (used: UInt64, compressed: UInt64, free: UInt64) = (0, 0, 0)
    @Published private(set) var topProcesses: [ProcInfo] = []

    private let pressureSource: DispatchSourceMemoryPressure
    private var timer: Timer?

    init() {
        pressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical], queue: .main)

        pressureSource.setEventHandler { [weak self] in
            guard let self else { return }
            let event = self.pressureSource.data
            if event.contains(.critical) {
                self.setLevel(.critical)
            } else if event.contains(.warning) {
                self.setLevel(.warning)
            } else {
                self.setLevel(.normal)
            }
        }
        pressureSource.resume()
        level = Level(kernel: SystemStats.pressureLevel())

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func setLevel(_ new: Level) {
        if new == .critical && level != .critical { notifyCritical() }
        level = new
    }

    private func notifyCritical() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Critical memory pressure")
        content.body = String(localized: "Your Mac is swapping heavily. Quit an app to free memory.")
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "critical", content: content, trigger: nil))
    }

    func refresh() {
        Task.detached(priority: .utility) {
            let swap = SystemStats.swapUsed()
            let mem = SystemStats.memoryStats()
            let procs = SystemStats.topProcesses()
            await MainActor.run {
                self.swapUsed = swap
                self.memory = mem
                self.topProcesses = procs
            }
        }
    }

    /// Filled circle in the level's color. `isTemplate = false` so the menu bar
    /// keeps the color instead of tinting it.
    var dotImage: NSImage {
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        level.color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 10, height: 10)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
