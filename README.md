# DeskSway

A small native macOS menu-bar app that turns horizontal wheel-style scrolling into Space shortcuts while Mission Control is detected. Swift, AppKit and public ApplicationServices APIs; no external packages, network service, analytics, updater or automatic login item.

**Stage 2 local trial implemented; physical-mouse acceptance is still pending.** The [stage 1 report](docs/phase1-validation.ja.md) establishes state detection on macOS 27.2, Apple Silicon, one display. The [stage 2 report](docs/stage2-validation.ja.md) separates automated checks from outstanding real-device, permission, UI and resource measurements.

## Build and run

The current build was checked with Xcode 27.2 / Swift 6.4.2 on macOS 27.2, arm64. The package's deployment floor is macOS 14; that is **not** a compatibility claim for older OS versions or Intel. Detection relies on undocumented system UI structure and is currently only validated on macOS 27.2 with one display.

```sh
swift test
./scripts/build-app.sh
open .build/DeskSway.app
```

The script creates `.build/DeskSway.app` with a local ad-hoc signature, without personal signing information. It is not Developer ID signed or notarized. Rebuilding may require regranting app permissions. Keep the app at a stable location when testing permissions; if you move it to Applications, quit the previous copy first. Only run one copy at a time.

## First use

1. Launching DeskSway when it is not running starts it in the menu bar without opening settings. Open the app again while it is running, or choose **設定…** from its menu, to show settings on the current Space (including bringing an existing settings window there). **Command-W** closes settings; **Command-Q** quits DeskSway while the app is focused. Unsaved changes require confirmation before closing or quitting. Conversion continues while settings is open; only explicit input recording temporarily blocks conversion. The **動作** section shows the saved run/pause choice and current Mission Control detection.
2. Check the separate Accessibility, Input Monitoring and key-posting permission statuses. Use **システム設定を開く…** for Accessibility/Input Monitoring and **キー送信を許可…** for the dedicated event-posting request. **権限を再確認**, **アプリを再起動**, and **アプリの場所を表示** are in the same window. Only a user-initiated permission action requests access. Screen Recording is not used.
3. For each direction, click **キーを記録** and physically press/release the same shortcut configured for macOS “Move left/right a space.” This records the shortcut directly without changing system shortcuts. Modifier-only input is ignored; unsupported/bare keys and duplicate left/right shortcuts are rejected. Existing shortcut preferences are preserved.
4. Click each **横入力を記録** button and operate the actual mouse horizontally in the direction you want to mean left/right. Keep the pointer over the settings window. The received sign and wheel/gesture format are shown and saved; both directions must be opposite signs of the same format. Vertical-dominant and momentum input do not register. No Space shortcuts are posted during recording.
5. In **連続入力**, adjust **次の入力までの待ち時間** from 0.00–2.00 seconds in 0.05-second steps (default 0.60). A shorter value accepts repeated horizontal input sooner; 0 seconds removes the wait and accepts every eligible event. **標準に戻す** restores 0.60 seconds. Click **保存** (Command-S) to apply shortcuts, scroll mapping and waiting time together while leaving settings open, or **保存して閉じる** to save and close. Saved changes apply while settings remains open, so you can test them immediately. Unsaved edits do not affect conversion. **変更を破棄して閉じる** leaves the saved configuration unchanged. Make sure BTT is quit before running, and test both directions with your physical mouse. Leave Mos, LinearMouse and Karabiner settings unchanged.
6. Use **一時停止** or **DeskSwayを終了** to stop. Restore BTT only after DeskSway is paused or stopped.

**Permission troubleshooting:** Key posting uses `CGRequestPostEventAccess`; requesting Accessibility alone is not a substitute for that request. If Accessibility and Input Monitoring are recognized but key posting is not, use **キー送信を許可…** and follow macOS’s instructions, then recheck/restart if needed. An enabled switch in System Settings does not guarantee that the current binary is authorized. During this trial, macOS explicitly logged a code-requirement mismatch between a previous DeskSway grant and the rebuilt ad-hoc binary. If the app still reports missing permission, remove the old DeskSway entry from the affected privacy list, add the current app shown by **アプリの場所を表示**, grant access, then restart. Do this yourself in System Settings; DeskSway never changes TCC records or bypasses authorization. Ad-hoc rebuilds can require repeating this step. A stable certificate-backed signing setup is not included in this local trial.

