# Configurable continuous-input interval

User request: continuous input is blocked; make the input waiting time adjustable. Main remains the working branch.

Trace: the previous policy waited 600 ms between moves but also consumed a wheel burst or phase-bearing gesture after its first movement, so merely exposing 600 ms would not satisfy continuous input.

Decision: one `repeatInterval` preference, 0.10–2.00 s, default 0.60 s. A new non-momentum horizontal event after that interval can issue the next movement, within the same burst/gesture too. No timers or deferred movements. Vertical input passes; detection/permission loss still interrupts the stream and requires a fresh wheel burst/gesture. During the waiting interval, matched horizontal components are suppressed while vertical components remain. This intentionally supersedes the old one-movement-per-gesture restriction.

Implementation: extend existing InputConfiguration with validated persistence and absent-field migration; route the value through InputMonitor and ScrollEventAdapter to ScrollPolicy. Add one labeled slider/value/reset row to unified settings. Save/discard uses the existing draft flow.

Proof: regression tests for short/long intervals, exact boundaries, continuous wheel and phased input, momentum/zero input, gate loss, real CGEvent key preparation, legacy migration, persistence and invalid values. Existing tests describing one-movement-per-gesture are revised to the explicitly requested behavior. Verify native UI display and slider/save flow; physical acceptance remains distinct.

Outcome: implemented on main; all 46 tests passed; release/ad-hoc verification passed. Independent review had no actionable findings. Native UI verified slider 0.20 seconds and reset to 0.60; left open at default without changing saved user configuration. Permission recognition was lost after the ad-hoc rebuild, so physical mouse acceptance awaits user reauthorization. No permission, BTT, or mouse-utility changes; no commit or push.
