import Testing

@testable import Memory_Mapping

extension Memory.Map.Page.Lock {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension Memory.Map.Page.Lock.Test.Unit {

    #if os(macOS) || os(Linux)
        @Test
        func `lock and unlock memory map`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

            do throws(Memory.Error) {
                try Memory.Map.Page.Lock.lock(map)
                try Memory.Map.Page.Lock.unlock(map)
            } catch {

            }

            map.unmap()
        }

        @Test
        func `lock and unlock by address`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

            guard let base = map.baseAddress else {
                map.unmap()
                Issue.record("Map has no base address")
                return
            }

            let length = map.length

            do throws(Memory.Error) {
                try Memory.Map.Page.Lock.lock(address: base, size: length)
                try Memory.Map.Page.Lock.unlock(address: base, size: length)
            } catch {

            }

            map.unmap()
        }

        @Test
        func `lock all flags are accessible`() {

            let _: Memory.Map.Page.Lock.All.Options = .current
            let _: Memory.Map.Page.Lock.All.Options = .future
        }
    #endif

    #if os(Windows)
        @Test
        func `lock and unlock memory map (Windows)`() throws {
            let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])

            guard let base = map.baseAddress else {
                map.unmap()
                Issue.record("Map has no base address")
                return
            }

            let length = map.length

            do throws(Memory.Error) {
                try Memory.Map.Page.Lock.lock(address: base, size: length)
                try Memory.Map.Page.Lock.unlock(address: base, size: length)
            } catch {

            }

            map.unmap()
        }

        @Test
        func `lock and unlock by address (Windows)`() throws {
            let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])

            guard let base = map.baseAddress else {
                map.unmap()
                Issue.record("Map has no base address")
                return
            }

            let length = map.length

            do throws(Memory.Error) {
                try Memory.Map.Page.Lock.lock(address: base, size: length)
                try Memory.Map.Page.Lock.unlock(address: base, size: length)
            } catch {

            }

            map.unmap()
        }
    #endif
}

extension Memory.Map.Page.Lock.Test.`Edge Case` {

}

extension Memory.Map.Page.Lock.Test.Performance {

}
