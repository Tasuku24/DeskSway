# Mission Control state feasibility probe

**Read-only diagnostic. Not a replacement app and never intercepts input.**

The stage 2 app now uses the same AX reader in `Sources/DeskSwayCore/MissionControlReader.swift`. See the [app README](../../README.md) for the local trial and its pending acceptance.

The macOS 27.2 single-display state checks have now been compared with user-observed screen states. See the [real-device validation report](../../docs/phase1-validation.ja.md) for successful cases, transient unknowns, measurements, and untested cases.

This temporary Swift program reads the Dock and WindowManager Accessibility trees every 200 ms. It observes their current state independently of which key or mouse button opened the overview. It installs no event tap, does not monitor or suppress input, posts no keys, and performs no AX UI actions. Existing BTT, Karabiner, Mos, and LinearMouse settings are untouched. There is no network access, analytics, update service, login item, or external package dependency.

## Build and run

Requires macOS, Xcode or its command line tools, and Swift. This probe has been compiled and executed only on macOS 27.2 (26B123), arm64, Xcode 27.2, Swift 6.4.2. That is execution evidence, not a complete compatibility claim.

In Terminal, change directory to this folder, then run:

```sh
./run.sh 180
```

The number is the observation duration in seconds; it defaults to 180. Stop early with Control-C. It exits automatically at the time limit, subject to synchronous AX call delays. A fresh binary is built in `.build/`. Console output is not written to a file unless you explicitly redirect it. Do not commit logs or the binary.

## Permission

Accessibility access is required for the process responsible for the executable. During the Codex-hosted run, `AXIsProcessTrusted()` was true and AX reads succeeded without changing permissions. This does not establish permission for a later Terminal run or standalone app.

If output reports `state=unknown accessibilityPermissionMissing`, this is a permission failure, not a closed Mission Control. If you choose to grant access, use System Settings → Privacy & Security → Accessibility for the host/executable identified by macOS, then rerun. The probe does not prompt, grant permission, or modify TCC. Input Monitoring and Screen Recording are not required by this probe.

## Meaning of output

- `missionControl`: a populated `mc.display` or `mc` group was observed. This is a candidate signature requiring visual validation.
- `appExpose`: a populated `appexpose.display` group was observed. New environments still need visual validation; see the report for this machine's results.
- `inactiveCandidate`: both hosts could be read without an AX error and neither signature was found. It is deliberately not a guarantee that the overview is closed; an OS schema change could remove both signatures.
- `unknown`: permission missing, host process missing, AX read failure, traversal limit, or conflicting signatures. Never interpret it as inactive.

The source reads role, identifier, and children only. It does not request titles, text values, screenshots, URLs, or keyboard content. Output contains elapsed time, duration of the AX scan, counts, allowlisted structural identifiers, and numeric AX errors. App/window thumbnail identifiers are not printed. A heartbeat is printed every five seconds and changes are printed immediately after the detecting scan.

The traversal is bounded to 200 nodes and depth 4, with a 150 ms AX messaging timeout on each visited element. This is a diagnostic limit, not a guarantee on total scan latency: multiple calls may delay a poll. No input-handling logic should run on this polling thread in the app.

## API and compatibility boundary

`AXIsProcessTrusted`, `AXUIElementCreateApplication`, `AXUIElementCopyAttributeValue`, and `AXUIElementSetMessagingTimeout` are public ApplicationServices APIs. The strings `mc.display`, `mc.spaces.list`, and `appexpose.display`, their structure, and the responsible host process are undocumented system UI details. There is no claim of an Apple-supported Mission Control state property. No private CGS/SkyLight symbols are used. The current probe is intended for macOS 27; older versions are untested, including their App Exposé signatures.

Sources:

