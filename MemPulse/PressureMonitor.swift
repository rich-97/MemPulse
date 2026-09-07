import AppKit
import SwiftUI

/// Observa la presión de memoria del sistema (mismo semáforo que Activity Monitor)
/// y refresca swap / RAM / top procesos cada 5 s.
@MainActor
final class PressureMonitor: ObservableObject {

    enum Level {
        case normal, warning, critical

        var color: NSColor {
            switch self {
            case .normal:   return .systemGreen
            case .warning:  return .systemYellow
            case .critical: return .systemRed
            }
        }
        var label: String {
            switch self {
            case .normal:   return "Normal"
            case .warning:  return "Elevada"
            case .critical: return "Crítica"
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
                self.level = .critical
            } else if event.contains(.warning) {
                self.level = .warning
            } else {
                self.level = .normal
            }
        }
        pressureSource.resume()

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
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

    /// Círculo relleno con el color del nivel. `isTemplate = false` para que la
    /// barra de menú respete el color en vez de teñirlo.
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
