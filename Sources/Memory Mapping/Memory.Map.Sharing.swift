internal import Kernel

extension Memory.Map.Sharing {

    @inlinable
    public var kernelOptions: Memory.Map.Options {
        switch self {
        case .shared: return .shared
        case .private: return .private
        }
    }
}
