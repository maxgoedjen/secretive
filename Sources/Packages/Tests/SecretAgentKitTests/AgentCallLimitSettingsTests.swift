import Foundation
import Testing
import Common

@Suite struct AgentCallLimitSettingsTests {

    @Test func trackerStopsAfterConfiguredSignRequests() throws {
        let url = AgentCallLimitSettings.fileURL
        let backup = try? Data(contentsOf: url)
        defer {
            if let backup {
                try? backup.write(to: url)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let state = AgentCallLimitSettings.State(limit: 2, remaining: 2)
        let data = try JSONEncoder().encode(state)
        try data.write(to: url)

        let tracker = AgentCallLimitTracker(state: state)
        #expect(tracker.recordSignRequest() == false)
        #expect(tracker.recordSignRequest() == true)
        #expect(AgentCallLimitSettings.load().remaining == 0)
    }

    @Test func unlimitedTrackerNeverStops() {
        let tracker = AgentCallLimitTracker(state: .init(limit: 0, remaining: nil))
        #expect(tracker.recordSignRequest() == false)
        #expect(tracker.recordSignRequest() == false)
    }

    @Test func exhaustedWhenRemainingIsZero() {
        #expect(AgentCallLimitSettings.isExhausted(.init(limit: 3, remaining: 0)))
        #expect(!AgentCallLimitSettings.isExhausted(.init(limit: 3, remaining: 1)))
        #expect(!AgentCallLimitSettings.isExhausted(.init(limit: 0, remaining: nil)))
    }

}
