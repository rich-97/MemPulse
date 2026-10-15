import AppKit
import ServiceManagement
import SwiftUI

@main
struct MemPulseApp: App {
    @StateObject private var monitor = PressureMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(monitor: monitor)
        } label: {
            Image(nsImage: monitor.dotImage)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuContent: View {
    @ObservedObject var monitor: PressureMonitor
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(monitor.level.color))
                    .frame(width: 10, height: 10)
                Text("Memory pressure: \(monitor.level.label)")
                    .font(.headline)
            }

            Text("Swap used: \(bytes(monitor.swapUsed))")
            Text("RAM used: \(bytes(monitor.memory.used))   ·   compressed: \(bytes(monitor.memory.compressed))")
                .foregroundStyle(.secondary)

            Divider()

            Text("Top memory apps")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if monitor.topProcesses.isEmpty {
                Text("Measuring…").foregroundStyle(.tertiary)
            }
            ForEach(monitor.topProcesses) { proc in
                HStack {
                    Text(proc.name).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text(bytes(proc.bytes))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    if let app = NSRunningApplication(processIdentifier: proc.pid),
                       app.activationPolicy == .regular {
                        Button("Quit") {
                            NSEvent.modifierFlags.contains(.option) ? app.forceTerminate() : app.terminate()
                        }
                            .buttonStyle(.borderless)
                            .help("Hold ⌥ to force quit")
                            .controlSize(.small)
                    }
                }
            }

            Divider()

            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        on ? try SMAppService.mainApp.register()
                           : try SMAppService.mainApp.unregister()
                    } catch {
                        launchAtLogin = (SMAppService.mainApp.status == .enabled)
                    }
                }

            Button("Quit MemPulse") { NSApp.terminate(nil) }
        }
        .padding(12)
        .frame(width: 300)
    }

    private func bytes(_ n: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .memory)
    }
}
