# DeskSway

A planned small macOS resident app for moving between Spaces with horizontal mouse scrolling while Mission Control is open.

**Stage 1 state detection passed on macOS 27.2 with one display**, using user-observed screen states matched to a running probe. See the [validation report](docs/phase1-validation.ja.md). Application implementation has not started. The only executable source here is the read-only [Mission Control probe](probes/mission-control/README.md). It does not intercept scrolling, send keys, take over the middle mouse button, or change other applications' settings.

The intended implementation uses Swift and native macOS facilities. No third-party dependency, network service, analytics, automatic updater, or enabled login item has been added. A public license has not yet been chosen. There is no remote repository or public release.

The public AX calls read undocumented system UI identifiers; compatibility with other OS versions and multiple displays is unverified. The report separates evidence, limits, and next-stage acceptance. Public license candidates are MIT (short and permissive), Apache-2.0 (explicit patent grant), and GPL-3.0 (source disclosure for distributed derivatives). No license has been selected.
