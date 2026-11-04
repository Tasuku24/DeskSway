# Unified settings and input recording

Scope: User requested one settings window, direct shortcut entry, and actual horizontal-scroll registration after reporting non-working conversion. Continue on main; preserve existing settings. Root cause of the live failure is not yet established; separate permission/readiness statuses and observed input are required evidence, not an assumption that permissions or direction are wrong.

Architecture: Existing SettingsStore persists shortcuts plus a validated scroll mapping. ScrollPolicy consumes that mapping, allowing phase-bearing input only after explicit registration and preserving one action per gesture. A short-lived recording tap intercepts key down/up only during explicit shortcut capture in the foreground settings window; scroll capture uses the same tap location as conversion. Unified AppKit settings owns recording UI, live permissions, run/pause, save and close. Runtime conversion stays paused while settings is open.

Invariants: Never emit Space shortcuts while recording. After cancellation, deactivation, close or timeout, accept no new recording; drain only already-swallowed keys until release, then remove the tap. The UI explicitly states this boundary. Swallow recorded key-down and corresponding key-up so existing system shortcuts do not execute. Ignore modifier-only/repeat input, reject duplicates. Horizontal capture rejects vertical/momentum input; sign and phase kind drive runtime matching. Existing valid settings migrate; corrupted mappings fail open. No permission changes without user action. No BTT or mouse utility setting changes.

- [x] Add failing behavior tests for recorder key pairs, mapping validation/persistence, reversed direction, recorded phased gestures, inertia and detection-loss boundaries.
- [x] Implement core model and recording decisions; run suite.
- [x] Integrate transient input recording and unified settings with per-permission status; open settings on launch/reopen.
- [x] Build, review independently, address important findings with regressions, restart local app to settings and inspect UI where available.
- [x] Update usage/validation docs; report any physical-input checks still pending.

Outcome: 37 tests pass; independent review finding about held-key cancellation fixed RED→GREEN. Unified settings and missing-permission handling visually inspected. Physical recording/Space moves are pending OS reauthorization. TCC logs confirmed a previous-grant/current-code requirement mismatch. No TCC/security setting edits performed. Same bundle location retained; main remains uncommitted.
