import Synchronization

extension Memory.Allocation.Peak {

    public final class Tracker: Sendable {
        private let state: Mutex<State>
        private let baseline: Memory.Allocation.Statistics

        public init() {
            self.baseline = Memory.Allocation.Statistics.capture()
            self.state = Mutex(State())
        }
    }
}

extension Memory.Allocation.Peak.Tracker {
    private struct State: Sendable {
        var peakBytes: Int = 0
        var peakAllocations: Int = 0
        var samples: [Memory.Allocation.Statistics] = []
    }
}

extension Memory.Allocation.Peak.Tracker {

    public func sample() {
        let current = Memory.Allocation.Statistics.capture()
        let delta = Memory.Allocation.Statistics.delta(from: baseline, to: current)

        state.withLock { state in
            state.samples.append(delta)
            state.peakBytes = max(state.peakBytes, delta.bytes.allocated)
            state.peakAllocations = max(state.peakAllocations, delta.allocations)
        }
    }

    public var samples: [Memory.Allocation.Statistics] {
        state.withLock { $0.samples }
    }

    public var current: Memory.Allocation.Statistics {
        let current = Memory.Allocation.Statistics.capture()
        return Memory.Allocation.Statistics.delta(from: baseline, to: current)
    }

    public func reset() {
        state.withLock { state in
            state.samples.removeAll()
            state.peakBytes = 0
            state.peakAllocations = 0
        }
    }
}

extension Memory.Allocation.Peak.Tracker {

    public var peak: Peak { Peak(self) }
}

extension Memory.Allocation.Peak.Tracker {

    public struct Peak: Sendable {
        private let tracker: Memory.Allocation.Peak.Tracker

        internal init(_ tracker: Memory.Allocation.Peak.Tracker) {
            self.tracker = tracker
        }
    }
}

extension Memory.Allocation.Peak.Tracker.Peak {

    public var bytes: Int {
        tracker.state.withLock { $0.peakBytes }
    }

    public var allocations: Int {
        tracker.state.withLock { $0.peakAllocations }
    }
}

extension Memory.Allocation.Peak.Tracker {

    /// Runs `operation` with a fresh tracker and reports the highest sample.
    ///
    /// The tracker samples once after `operation` returns, so the peak is never below the final delta;
    /// call ``sample()`` inside `operation` to capture higher intermediate values.
    public static func track<T, E: Swift.Error>(
        _ operation: (Memory.Allocation.Peak.Tracker) throws(E) -> T
    ) throws(E) -> (result: T, peak: Memory.Allocation.Statistics) {
        let tracker = Memory.Allocation.Peak.Tracker()
        let result = try operation(tracker)
        tracker.sample()

        return (
            result,
            Memory.Allocation.Statistics(
                allocations: tracker.peak.allocations,
                deallocations: 0,
                bytesAllocated: tracker.peak.bytes
            )
        )
    }

    /// Runs `operation` with a fresh tracker and reports the highest sample.
    ///
    /// The tracker samples once after `operation` returns, so the peak is never below the final delta;
    /// call ``sample()`` inside `operation` to capture higher intermediate values.
    public static func track<T, E: Swift.Error>(
        _ operation: (Memory.Allocation.Peak.Tracker) async throws(E) -> T
    ) async throws(E) -> (result: T, peak: Memory.Allocation.Statistics) {
        let tracker = Memory.Allocation.Peak.Tracker()
        let result = try await operation(tracker)
        tracker.sample()

        return (
            result,
            Memory.Allocation.Statistics(
                allocations: tracker.peak.allocations,
                deallocations: 0,
                bytesAllocated: tracker.peak.bytes
            )
        )
    }
}
