# Settings UI design QA

Reviewed 2026-11-05 using Product Design image-to-code and design-qa workflows, adapted to native AppKit.

## Reference and scope

Selected concept 1 is `/Users/s26037/.codex/generated_images/01a1a7e1-ed84-7323-834d-eb15a921caf6/exec-2d1d7efc-f0c8-4aa6-8588-6b3b25e87138.png`.

The reference and live `.build/DeskSway.app` screenshot were displayed together in the development chat. Comparison used the window content, accounting for Retina scale, reference outer margins, and actual settings state. Default window content is 740 × 560 points, with a minimum of 740 × 560.

## Visual review

- Typography passed. Native system text gives clear title, section, control, and helper hierarchy. Japanese labels and shortcut symbols are readable.
- Layout passed. Input columns align, section separators and margins are consistent, and footer actions remain outside the scrolling content. Initial helper clipping and excessive permission-summary spacing were corrected and recaptured.
- Color passed. Graphite artwork anchors the header. Buttons use regular-size AppKit controls, default bezel colors, and the system accent, and permission warnings use orange with symbols and accessible descriptions.
- Assets passed. The bundled Graphite icon appears sharply in the header. Native permission symbols carry state.
- Copy passed. Actual shortcut and scroll values are displayed. The live permission and detection statuses reflect the running app. Current delay is 0.00 seconds. These state-dependent labels intentionally differ from the mockup.

## Interaction and verification

- Live details expansion exposes all permission actions and enables scrolling. Collapse restores the compact summary.
- Live reset changed the draft delay to 0.60 seconds. Discard restored the saved 0.00 seconds.
- Automated tests cover draft preservation through disclosure, save-failure feedback, and footer/document layout at regular and minimum window sizes under light and dark appearances.
- All 52 tests passed. Release app build and signature verification passed.
- Existing save, recording, close, and quit handlers are reused by the redesigned controls.

## Remaining verification limits

After the ad-hoc rebuild, macOS reports Accessibility, Input Monitoring, and key posting permissions as unrecognized. Permission recovery requires user action. Physical input recording and Space movement remain unverified on this build. Live dark appearance and VoiceOver navigation were not tested.

## Final result

Passed for the reviewed light-appearance design and settings interactions. Runtime permission recovery and physical input validation remain open.

## Native appearance revision

Following user feedback, regular AppKit buttons and platform-sized control fonts replace large controls. Explicit button tint overrides were removed. Recording buttons, header artwork, title, section headings, row heights, and spacing are more compact. The default action uses the system accent. The rebuilt app was opened and visually inspected at 740 × 560 points. Labels and footer actions are visible. All 52 tests and the signed release build passed again. Permission recognition remains unresolved.

Final result: passed for this native appearance revision.

## Localization and scroll-free revision

The latest user requirements supersede the earlier scrolling layout. Settings now use a plain view with an 800 × 600-point minimum. Opening permission details replaces the input sections in place. Closing details restores those sections and their draft values. Footer actions remain visible in both views.

All 99 UI strings, including menus, recording feedback, validation messages, permission statuses, tooltips, and accessibility labels, have English and Japanese resource entries. AppKit/Foundation selects the preferred supported language. English is the development fallback. Both app and resource bundles declare localization support.

Live English and Japanese settings screenshots were inspected. The English details view was also inspected with every permission action visible. Neither view contains a scroll area or scrollbar. Temporary launch-only language overrides were used for verification, then the app was relaunched normally. The system preference order is en-JP followed by ja-JP, and normal launch shows English.

The resource key sets and all format placeholders match. The 52-test suite passes, including no-scroll-view and visible-button layout checks. Release build and signature verification pass. Language-specific xctest command attempts were unsupported and are excluded from this evidence. Live language verification used the actual app instead.

Normal launch still reports permissions as unrecognized. Physical input conversion and live dark-mode appearance remain outside this verification.

Final result: passed for bilingual UI and scroll-free settings.

## Native tabs and manual language selection

The settings window now uses an AppKit NSTabView with General and Permissions tabs. General contains input settings and a Language popup. Permissions contains the status summary and permission actions. Both tabs were inspected in the running app, with no scroll views. Minimum window size is 800 × 700 points.

Language options are Follow System Settings, 日本語, and English. The selection is a draft until Save succeeds. Discard/close protection includes language changes. Language resources are resolved once per launch so all app-owned UI uses one language. The inline instruction explains that saving and restarting applies the selection.

Verified the full native interaction from system-following English to Japanese via selection, Save, and Restart App. Verified returning to Follow System Settings via the same path. The final app is running in system-following mode. Added regression coverage for successful/failed language saves and updated tab draft-preservation/layout tests. All 53 tests passed, as did the release build and signing.

Final result: passed for tabs and manual language switching. Permission recovery and physical input verification remain open.
