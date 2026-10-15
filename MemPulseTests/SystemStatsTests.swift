import XCTest
@testable import MemPulse

final class SystemStatsTests: XCTestCase {

    func testParseProcLinesSortsByBytesDescendingWithNamesAndPids() {
        let sample = [
            "  701   512000 /Applications/Safari.app/Contents/MacOS/Safari",
            "    1    20480 /sbin/launchd",
            "   42  1048576 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "garbage line without numbers",
            "",
        ].joined(separator: "\n")

        let procs = SystemStats.parseProcLines(sample)

        XCTAssertEqual(procs.map(\.name), ["Google Chrome", "Safari", "launchd"])
        XCTAssertEqual(procs.first?.pid, 42)
        XCTAssertEqual(procs.first?.bytes, 1_048_576 * 1024)
        XCTAssertEqual(procs.last?.pid, 1)
    }

    func testParseProcLinesGroupsHelpersUnderTheirAppWithMainPid() {
        let sample = [
            "  900   100 /Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)",
            "   42   200 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "  901   300 /Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper",
            "  701   250 /Applications/Safari.app/Contents/MacOS/Safari",
        ].joined(separator: "\n")

        let procs = SystemStats.parseProcLines(sample)

        XCTAssertEqual(procs.map(\.name), ["Google Chrome", "Safari"])
        XCTAssertEqual(procs.first?.bytes, 600 * 1024)
        XCTAssertEqual(procs.first?.pid, 42)
    }

    func testSwapUsedReturnsPlausibleValue() {
        // Sanity check that the xsw_usage struct decode is not garbage.
        XCTAssertLessThan(SystemStats.swapUsed(), UInt64(128) * 1024 * 1024 * 1024)
    }
}
