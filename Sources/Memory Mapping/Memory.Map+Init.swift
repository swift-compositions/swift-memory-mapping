public import Kernel

#if !os(Windows)
    extension Memory.Map {

        public init(
            fileDescriptor: borrowing Kernel.Descriptor,
            range: Range,
            access: Access = .read,
            sharing: Sharing = .shared,
            safety: Safety? = nil
        ) throws(Memory.Error) {
            try access.validate()

            let effectiveSafety = safety ?? (access.allows.write ? .default.write : .default.read)

            let userLen: Kernel.File.Size
            switch range {
            case .bytes(_, let length):
                userLen = length

            case .whole:
                let fileStats: Kernel.File.Stats
                do throws(Kernel.File.Stats.Error) {
                    fileStats = try Kernel.File.Stats.get(descriptor: fileDescriptor)
                } catch {
                    throw .stat(error)
                }
                userLen = fileStats.size
                guard userLen.isPositive else {
                    throw .size
                }
            }

            let requestedOffset = range.offset
            let alignedOffset = Memory.Allocation.align.down(requestedOffset)
            let delta = Kernel.File.Size(requestedOffset - alignedOffset)
            let totalLength = userLen + delta
            let mappingLen = try Memory.Map.Page.align.up(totalLength)

            let mappingLenCount = Memory.Address.Count(UInt(mappingLen.underlying))

            let baseAddress: Memory.Address
            do throws(Self.Error) {
                baseAddress = try Self.map(
                    length: mappingLenCount,
                    protection: access.kernelProtection,
                    flags: sharing.kernelOptions,
                    descriptor: fileDescriptor,
                    offset: alignedOffset
                )
            } catch {
                throw Memory.Error(from: error)
            }

            let region = Self.Region(base: baseAddress, length: mappingLenCount)

            let lockToken: Memory.Lock.Token?
            if case .coordinated(let kind, let scope) = effectiveSafety {
                let lockRange = Self.computeLockRange(
                    scope: scope,
                    alignedOffset: alignedOffset,
                    mappingLength: mappingLen
                )
                do throws(Kernel.Lock.Error) {
                    lockToken = try Memory.Lock.Token.acquire(
                        descriptor: fileDescriptor,
                        range: lockRange,
                        kind: kind
                    )
                } catch {
                    do throws(Self.Error) {
                        try Self.unmap(region)
                    } catch {}
                    throw .fileLock(error)
                }
            } else {
                lockToken = nil
            }

            self.init(
                region: region,
                offsetDelta: Memory.Address.Count(UInt(delta.underlying)),
                userLength: Memory.Address.Count(UInt(userLen.underlying)),
                access: access,
                sharing: sharing,
                safety: effectiveSafety,
                lockToken: lockToken,
                unmap: { region in
                    do throws(Self.Error) {
                        try Self.unmap(region)
                    } catch {}
                }
            )
        }

        public static func open(
            fileDescriptor: borrowing Kernel.Descriptor,
            range: Range,
            access: Access = .read,
            sharing: Sharing = .shared,
            safety: Safety? = nil
        ) throws(Memory.Error) -> Self {
            try Self(
                fileDescriptor: fileDescriptor,
                range: range,
                access: access,
                sharing: sharing,
                safety: safety
            )
        }
    }
#endif

extension Memory.Map {

    static func computeLockRange(
        scope: Safety.Scope,
        alignedOffset: Kernel.File.Offset,
        mappingLength: Kernel.File.Size
    ) -> Kernel.Lock.Range {
        switch scope {
        case .file:
            return .file

        case .mapped:
            return Kernel.Lock.Range(
                forMappingAt: alignedOffset,
                length: mappingLength,
                granularity: Memory.Allocation.system
            )
        }
    }
}

