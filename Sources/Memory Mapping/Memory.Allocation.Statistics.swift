#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    internal import Darwin_Memory_Standard
#elseif os(Linux)
    internal import Linux_Memory_Standard
#endif

extension Memory.Allocation {

    public struct Statistics: Sendable, Equatable {
        public let allocations: Int
        public let deallocations: Int
        public let bytesAllocated: Int
        public let availability: Availability
        public let scope: Scope
        public let instrumentation: Instrumentation

        public init(
            allocations: Int = 0,
            deallocations: Int = 0,
            bytesAllocated: Int = 0,
            availability: Availability = .unavailable,
            scope: Scope = .none,
            instrumentation: Instrumentation = .none
        ) {
            self.allocations = allocations
            self.deallocations = deallocations
            self.bytesAllocated = bytesAllocated
            self.availability = availability
            self.scope = scope
            self.instrumentation = instrumentation
        }
    }
}

extension Memory.Allocation.Statistics {
    public var bytes: Bytes { Bytes(self) }
    public var net: Net { Net(self) }

    public struct Bytes: Sendable {
        private let stats: Memory.Allocation.Statistics
        init(_ stats: Memory.Allocation.Statistics) { self.stats = stats }
    }

    public struct Net: Sendable {
        private let stats: Memory.Allocation.Statistics
        init(_ stats: Memory.Allocation.Statistics) { self.stats = stats }
    }
}

extension Memory.Allocation.Statistics.Bytes {
    public var allocated: Int { stats.bytesAllocated }
}

extension Memory.Allocation.Statistics.Net {
    public var allocations: Int { stats.allocations - stats.deallocations }
}

extension Memory.Allocation.Statistics {

    public static func capture() -> Self {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            let statistics = Darwin.Memory.Allocation.Statistics.capture()
            return Self(
                allocations: statistics.allocations,
                deallocations: statistics.deallocations,
                bytesAllocated: statistics.bytesAllocated,
                availability: .available,
                scope: .process,
                instrumentation: .snapshot
            )
        #elseif os(Linux)
            let statistics = Linux.Memory.Allocation.Statistics.capture()
            return Self(
                allocations: statistics.allocations,
                deallocations: statistics.deallocations,
                bytesAllocated: statistics.bytesAllocated,
                availability: .available,
                scope: .thread,
                instrumentation: .interposed
            )
        #else
            return Self()
        #endif
    }

    public static func delta(from baseline: Self, to current: Self) -> Self {
        Self(
            allocations: current.allocations - baseline.allocations,
            deallocations: current.deallocations - baseline.deallocations,
            bytesAllocated: current.bytesAllocated - baseline.bytesAllocated,
            availability:
                baseline.availability == .available && current.availability == .available
                ? .available : .unavailable,
            scope: baseline.scope == current.scope ? current.scope : .none,
            instrumentation:
                baseline.instrumentation == current.instrumentation
                ? current.instrumentation : .none
        )
    }

}
