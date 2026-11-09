import Testing

@testable import Memory_Mapping

extension Memory.Test.`Edge Case` {
    @Test func `histogram of a single value has one bucket holding it`() {
        let histogram = Memory.Allocation.Histogram(values: [42], buckets: 10)
        #expect(histogram.buckets.count == 1)
        #expect(histogram.buckets.first?.range == 42..<43)
        #expect(histogram.buckets.first?.count == 1)
    }

    @Test func `histogram whose values span fewer integers than buckets clamps the bucket count`() {
        let histogram = Memory.Allocation.Histogram(values: [1, 2, 2, 3], buckets: 10)
        #expect(histogram.buckets.count == 3)
        #expect(histogram.buckets.map(\.count) == [1, 2, 1])
        #expect(histogram.buckets.allSatisfy { $0.range.lowerBound < $0.range.upperBound })
    }

    @Test func `histogram over a wide span keeps the requested bucket count and every value`() {
        let values = Array(0..<100)
        let histogram = Memory.Allocation.Histogram(values: values, buckets: 10)
        #expect(histogram.buckets.count == 10)
        #expect(histogram.buckets.reduce(0) { $0 + $1.count } == values.count)
    }
}
