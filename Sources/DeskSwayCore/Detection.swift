import Foundation

public enum OverviewState: String { case missionControl, appExpose, inactiveCandidate, unknown }
public struct Detection {
    public var state: OverviewState
    public var observedAt: TimeInterval
    public init(state: OverviewState, observedAt: TimeInterval) { self.state = state; self.observedAt = observedAt }
    public static let unknown = Detection(state: .unknown, observedAt: -.infinity)
}
