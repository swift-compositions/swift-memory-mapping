public import Kernel

#if !os(Windows)

    extension Memory.Lock.Token {

        public static func acquire(
            descriptor: borrowing Kernel.Descriptor,
            range: Kernel.Lock.Range,
            kind: Memory.Lock.Kind
        ) throws(Kernel.Lock.Error) -> Memory.Lock.Token {

            let duped: Kernel.Descriptor
            do throws(Kernel.Descriptor.Duplicate.Error) {
                duped = try Kernel.Descriptor.Duplicate.duplicate(descriptor)
            } catch {
                throw .unavailable
            }

            let kernelKind: Kernel.Lock.Kind
            switch kind {
            case .shared: kernelKind = .shared
            case .exclusive: kernelKind = .exclusive
            }

            do throws(Kernel.Lock.Error) {
                try Kernel.Lock.lock(duped, range: range, kind: kernelKind)
            } catch {

                do throws(Kernel.Close.Error) {
                    try Kernel.Close.close(consume duped)
                } catch {}
                throw error
            }

            var ownedFd: Kernel.Descriptor? = consume duped
            return Memory.Lock.Token(release: {
                guard let fd = ownedFd.take() else { return }
                do throws(Kernel.Lock.Error) {
                    try Kernel.Lock.unlock(fd, range: range)
                } catch {}
                do throws(Kernel.Close.Error) {
                    try Kernel.Close.close(consume fd)
                } catch {}
            })
        }
    }

#endif