The run/pause choice and shortcuts are saved locally in standard Preferences under `local.DeskSway`. Settings are never written to the repository. Opening settings does not stop conversion; unsaved changes require confirmation before closing. On later launches the prior run preference is restored, but conversion still waits for all readiness conditions. Login at startup is not enabled; you can add the app through macOS Login Items yourself if wanted.

## Input protection and limits

- Runtime conversion taps scroll events only. Explicit shortcut recording temporarily taps key down/up in the foreground settings window; it stores one key code and modifier set, never text. Input waiting times out after 15 seconds and focus loss cancels new recording. Cancellation drains only already-swallowed keys until release, including their repeats, before removing the tap; unrelated keys pass through and are not recorded. Restart/quit waits for these held keys to be released. Clicks and middle-button actions are untouched. Generated events are one configured key-down/up pair.
- Conversion requires running state, valid settings, Accessibility, listen/post access, an enabled tap, and a Mission Control observation no more than 500 ms old. All other states pass input through, including App Exposé, unknown, stale detection, pause and missing permissions.
- AX reads run on a separate serial queue with a 200 ms polling target, a 150 ms timeout on **each** AX element, depth 4 and 200-node limits per host. Observation age starts before the scan, not at completion. Sleep/session and relevant process changes invalidate pending results. Multiple AX calls can exceed the poll interval. There is an unavoidable observation window after MC closes; 500 ms is a freshness bound, not a measured detection delay.
- Eligible horizontal input can repeat within the same wheel burst or recorded gesture after the configured waiting time (0.00–2.00 seconds, default 0.60). The interval is measured from the last generated shortcut, so intervening input does not extend it. During the wait only matched horizontal components are suppressed. Each movement needs a new actual input event: there is no repeat timer, queued movement or catch-up after silence. Zero input and momentum never cause another movement.
- Detection/permission loss still interrupts the stream. A wheel stream needs 250 ms without horizontal input before it can resume; a recorded gesture needs a new begin event. This safety reset is separate from the normal repeat interval.
- Vertical-dominant input passes intact. Mixed horizontal-dominant input retains all vertical and third-axis fields while only horizontal fields are cleared. Failures to prepare replacement/key events leave the original event intact. The public posting API provides no acknowledgement that macOS acted on a shortcut.
- **Public CGEvents do not authenticate a physical device.** Defaults accept phase-less wheel-style events, including continuous ones from some mouse smoothers. Recording a phase-bearing input explicitly enables that gesture format. The same format from a trackpad cannot be distinguished from the recorded mouse; momentum always passes without generating a shortcut. A smoother that drops gesture/momentum metadata cannot be reliably distinguished from a new wheel burst; compatibility with Mos/LinearMouse and the user's real mouse remains to be tested. Do not treat this as an absolute hardware-mouse filter.
- A disabled tap clears detection and is retried with permissions checked, at most every two seconds. Missing permissions can require an app restart. No working permission-recovery or multi-display claim is made before real-device testing.

## Development and removal

`Sources/DeskSwayCore` owns input policy, shortcut validation, CGEvent preparation and the shared AX reader. `Sources/DeskSway` owns the unified settings, short-lived recorder, main-thread menu, runtime event tap and lifecycle; AX IPC runs separately. The [read-only probe](probes/mission-control/README.md) uses the same reader but does not link the input adapter or install a tap. Tests construct events but never post them.

To remove the app, quit it and remove the built `.app`. Remove any permission or login-item entries you added through System Settings. Preferences may be retained; deleting the `local.DeskSway` preferences domain separately resets local settings. No background helper, launch agent or service is installed.

Source and trial work remain local in this task; no push or release was performed. A Git remote may already be configured. A public license has not been selected, and no LICENSE file is added. Do not treat the local ad-hoc build as a signed distribution.
