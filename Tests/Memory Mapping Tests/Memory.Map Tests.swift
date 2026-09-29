import Kernel
import Kernel_Test_Support
@_spi(MemoryInternal) import Memory
import Testing

@testable import Memory_Mapping

extension Memory.Map {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension Memory.Map.Test.Unit {

    #if os(macOS) || os(Linux)
        @Test
        func `anonymous mapping creates valid region`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

            let isMapped = map.isMapped
            let length = map.length
            let hasBase = map.baseAddress != nil

            map.unmap()

            #expect(isMapped)
            #expect(length == 4096)
            #expect(hasBase)
        }

        @Test
        func `anonymous mapping read/write`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

            map[0] = 42
            map[100] = 123

            let byte0 = map[0]
            let byte100 = map[100]

            map.unmap()

            #expect(byte0 == 42)
            #expect(byte100 == 123)
        }

        @Test
        func `anonymous mapping default access is read/write`() throws {
            let map = try Memory.Map(anonymousLength: 4096)

            let access = map.access

            map.unmap()

            #expect(access.allows.read)
            #expect(access.allows.write)
        }

        @Test
        func `anonymous mapping read-only`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: .read)

            let access = map.access
            let noMutableBase = map.mutableBaseAddress == nil

            map.unmap()

            #expect(access.allows.read)
            #expect(!access.allows.write)
            #expect(noMutableBase)
        }

        @Test
        func `anonymous mapping uses unchecked safety`() throws {
            let map = try Memory.Map(anonymousLength: 4096)

            let safety = map.safety

            map.unmap()

            #expect(safety == .unchecked)
        }
    #endif

    #if os(Windows)
        @Test
        func `anonymous mapping via static factory`() throws {
            let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])

            let isMapped = map.isMapped
            let length = map.length

            map.unmap()

            #expect(isMapped)
            #expect(length == 4096)
        }

        @Test
        func `anonymous mapping read/write (Windows)`() throws {
            let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])

            map[0] = 42
            map[100] = 123

            let byte0 = map[0]
            let byte100 = map[100]

            map.unmap()

            #expect(byte0 == 42)
            #expect(byte100 == 123)
        }

        @Test
        func `withUnsafeBytes read access (Windows)`() throws {
            let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])

            map[0] = 1
            map[1] = 2
            map[2] = 3

            let sum = map.withUnsafeBytes { buffer -> Int in
                Int(buffer[0]) + Int(buffer[1]) + Int(buffer[2])
            }

            map.unmap()

            #expect(sum == 6)
        }

        @Test
        func `withUnsafeMutableBytes write access (Windows)`() throws {
            let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])

            map.withUnsafeMutableBytes { buffer in
                buffer[0] = 10
                buffer[1] = 20
                buffer[2] = 30
            }

            let byte0 = map[0]
            let byte1 = map[1]
            let byte2 = map[2]

            map.unmap()

            #expect(byte0 == 10)
            #expect(byte1 == 20)
            #expect(byte2 == 30)
        }

        @Test
        func `debug description (Windows)`() throws {
            let map = try Memory.Map.anonymous(length: 4096)

            let description = map.debugDescription

            map.unmap()

            #expect(description.contains("mapped"))
            #expect(description.contains("4096"))
        }
    #endif

    #if os(macOS) || os(Linux)
        @Test
        func `withUnsafeBytes provides read access`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

            map[0] = 1
            map[1] = 2
            map[2] = 3

            let sum = map.withUnsafeBytes { buffer -> Int in
                Int(buffer[0]) + Int(buffer[1]) + Int(buffer[2])
            }

            map.unmap()

            #expect(sum == 6)
        }

        @Test
        func `withUnsafeMutableBytes provides write access`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

            map.withUnsafeMutableBytes { buffer in
                buffer[0] = 10
                buffer[1] = 20
                buffer[2] = 30
            }

            let byte0 = map[0]
            let byte1 = map[1]
            let byte2 = map[2]

            map.unmap()

            #expect(byte0 == 10)
            #expect(byte1 == 20)
            #expect(byte2 == 30)
        }
    #endif

    #if os(macOS) || os(Linux)
        @Test
        func `file-backed mapping reads content`() throws {
            let content = "Hello, Memory Map!"
            let tempFile = try KernelIOTest.createTempFileWithContent(content)

            let map = try Memory.Map(
                fileDescriptor: tempFile.descriptor,
                range: .whole,
                access: .read,
                sharing: .shared,
                safety: .unchecked
            )

            let isMapped = map.isMapped
            let length = map.length

            let bytes = map.withUnsafeBytes { buffer -> [UInt8] in
                Array(buffer)
            }
            let readContent = Swift.String(decoding: bytes, as: UTF8.self)

            map.unmap()
            KernelIOTest.cleanupTempFile(tempFile)

            #expect(isMapped)
            #expect(length == Memory.Address.Count(UInt(content.utf8.count)))
            #expect(readContent == content)
        }

        @Test
        func `file-backed mapping with read/write modifies file`() throws {
            let content = "0123456789"
            let tempFile = try KernelIOTest.createTempFileWithContent(content)

            let map = try Memory.Map(
                fileDescriptor: tempFile.descriptor,
                range: .whole,
                access: [.read, .write],
                sharing: .shared,
                safety: .unchecked
            )

            map[0] = 65
            try map.sync()

            let byte0 = map[0]

            map.unmap()
            KernelIOTest.cleanupTempFile(tempFile)

            #expect(byte0 == 65)
        }

        @Test
        func `copy-on-write does not modify original`() throws {
            let content = "Original"
            let tempFile = try KernelIOTest.createTempFileWithContent(content)

            let map = try Memory.Map(
                fileDescriptor: tempFile.descriptor,
                range: .whole,
                access: [.read, .write],
                sharing: .private,
                safety: .unchecked
            )

            let originalByte = map[0]
            map[0] = 99

            let newByte = map[0]

            map.unmap()
            KernelIOTest.cleanupTempFile(tempFile)

            #expect(newByte == 99)
            #expect(originalByte == Byte(UInt8(ascii: "O")))
        }

        @Test
        func `static factory open() works`() throws {
            let content = "Factory test"
            let tempFile = try KernelIOTest.createTempFileWithContent(content)

            let map = try Memory.Map.open(
                fileDescriptor: tempFile.descriptor,
                range: .whole,
                access: .read
            )

            let isMapped = map.isMapped

            map.unmap()
            KernelIOTest.cleanupTempFile(tempFile)

            #expect(isMapped)
        }

        @Test
        func `static factory anonymous() works`() throws {
            let map = try Memory.Map.anonymous(length: 4096)

            let isMapped = map.isMapped
            let length = map.length

            map.unmap()

            #expect(isMapped)
            #expect(length == 4096)
        }

        @Test
        func `bytes range with offset and length`() throws {
            let content = Swift.String(repeating: "X", count: 8192)
            let tempFile = try KernelIOTest.createTempFileWithContent(content)

            let map = try Memory.Map(
                fileDescriptor: tempFile.descriptor,
                range: .bytes(offset: 4096, length: 1024),
                access: .read,
                safety: .unchecked
            )

            let length = map.length

            map.unmap()
            KernelIOTest.cleanupTempFile(tempFile)

            #expect(length == 1024)
        }
    #endif

    #if os(Linux)
        @Test
        func `mmap offset mapping for io_uring-style APIs`() throws {

            let content = Swift.String(repeating: "X", count: 8192)
            let tempFile = try KernelIOTest.createTempFileWithContent(content)

            let map = try Memory.Map(
                fileDescriptor: tempFile.descriptor,
                mmapOffset: Kernel.File.Offset(4096),
                length: 4096,
                access: .read,
                sharing: .shared
            )

            let isMapped = map.isMapped
            let length = map.length

            map.unmap()
            KernelIOTest.cleanupTempFile(tempFile)

            #expect(isMapped)
            #expect(length == 4096)
        }
    #endif

    #if os(macOS) || os(Linux)
        @Test
        func `sync on anonymous mapping`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

            map[0] = 42

            do throws(Memory.Error) {
                try map.sync()
            } catch {

            }

            map.unmap()
        }

        @Test
        func `sync async flag`() throws {
            let content = "Sync test"
            let tempFile = try KernelIOTest.createTempFileWithContent(content)

            let map = try Memory.Map(
                fileDescriptor: tempFile.descriptor,
                range: .whole,
                access: [.read, .write],
                sharing: .shared,
                safety: .unchecked
            )

            map[0] = 65

            try map.sync(async: false)
            try map.sync(async: true)

            map.unmap()
            KernelIOTest.cleanupTempFile(tempFile)
        }
    #endif

    #if os(macOS) || os(Linux)
        @Test
        func `protect changes access`() throws {
            var map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

            map[0] = 42
            try map.protect(.read)

            let access = map.access
            let byte0 = map[0]

            map.unmap()

            #expect(access == .read)
            #expect(!access.allows.write)
            #expect(byte0 == 42)
        }

        @Test
        func `protect restores write access`() throws {
            var map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

            try map.protect(.read)
            try map.protect([.read, .write])

            let access = map.access
            map[0] = 100
            let byte0 = map[0]

            map.unmap()

            #expect(access.allows.write)
            #expect(byte0 == 100)
        }
    #endif

    #if os(macOS) || os(Linux)
        @Test
        func `remap to new range`() throws {

            let firstHalf = Swift.String(repeating: "A", count: 4096)
            let secondHalf = Swift.String(repeating: "B", count: 4096)
            let content = firstHalf + secondHalf
            let tempFile = try KernelIOTest.createTempFileWithContent(content)

            var map = try Memory.Map(
                fileDescriptor: tempFile.descriptor,
                range: .bytes(offset: 0, length: 4096),
                access: .read,
                safety: .unchecked
            )

            let firstByte = map[0]

            map = try map.remap(
                fileDescriptor: tempFile.descriptor,
                range: .bytes(offset: 4096, length: 4096)
            )

            let secondByte = map[0]

            map.unmap()
            KernelIOTest.cleanupTempFile(tempFile)

            #expect(firstByte == Byte(UInt8(ascii: "A")))
            #expect(secondByte == Byte(UInt8(ascii: "B")))
        }
    #endif

    #if os(macOS) || os(Linux)
        @Test
        func `debug description`() throws {
            let map = try Memory.Map(anonymousLength: 4096)

            let description = map.debugDescription

            map.unmap()

            #expect(description.contains("mapped"))
            #expect(description.contains("4096"))
        }
    #endif
}

