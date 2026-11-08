extension Memory.Allocation.Histogram {
    public struct Bucket: Sendable {
        public let range: Range<Int>
        public let count: Int
    }
}
