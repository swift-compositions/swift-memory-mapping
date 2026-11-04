# swift-memory-mapping

Use this package when you need to map a file or anonymous memory into the process, share named memory between processes, pin pages in RAM, or count the heap allocations a piece of code makes. Start from `Memory.Map` for mappings, `Memory.Shared.open(name:mode:)` for named shared memory, `Memory.Map.Page.Lock` to lock pages, and `Memory.Allocation.Tracker`, `Memory.Allocation.Leak.Detector`, `Memory.Allocation.Peak.Tracker` or `Memory.Allocation.Profiler` to measure allocations. The `Memory.Map` value itself and its access, sharing and safety options come from swift-memory, which only describes a mapping and makes no system calls. To hand out addresses from memory you already own, use swift-memory-allocation.

## Laws

- Write access without read access is rejected before anything is mapped. An empty access set is accepted.
- A file mapping defaults to read access and `.shared` sharing. An anonymous mapping defaults to read and write access and `.private` sharing.
- Unless a safety is given, a file mapping takes an advisory file lock over the mapped range: shared for a read-only mapping and exclusive for a writable one. The lock is taken on a duplicate of the descriptor and released when the mapping is unmapped. If the lock can't be taken, the mapping is undone and the call fails. On Windows the lock is never taken. Anonymous mappings, and the Linux initializer that takes a raw `mmapOffset`, are unchecked.
- `Memory.Map.Range.whole` maps the file's size at the time of the call, and an empty file fails. A zero-length byte range fails.
- An offset need not be aligned. The mapping starts at the offset rounded down to the allocation granularity, but `baseAddress`, indices and `length` all refer to the requested range. The mapped length is rounded up to whole pages, and the bytes beyond `length` can't be reached through the map.
- Reading past `length`, or writing through a mapping without write access, traps. `mutableBaseAddress` is nil for a mapping without write access.
- `Memory.Map.protect(_:)` and `Memory.Map.sync(async:)` act on the whole mapped pages. With `async` true, `sync` schedules the write-back and returns without waiting for it.
- `Memory.Map.remap(fileDescriptor:range:)` unmaps first and then maps the new range with the same access, sharing and safety. If the new mapping fails, the old one is already gone.
- Advice on an unmapped mapping does nothing. On Windows advice has no effect.
- `Memory.Shared.Mode.Create.exclusive` fails if the name already exists. New shared memory is readable and writable by its owner only, unless other permissions are given.
- `Memory.Allocation.Statistics.capture()` counts the whole process on Apple platforms, and only the calling thread on Linux. Elsewhere it reports nothing as unavailable. A delta is available only when both ends are, and keeps a scope or instrumentation only when both ends agree.
- `Memory.Allocation.Leak.Detector` compares against the statistics taken when it was created. It reports a leak when more allocations than deallocations happened since then. The byte count it reports is every byte allocated since then, freed or not.
- `Memory.Allocation.Peak.Tracker` records a peak only when `Memory.Allocation.Peak.Tracker.sample()` is called. `Memory.Allocation.Peak.Tracker.track(sampleInterval:_:)` ignores `sampleInterval`, so an operation that never samples reports a peak of zero.
- `Memory.Allocation.Profiler` percentiles pick the sorted measurement at index count × p / 100, rounded down and clamped to the last one. The median of an even count is the upper of the two middle values. With no measurements, every statistic is zero.
- `Memory.Allocation.Histogram` splits the span from the smallest to the largest value into equal integer-width buckets, and the last bucket reaches the largest value. It traps when that span covers fewer than `buckets` minus one integers, such as a single measurement with the default 10 buckets.