extension Memory.Map.Test.`Edge Case` {
    #if os(macOS) || os(Linux)
        @Test
        func `empty file throws size error`() throws {
            let tempFile = try KernelIOTest.createTempFile()

            #expect(throws: Memory.Error.self) {
                _ = try Memory.Map(
                    fileDescriptor: tempFile.descriptor,
                    range: .whole,
                    access: .read,
                    safety: .unchecked
                )
            }

            KernelIOTest.cleanupTempFile(tempFile)
        }

        @Test
        func `write-only access throws`() throws {
            #expect(throws: Memory.Error.self) {
                _ = try Memory.Map(anonymousLength: 4096, access: .write)
            }
        }

        @Test
        func `unmap consumes mapping`() throws {
            let map = try Memory.Map(anonymousLength: 4096)
            let wasMapped = map.isMapped

            map.unmap()

            #expect(wasMapped)
        }

        @Test
        func `zero-length bytes range behavior`() throws {

            let content = "Test content"
            let tempFile = try KernelIOTest.createTempFileWithContent(content)

            #expect(throws: Memory.Error.self) {
                _ = try Memory.Map(
                    fileDescriptor: tempFile.descriptor,
                    range: .bytes(offset: 0, length: 0),
                    access: .read,
                    safety: .unchecked
                )
            }

            KernelIOTest.cleanupTempFile(tempFile)
        }

        @Test
        func `non-page-aligned length is rounded up`() throws {
            let map = try Memory.Map(anonymousLength: 100, access: [.read, .write])

            let length = map.length
            let hasBase = map.baseAddress != nil

            map.unmap()

            #expect(length == 100)
            #expect(hasBase)
        }

        @Test
        func `offset at allocation granularity boundary`() throws {

            let content = Swift.String(repeating: "X", count: 131072)
            let tempFile = try KernelIOTest.createTempFileWithContent(content)

            let offsetBytes: Int = Memory.Allocation.granularity.underlying.magnitude()
            let map = try Memory.Map(
                fileDescriptor: tempFile.descriptor,
                range: .bytes(offset: Kernel.File.Offset(offsetBytes), length: 4096),
                access: .read,
                safety: .unchecked
            )

            let isMapped = map.isMapped
            let length = map.length

            map.unmap()
            KernelIOTest.cleanupTempFile(tempFile)

            #expect(isMapped)
            #expect(length == 4096)
        }

        @Test
        func `non-granularity-aligned offset works`() throws {

            let content = Swift.String(repeating: "Y", count: 131072)
            let tempFile = try KernelIOTest.createTempFileWithContent(content)

            let map = try Memory.Map(
                fileDescriptor: tempFile.descriptor,
                range: .bytes(offset: 1000, length: 4096),
                access: .read,
                safety: .unchecked
            )

            let isMapped = map.isMapped
            let length = map.length

            let byte0 = map[0]

            map.unmap()
            KernelIOTest.cleanupTempFile(tempFile)

            #expect(isMapped)
            #expect(length == 4096)
            #expect(byte0 == Byte(UInt8(ascii: "Y")))
        }

        @Test
        func `subscript at last valid index`() throws {
            let map = try Memory.Map(anonymousLength: 100, access: [.read, .write])

            map[99] = 255
            let byte = map[99]

            map.unmap()

            #expect(byte == 255)
        }

        @Test
        func `subscript at first index`() throws {
            let map = try Memory.Map(anonymousLength: 100, access: [.read, .write])

            map[0] = 1
            let byte = map[0]

            map.unmap()

            #expect(byte == 1)
        }
    #endif

    #if os(Windows)
        @Test
        func `write-only access throws (Windows)`() throws {
            #expect(throws: Memory.Error.self) {
                _ = try Memory.Map.anonymous(length: 4096, access: .write)
            }
        }

        @Test
        func `unmap consumes mapping (Windows)`() throws {
            let map = try Memory.Map.anonymous(length: 4096)
            let wasMapped = map.isMapped

            map.unmap()

            #expect(wasMapped)
        }

        @Test
        func `non-page-aligned length is rounded up (Windows)`() throws {
            let map = try Memory.Map.anonymous(length: 100, access: [.read, .write])

            let length = map.length
            let hasBase = map.baseAddress != nil

            map.unmap()

            #expect(length == 100)
            #expect(hasBase)
        }

        @Test
        func `subscript at last valid index (Windows)`() throws {
            let map = try Memory.Map.anonymous(length: 100, access: [.read, .write])

            map[99] = 255
            let byte = map[99]

            map.unmap()

            #expect(byte == 255)
        }

        @Test
        func `subscript at first index (Windows)`() throws {
            let map = try Memory.Map.anonymous(length: 100, access: [.read, .write])

            map[0] = 1
            let byte = map[0]

            map.unmap()

            #expect(byte == 1)
        }
    #endif
}

extension Memory.Map.Test.Performance {
    #if os(macOS) || os(Linux)
        @Test
        func `Map/unmap cycle`() throws {
            for _ in 0..<10 {
                let map = try Memory.Map(anonymousLength: 4096)
                map.unmap()
            }
        }

        @Test
        func `Sequential write throughput`() throws {
            let map = try Memory.Map(anonymousLength: 65536, access: [.read, .write])

            map.withUnsafeMutableBytes { buffer in
                for i in 0..<buffer.count {
                    buffer[i] = UInt8(truncatingIfNeeded: i)
                }
            }

            map.unmap()
        }
    #endif

    #if os(Windows)
        @Test
        func `Map/unmap cycle (Windows)`() throws {
            for _ in 0..<10 {
                let map = try Memory.Map.anonymous(length: 4096)
                map.unmap()
            }
        }

        @Test
        func `Sequential write throughput (Windows)`() throws {
            let map = try Memory.Map.anonymous(length: 65536, access: [.read, .write])

            map.withUnsafeMutableBytes { buffer in
                for i in 0..<buffer.count {
                    buffer[i] = UInt8(truncatingIfNeeded: i)
                }
            }

            map.unmap()
        }
    #endif
}
