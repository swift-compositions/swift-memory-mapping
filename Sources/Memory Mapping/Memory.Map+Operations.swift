public import Kernel
@_spi(MemoryInternal) public import Memory

extension Memory.Map {

    public consuming func unmap() {
        guard let currentRegion = _region else { return }

        _lockToken?.release()

        _unmap(currentRegion)

        _region = nil
    }
}

#if !os(Windows)
    extension Memory.Map {

        public consuming func remap(
            fileDescriptor: borrowing Kernel.Descriptor,
            range: Range
        ) throws(Memory.Error) -> Self {
            let capturedAccess = access
            let capturedSharing = sharing
            let capturedSafety = safety

            self.unmap()

            return try Self(
                fileDescriptor: fileDescriptor,
                range: range,
                access: capturedAccess,
                sharing: capturedSharing,
                safety: capturedSafety
            )
        }
    }
#endif

#if os(Windows)
    extension Memory.Map {
        public consuming func remap(
            fileHandle: borrowing Kernel.Descriptor,
            range: Range
        ) throws(Memory.Error) -> Self {
            let capturedAccess = access
            let capturedSharing = sharing
            let capturedSafety = safety

            self.unmap()

            return try Self.open(
                fileHandle: fileHandle,
                range: range,
                access: capturedAccess,
                sharing: capturedSharing,
                safety: capturedSafety
            )
        }
    }
#endif

extension Memory.Map {

    public subscript(index: Index) -> Byte {
        get {
            precondition(index < endIndex, "Index out of bounds")
            guard let base = unsafe baseAddress else {
                preconditionFailure("Mapping is not valid")
            }
            return Byte(
                unsafe base.load(
                    fromByteOffset: Int(bitPattern: index.underlying.rawValue),
                    as: UInt8.self
                )
            )
        }
        nonmutating set {
            precondition(access.allows.write, "Mapping does not allow writes")
            precondition(index < endIndex, "Index out of bounds")
            guard let base = unsafe mutableBaseAddress else {
                preconditionFailure("Mapping is not valid")
            }
            unsafe base.storeBytes(
                of: newValue.underlying,
                toByteOffset: Int(bitPattern: index.underlying.rawValue),
                as: UInt8.self
            )
        }
    }

    public func withUnsafeBytes<T, E: Swift.Error>(
        _ body: (UnsafeRawBufferPointer) throws(E) -> T
    ) throws(E) -> T {
        guard let base = unsafe baseAddress else {
            preconditionFailure("Mapping is not valid")
        }
        let buffer = unsafe UnsafeRawBufferPointer(
            start: base,
            count: Int(bitPattern: _userLength.underlying.rawValue)
        )
        return try unsafe body(buffer)
    }

    public func withUnsafeMutableBytes<T, E: Swift.Error>(
        _ body: (UnsafeMutableRawBufferPointer) throws(E) -> T
    ) throws(E) -> T {
        precondition(access.allows.write, "Mapping does not allow writes")
        guard let base = unsafe mutableBaseAddress else {
            preconditionFailure("Mapping is not valid")
        }
        let buffer = unsafe UnsafeMutableRawBufferPointer(
            start: base,
            count: Int(bitPattern: _userLength.underlying.rawValue)
        )
        return try unsafe body(buffer)
    }
}

extension Memory.Map {

    public mutating func protect(_ newAccess: Access) throws(Memory.Error) {
        try newAccess.validate()

        guard let base = mappingBaseAddress else {
            throw .unmapped
        }

        do throws(Self.Error) {
            try Self.protect(
                addr: base,
                length: mappingLength,
                protection: newAccess.kernelProtection
            )
            access = newAccess
        } catch {
            throw Memory.Error(from: error)
        }
    }
}

extension Memory.Map {

    public func sync(async: Bool = false) throws(Memory.Error) {
        guard let base = mappingBaseAddress else {
            throw .unmapped
        }

        do throws(Self.Error) {
            #if os(Windows)
                try unsafe Self.sync(addr: base, length: mappingLength)
            #else
                let flags: Memory.Map.Sync.Options = async ? .async : .sync
                try Self.sync(addr: base, length: mappingLength, flags: flags)
            #endif
        } catch {
            throw Memory.Error(from: error)
        }
    }

    public func advise(_ advice: Memory.Map.Advice) {
        guard let base = mappingBaseAddress else { return }
        Self.advise(addr: base, length: mappingLength, advice: advice)
    }
}

extension Memory.Map {

    var mappingBaseAddress: Memory.Address? { _region?.base }

    var mappingLength: Memory.Address.Count { _region?.length ?? .zero }

    public var baseAddress: UnsafeRawPointer? {
        guard let base = mappingBaseAddress else { return nil }
        return unsafe base.pointer.advanced(by: Int(bitPattern: _offsetDelta.underlying.rawValue))
    }

    public var mutableBaseAddress: UnsafeMutableRawPointer? {
        guard access.allows.write, let base = mappingBaseAddress else { return nil }
        return unsafe base.mutablePointer.advanced(
            by: Int(bitPattern: _offsetDelta.underlying.rawValue)
        )
    }

    public var length: Memory.Address.Count { _userLength }

    public var endIndex: Index {
        Index(Ordinal(_userLength.underlying.rawValue))
    }

    public var isMapped: Bool { _region != nil }
}

extension Memory.Map {

    public typealias Index = Tagged<Memory.Map, Ordinal>

    public typealias Offset = Index.Offset
}

extension Memory.Map {

    public var debugDescription: Swift.String {
        let status = isMapped ? "mapped" : "unmapped"
        return
            "Map(\(status), length: \(_userLength), access: \(access), sharing: \(sharing), safety: \(safety))"
    }
}
