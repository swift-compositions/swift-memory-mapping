extension Memory.Allocation.Leak {

    public enum Error: Swift.Error, Sendable {

        case detected(allocations: Int, bytes: Int, file: StaticString, line: UInt)
    }
}

extension Memory.Allocation.Leak.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .detected(let allocations, let bytes, let file, let line):
            return """
                Memory leak detected at \(file):\(line)
                Net allocations: \(allocations)
                Bytes allocated since baseline: \(bytes)
                """
        }
    }
}