- [Apple: AXUIElementCopyAttributeValue and its failure codes](https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue)
- [Apple: AXIsProcessTrusted](https://developer.apple.com/documentation/applicationservices/1460720-axisprocesstrusted)
- [Hammerspoon issue #3897: macOS 27 host change](https://github.com/Hammerspoon/hammerspoon/issues/3897)
- [MissionClose detection implementation](https://github.com/beqaabu/MissionClose/blob/main/Sources/MissionControl.swift), source blob `c1f0ed8da1c17728c55b58190e581e2f30101af3` reviewed 2026-11-03. Its separate private Space-ID functions were not reused.
- [MissionClose MIT license](https://github.com/beqaabu/MissionClose/blob/main/LICENSE)

The probe was written separately using public platform APIs; no third-party source or binary is bundled. MissionClose was reviewed for the observed identifiers and known platform change. This project's public license has not been selected. Suggested choices: MIT for easy reuse and a short license, Apache-2.0 for an explicit patent grant, or GPL-3.0 if distributing derivative versions should require source disclosure. Do not add a final license until the owner chooses.

## Visual acceptance procedure — for reproduction

Keep BTT enabled: this probe cannot double-trigger a Space move. Do not change Mos, LinearMouse, Karabiner, or shortcuts. Run from a visible Terminal so the output can be checked after each action. Allow five seconds in each steady state. Record what was visibly on screen alongside the corresponding `t=` lines; key history alone is insufficient.

1. Start on an ordinary desktop. Confirm the screen is not an overview and the output is `inactiveCandidate`.
2. Use the real mouse middle button to open Mission Control outside Fusion. Confirm Mission Control visually, note whether the output becomes `missionControl`, then close with Escape and verify recovery.
3. Open with the existing Control+Option+Shift+Command+Up shortcut. Repeat the same visual and log comparison. This checks an opening path independent of the middle button.
4. Leave Mission Control open and use the existing left/right Space shortcuts (Control+Option+Shift+Command+A / S) or the already-configured BTT horizontal wheel. Move to an adjacent Space and back. Check that the overview visibly stays open and that state is continuously `missionControl`. Absence of transition lines means the signature did not change, but requires the visual observation as its counterpart.
5. Close and verify recovery. Open App Exposé with the existing Control+Option+Shift+Command+Down shortcut while an app with windows is active. Confirm it visually. Expected signature is `appExpose`, never `missionControl`. Close and check recovery. A failure to open App Exposé is an unperformed test, not successful distinction.
6. Repeat open/close ten times by both opening routes. At each stable endpoint verify the screen and state. Record any `unknown`, false-positive or missed transition.
7. When convenient, use a disposable app/window for a fullscreen test: enter fullscreen through its standard control, open Mission Control, observe, switch to another existing Space and back, then close. Restore the disposable window afterward. Do not alter documents to create this test.
8. Multiple displays: only one logical display was available to this run. If additional displays become available, repeat with each display focused, with both overviews and cross-Space movement. Record the existing “Displays have separate Spaces” configuration; do not change it for testing.
9. Permission changes, Dock/WindowManager restarts, lock/unlock and sleep/wake are additional pending recovery checks. Do not revoke permissions used by other tools during unrelated work. Permission revocation tests need a later isolated host/app.

For latency, record visible transition onset and the first matching output against a common time reference. `scanMS` is the read time, not end-to-end latency. A 200 ms polling target also does not establish a measured 200 ms bound.

The Stage 2 gate requires screen/log comparison establishing Mission Control vs App Exposé distinction, reliable open/close recovery, and stable state during Space changes. Those basic state checks passed in the macOS 27.2 single-display run documented in the report; the separate stage 2 app implements input interception, but physical-mouse acceptance is pending. Consult the owner before proceeding if private APIs prove necessary or the supported public-API/undocumented-schema boundary is unacceptable.

## Stop and remove

Control-C stops the probe; it has no persistence or background service. Delete this folder to remove its source and `.build` binary. Any Accessibility permission granted manually can be removed manually afterward. No other app or configuration needs to be removed.
