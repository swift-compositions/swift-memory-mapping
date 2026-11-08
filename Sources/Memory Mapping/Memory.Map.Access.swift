public import Kernel

extension Memory.Map.Access {

    @inlinable
    public var kernelProtection: Memory.Map.Protection {
        switch (contains(.read), contains(.write)) {
        case (true, true):
            return Memory.Map.Protection.read | Memory.Map.Protection.write

        case (true, false):
            return .read

        case (false, true):
            return .write

        case (false, false):
            return .none
        }
    }
}

extension Memory.Map.Access {

    @inlinable
    public func validate() throws(Memory.Error) {
        if contains(.write) && !contains(.read) {
            throw .access
        }
    }
}
