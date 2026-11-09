import Testing

@testable import Memory_Mapping

extension Memory.Test.Performance {
    @Test func `peak tracker reports the final allocation when the operation never samples`() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
            let (storage, peak) = Memory.Allocation.Peak.Tracker.track { _ in
                Array(repeating: UInt8(1), count: 1_048_576)
            }
            #expect(storage.count == 1_048_576)
            #expect(peak.bytesAllocated > 0)
            #expect(peak.allocations > 0)
        #endif
    }
}
