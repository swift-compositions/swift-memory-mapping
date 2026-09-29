public import Kernel

extension Memory.Map.Page {

    public enum Lock {}
}

extension Memory.Map.Page.Lock {

    public static var all: All.Type { All.self }

    public enum All {}
}

extension Memory.Map.Page.Lock.All {

    public static var isSupported: Bool {
        #if os(Windows)
            return false
        #else
            return true
        #endif
    }
}

extension Memory.Map.Page.Lock {

    public static func lock(
        address: UnsafeRawPointer,
        size: Memory.Address.Count
    ) throws(Memory.Error) {
        do throws(Memory.Lock.Error) {
            try unsafe Memory.Lock.lock(address: address, length: size)
        } catch {
            throw Memory.Error(from: error)
        }
    }

    public static func unlock(
        address: UnsafeRawPointer,
        size: Memory.Address.Count
    ) throws(Memory.Error) {
        do throws(Memory.Lock.Error) {
            try unsafe Memory.Lock.unlock(address: address, length: size)
        } catch {
            throw Memory.Error(from: error)
        }
    }
}

extension Memory.Map.Page.Lock {

    public static func lock(_ map: borrowing Memory.Map) throws(Memory.Error) {
        guard let base = unsafe map.baseAddress else {
            throw .unmapped
        }
        try unsafe lock(address: base, size: map.length)
    }

    public static func unlock(_ map: borrowing Memory.Map) throws(Memory.Error) {
        guard let base = unsafe map.baseAddress else {
            throw .unmapped
        }
        try unsafe unlock(address: base, size: map.length)
    }
}

#if !os(Windows)
    extension Memory.Map.Page.Lock.All {

        public typealias Options = Memory.Lock.All.Options

        public static func lock(_ options: Options) throws(Memory.Error) {
            do throws(Memory.Lock.Error) {
                try Memory.Lock.lockAll(options)
            } catch {
                throw Memory.Error(from: error)
            }
        }

        public static func unlock() throws(Memory.Error) {
            do throws(Memory.Lock.Error) {
                try Memory.Lock.unlockAll()
            } catch {
                throw Memory.Error(from: error)
            }
        }
    }
#endif
