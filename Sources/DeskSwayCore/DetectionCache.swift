import Foundation

// Owned exclusively by the main thread. A generation invalidates in-flight AX reads.
public struct DetectionCache {
    public private(set) var generation: UInt64 = 0
    public private(set) var detection = Detection.unknown
    public init() {}
    public mutating func invalidate() { generation &+= 1; detection = .unknown }
    public mutating func accept(_ result: Detection, generation: UInt64) {
        guard generation == self.generation else { return }
        detection = result
    }
}
