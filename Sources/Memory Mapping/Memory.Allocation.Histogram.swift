extension Memory.Allocation {

    public struct Histogram: Sendable {
        public let buckets: [Bucket]

        public init(values: [Int], buckets bucketCount: Int) {
            let sorted = values.sorted()
            guard bucketCount > 0, let min = sorted.first, let max = sorted.last else {
                self.buckets = []
                return
            }
            let span = max - min + 1
            let bucketTotal = Swift.min(bucketCount, span)
            let bucketSize = span / bucketTotal
            var result: [Bucket] = []
            (0..<bucketTotal).forEach { i in
                let lo = min + i * bucketSize
                let hi = (i == bucketTotal - 1) ? max + 1 : lo + bucketSize
                let count = sorted.filter { $0 >= lo && $0 < hi }.count
                result.append(Bucket(range: lo..<hi, count: count))
            }
            self.buckets = result
        }
    }
}

extension Memory.Allocation.Histogram {
}
