import Foundation
import Darwin

struct ProcInfo: Identifiable, Equatable {
    let pid: Int32
    let name: String
    let bytes: UInt64
    var id: Int32 { pid }
}

enum SystemStats {

    /// Swap usada por el sistema, en bytes. `sysctl vm.swapusage`.
    static func swapUsed() -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return 0 }
        return usage.xsu_used
    }

    /// Memoria física, en bytes. `host_statistics64` / `HOST_VM_INFO64`.
    /// No cubierto por tests: pegamento de Mach. Se contrasta a mano con Activity Monitor.
    static func memoryStats() -> (used: UInt64, compressed: UInt64, free: UInt64) {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let kr = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return (0, 0, 0) }
        let page = UInt64(getpagesize())
        let compressed = UInt64(stats.compressor_page_count) * page
        let used = UInt64(stats.active_count) * page
            + UInt64(stats.wire_count) * page
            + compressed
        return (used: used, compressed: compressed, free: UInt64(stats.free_count) * page)
    }

    /// Procesos que más memoria residente usan, de mayor a menor.
    static func topProcesses(limit: Int = 5) -> [ProcInfo] {
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-axo", "pid=,rss=,comm="]
        let pipe = Pipe()
        ps.standardOutput = pipe
        ps.standardError = FileHandle.nullDevice
        guard (try? ps.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        ps.waitUntilExit()
        return parseProcLines(String(decoding: data, as: UTF8.self), limit: limit)
    }

    /// Parsea la salida de `ps -axo pid=,rss=,comm=`.
    /// `rss` viene en KB; `comm` es una ruta que puede contener espacios.
    static func parseProcLines(_ output: String, limit: Int = 5) -> [ProcInfo] {
        var procs: [ProcInfo] = []
        for rawLine in output.split(separator: "\n") {
            let line = String(rawLine)
            let scanner = Scanner(string: line)
            guard let pid = scanner.scanInt(),
                  let rssKB = scanner.scanUInt64() else { continue }
            let path = String(line[scanner.currentIndex...]).trimmingCharacters(in: .whitespaces)
            guard !path.isEmpty else { continue }
            let name = path.split(separator: "/").last.map(String.init) ?? path
            procs.append(ProcInfo(pid: Int32(truncatingIfNeeded: pid), name: name, bytes: rssKB * 1024))
        }
        return Array(procs.sorted { $0.bytes > $1.bytes }.prefix(limit))
    }
}
