public import Kernel

extension Memory.Shared {

    public struct Mode: Sendable, Equatable {

        public let access: Memory.Shared.Access

        public let options: Memory.Shared.Options

        public let permissions: Kernel.File.Permissions

        public init(
            access: Memory.Shared.Access,
            options: Memory.Shared.Options = [],
            permissions: Kernel.File.Permissions = .ownerReadWrite
        ) {
            self.access = access
            self.options = options
            self.permissions = permissions
        }
    }
}

extension Memory.Shared.Mode {

    public static let read = Self(access: .read)

    public static var create: Create.Type { Create.self }
}

extension Memory.Shared.Mode: ExpressibleByArrayLiteral {

    public init(arrayLiteral elements: Memory.Shared.Access...) {
        var read = false
        var write = false
        for element in elements {
            if element.read { read = true }
            if element.write { write = true }
        }
        self.init(access: Memory.Shared.Access(read: read, write: write))
    }
}

extension Memory.Shared.Mode {

    public enum Create {}
}

extension Memory.Shared.Mode.Create {

    public static var exclusive: Memory.Shared.Mode {
        Memory.Shared.Mode(
            access: .readWrite,
            options: [.create, .exclusive]
        )
    }

    public static var truncate: Memory.Shared.Mode {
        Memory.Shared.Mode(
            access: .readWrite,
            options: [.create, .truncate]
        )
    }
}

#if !os(Windows)

    extension Memory.Shared {

        public static func open(
            name: Swift.String,
            mode: Mode
        ) throws(Memory.Error) -> Kernel.Descriptor {

            var fd: Kernel.Descriptor? = nil
            var openError: Memory.Shared.Error? = nil
            name.withCString { namePtr in
                do throws(Self.Error) {
                    fd = try unsafe Self.open(
                        name: namePtr,
                        access: mode.access,
                        options: mode.options,
                        permissions: mode.permissions
                    )
                } catch {
                    openError = error
                }
            }
            if let fd {
                return fd
            }
            if let openError {
                throw Memory.Error(from: openError)
            }
            preconditionFailure("unreachable: withCString must set fd or openError")
        }

        public static func unlink(name: Swift.String) throws(Memory.Error) {
            var unlinkError: Memory.Shared.Error?
            name.withCString { namePtr in
                do throws(Self.Error) {
                    try unsafe Self.unlink(name: namePtr)
                } catch {
                    unlinkError = error
                }
            }
            if let unlinkError {
                throw Memory.Error(from: unlinkError)
            }
        }
    }

#endif

#if os(Windows)

    extension Memory.Shared {

        public static func open(
            name: Swift.String,
            size: Kernel.File.Size,
            mode: Mode
        ) throws(Memory.Error) -> Kernel.Descriptor {
            do throws(Self.Error) {
                return try Self.open(
                    name: name,
                    size: size,
                    access: mode.access,
                    options: mode.options
                )
            } catch {
                throw Memory.Error(from: error)
            }
        }

        public static func open(
            name: Swift.String,
            mode: Mode
        ) throws(Memory.Error) -> Kernel.Descriptor {
            do throws(Self.Error) {
                return try Self.open(
                    name: name,
                    access: mode.access
                )
            } catch {
                throw Memory.Error(from: error)
            }
        }

        public static func close(
            _ descriptor: consuming Kernel.Descriptor
        ) throws(Kernel.Close.Error) {
            try Kernel.Close.close(descriptor)
        }
    }

#endif
