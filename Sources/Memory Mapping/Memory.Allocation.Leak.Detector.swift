extension Memory.Allocation.Leak {

    public final class Detector: Sendable {
        private let baseline: Memory.Allocation.Statistics

        public init() {
            self.baseline = Memory.Allocation.Statistics.capture()
        }
    }
}

extension Memory.Allocation.Leak.Detector {

    public var detected: Bool {
        net.allocations > 0
    }

    public func assertNone(
        file: StaticString = #file,
        line: UInt = #line
    ) throws(Memory.Allocation.Leak.Error) {
        let netAllocs = net.allocations
        guard netAllocs == 0 else {
            throw .detected(
                allocations: netAllocs,
                bytes: delta().bytes.allocated,
                file: file,
                line: line
            )
        }
    }
}

extension Memory.Allocation.Leak.Detector {

    public var net: Net { Net(self) }
}

extension Memory.Allocation.Leak.Detector {

    public struct Net: Sendable {
        private let detector: Memory.Allocation.Leak.Detector

        internal init(_ detector: Memory.Allocation.Leak.Detector) {
            self.detector = detector
        }
    }
}

extension Memory.Allocation.Leak.Detector.Net {

    public var allocations: Int {
        let current = Memory.Allocation.Statistics.capture()
        let delta = Memory.Allocation.Statistics.delta(from: detector.baseline, to: current)
        return delta.net.allocations
    }
}

extension Memory.Allocation.Leak.Detector {

    public func delta() -> Memory.Allocation.Statistics {
        let current = Memory.Allocation.Statistics.capture()
        return Memory.Allocation.Statistics.delta(from: baseline, to: current)
    }
}