#if os(Windows)
    extension Memory.Map {
        public static func open(
            fileHandle: borrowing Kernel.Descriptor,
            range: Range,
            access: Access = .read,
            sharing: Sharing = .shared,
            safety: Safety? = nil
        ) throws(Memory.Error) -> Self {
            try access.validate()

            let effectiveSafety = safety ?? (access.allows.write ? .default.write : .default.read)

            let userLen: Kernel.File.Size
            switch range {
            case .bytes(_, let length):
                userLen = length

            case .whole:
                let fileStats: Kernel.File.Stats
                do throws(Kernel.File.Stats.Error) {
                    fileStats = try Kernel.File.Stats.get(descriptor: fileHandle)
                } catch {
                    throw .stat(error)
                }
                userLen = fileStats.size
                guard userLen.isPositive else {
                    throw .size
                }
            }

            let requestedOffset = range.offset
            let alignedOffset = Memory.Allocation.align.down(requestedOffset)
            let delta = Kernel.File.Size(requestedOffset - alignedOffset)
            let totalLength = userLen + delta
            let mappingLen = try Memory.Map.Page.align.up(totalLength)

            let mappingLenCount = Memory.Address.Count(UInt(mappingLen.underlying))

            let baseAddress: Memory.Address
            do throws(Self.Error) {
                baseAddress = try Self.map(
                    fd: fileHandle,
                    length: mappingLenCount,
                    protection: access.kernelProtection,
                    flags: sharing.kernelOptions,
                    offset: alignedOffset
                )
            } catch {
                throw Memory.Error(from: error)
            }

            let region = Self.Region(base: baseAddress, length: mappingLenCount)

            let lockToken: Memory.Lock.Token? = nil

            return Self(
                region: region,
                offsetDelta: Memory.Address.Count(UInt(delta.underlying)),
                userLength: Memory.Address.Count(UInt(userLen.underlying)),
                access: access,
                sharing: sharing,
                safety: effectiveSafety,
                lockToken: lockToken,
                unmap: { region in

                    do throws(Self.Error) {
                        try Self.unmap(
                            addr: region.base,
                            length: region.length,
                            isAnonymous: false
                        )
                    } catch {}
                }
            )
        }
    }
#endif

#if !os(Windows)
    extension Memory.Map {

        public init(
            anonymousLength length: Kernel.File.Size,
            access: Access = [.read, .write],
            sharing: Sharing = .private
        ) throws(Memory.Error) {
            try access.validate()

            let mappingLen = try Memory.Map.Page.align.up(length)
            let mappingLenCount = Memory.Address.Count(UInt(mappingLen.underlying))

            let region: Memory.Map.Region
            do throws(Self.Error) {
                region = try Self.Anonymous.map(
                    length: mappingLenCount,
                    protection: access.kernelProtection,
                    shared: sharing == .shared
                )
            } catch {
                throw Memory.Error(from: error)
            }

            self.init(
                region: region,
                offsetDelta: .zero,
                userLength: Memory.Address.Count(UInt(length.underlying)),
                access: access,
                sharing: sharing,
                safety: .unchecked,
                lockToken: nil,
                unmap: { region in
                    do throws(Self.Error) {
                        try Self.unmap(region)
                    } catch {}
                }
            )
        }

        public static func anonymous(
            length: Kernel.File.Size,
            access: Access = [.read, .write],
            sharing: Sharing = .private
        ) throws(Memory.Error) -> Self {
            try Self(anonymousLength: length, access: access, sharing: sharing)
        }
    }
#endif

#if os(Windows)
    extension Memory.Map {
        public static func anonymous(
            length: Kernel.File.Size,
            access: Access = [.read, .write],
            sharing: Sharing = .private
        ) throws(Memory.Error) -> Self {
            try access.validate()

            let mappingLen = try Memory.Map.Page.align.up(length)
            let mappingLenCount = Memory.Address.Count(UInt(mappingLen.underlying))

            let region: Memory.Map.Region
            do throws(Self.Error) {
                region = try Self.Anonymous.map(
                    length: mappingLenCount,
                    protection: access.kernelProtection
                )
            } catch {
                throw Memory.Error(from: error)
            }

            return Self(
                region: region,
                offsetDelta: .zero,
                userLength: Memory.Address.Count(UInt(length.underlying)),
                access: access,
                sharing: sharing,
                safety: .unchecked,
                lockToken: nil,
                unmap: { region in

                    do throws(Self.Error) {
                        try Self.unmap(
                            addr: region.base,
                            length: region.length,
                            isAnonymous: true
                        )
                    } catch {}
                }
            )
        }
    }
#endif

#if os(Linux)
    extension Memory.Map {

        public init(
            fileDescriptor: borrowing Kernel.Descriptor,
            mmapOffset: Kernel.File.Offset,
            length: Kernel.File.Size,
            access: Access = [.read, .write],
            sharing: Sharing = .shared
        ) throws(Memory.Error) {
            try access.validate()

            let mappingLen = try Memory.Map.Page.align.up(length)
            let mappingLenCount = Memory.Address.Count(UInt(mappingLen.underlying))

            let baseAddress: Memory.Address
            do throws(Self.Error) {
                baseAddress = try Self.map(
                    length: mappingLenCount,
                    protection: access.kernelProtection,
                    flags: sharing.kernelOptions,
                    descriptor: fileDescriptor,
                    offset: mmapOffset
                )
            } catch {
                throw Memory.Error(from: error)
            }

            let region = Self.Region(base: baseAddress, length: mappingLenCount)

            self.init(
                region: region,
                offsetDelta: .zero,
                userLength: Memory.Address.Count(UInt(length.underlying)),
                access: access,
                sharing: sharing,
                safety: .unchecked,
                lockToken: nil,
                unmap: { region in
                    do throws(Self.Error) {
                        try Self.unmap(region)
                    } catch {}
                }
            )
        }
    }
#endif
