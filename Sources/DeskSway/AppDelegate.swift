import AppKit
import ApplicationServices
import DeskSwayCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = SettingsStore()
    private let detector = DetectionMonitor()
    private let input = InputMonitor()
    private var statusItem: NSStatusItem!
    private let status = NSMenuItem(title: "一時停止中", action: nil, keyEquivalent: "")
    private let toggle = NSMenuItem(title: "実行", action: #selector(toggleRunning), keyEquivalent: "")
    private var settingsWindow: SettingsWindow?
    private var requestedRunning = false
    private var suspended = false
    private var permissionGranted = false
    private var bttRunning = false
    private var heartbeat: Timer?
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestedRunning = settings.running
        NSApp.setActivationPolicy(.accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "DeskSway")
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
        toggle.target = self; menu.addItem(toggle)
        add("設定…", #selector(showSettings), to: menu)
        menu.addItem(.separator())
        add("DeskSwayを終了", #selector(quit), to: menu, key: "q")
        statusItem.menu = menu
        input.configuration = settings.configuration
        input.gate = { [weak self] in
            guard let self else { return InputGate(running: false, permissionsGranted: false, tapEnabled: false, settingsValid: false, detection: .unknown) }
            return InputGate(running: self.requestedRunning && self.settingsWindow?.isRecording != true && !self.suspended && !self.bttRunning,
                             permissionsGranted: self.permissionGranted, tapEnabled: self.input.isEnabled,
                             settingsValid: self.input.configuration?.isValid == true, detection: self.detector.detection)
        }
        input.onDisabled = { [weak self] in self?.detector.invalidate() }
        observeLifecycle()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common); heartbeat = timer
        showSettings()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(); return true
    }
    private func add(_ title: String, _ selector: Selector, to menu: NSMenu, key: String = "") {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self; menu.addItem(item)
    }
    func menuWillOpen(_ menu: NSMenu) { refresh() }
    @objc private func refresh() {
        // Evaluate independently: a combined boolean hid WHICH permission failed.
        let accessibility = AXIsProcessTrusted()
        let listening = CGPreflightListenEventAccess()
        let posting = CGPreflightPostEventAccess()
        permissionGranted = accessibility && listening && posting
        bttRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.hegenberg.BetterTouchTool").isEmpty
        let active = requestedRunning && !suspended && !bttRunning && permissionGranted && input.configuration?.isValid == true
        detector.setActive(accessibility && !suspended && (requestedRunning || settingsWindow?.window?.isVisible == true))
        // Keep observing scrolls during recording; the per-event gate blocks
        // conversion and prevents resuming in the middle of a recorded gesture.
        input.reconcile(active: active)
        toggle.title = requestedRunning ? "一時停止" : "実行"
        let label: String
        if !requestedRunning { label = "一時停止中" }
        else if settingsWindow?.isRecording == true { label = "入力を記録中 — 変換を一時停止" }
        else if suspended { label = "休止中 — 入力を通過" }
        else if bttRunning { label = "BTTを終了してください" }
        else if input.configuration == nil { label = "設定を確認してください" }
        else if !accessibility { label = "アクセシビリティが未認識" }
        else if !listening { label = "入力監視が未認識" }
        else if !posting { label = "キー送信の許可が未認識" }
        else if !input.isEnabled { label = "入力監視を再試行中" }
        else if input.gate().permits(at: ProcessInfo.processInfo.systemUptime) { label = "Mission Control — 変換有効" }
        else { label = "待機中 — 入力を通過" }
        status.title = label
        statusItem.button?.toolTip = "DeskSway: \(label)"
        statusItem.button?.appearsDisabled = !requestedRunning
        let age = ProcessInfo.processInfo.systemUptime - detector.detection.observedAt
        let state: String
        if !accessibility { state = "アクセシビリティの許可待ち" }
        else if age < 0 || age > 0.5 { state = "新しい検知結果を待っています" }
        else {
            switch detector.detection.state {
            case .missionControl: state = "Mission Controlを検知"
            case .appExpose: state = "App Exposé（変換対象外）"
            case .inactiveCandidate: state = "通常画面（変換対象外）"
            case .unknown: state = "判定できません（入力を通過）"
            }
        }
        settingsWindow?.update(SettingsStatus(running: requestedRunning, accessibility: accessibility,
                                              listening: listening, posting: posting,
                                              summary: bttRunning ? "BTTを終了してください" : label, detection: state))
    }
    @objc private func toggleRunning() {
        requestedRunning.toggle()
        settings.running = requestedRunning
        detector.invalidate(); input.reset(); refresh()
    }
    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = SettingsWindow()
            window.onSave = { [weak self] configuration in
                guard let self else { return }
                try self.settings.save(configuration)
                self.input.configuration = configuration
                self.input.reset(); self.detector.invalidate()
            }
            window.onClose = { [weak self] in
                self?.refresh()
            }
            window.onToggleRunning = { [weak self] in self?.toggleRunning() }
            window.onAccessibility = { [weak self] in self?.requestAccessibility() }
            window.onInputMonitoring = { [weak self] in self?.requestInputMonitoring() }
            window.onPosting = { [weak self] in self?.requestPosting() }
            window.onRefresh = { [weak self] in self?.refresh() }
            window.onRestart = { [weak self] in self?.restart() }
            settingsWindow = window
        }
        settingsWindow?.present(settings.configuration)
        refresh()
    }
    @objc private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacy("Privacy_Accessibility")
    }
    @objc private func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        openPrivacy("Privacy_ListenEvent")
    }
    @objc private func requestPosting() {
        // Post-event access has its own request API; AX prompting alone does
        // not request this permission even when AXIsProcessTrusted is true.
        let granted = CGRequestPostEventAccess()
        refresh()
        settingsWindow?.showPostingRequestResult(granted: granted)
    }
    private func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }
    private func restart() {
        input.stop(); settingsWindow?.stopRecording()
        guard settingsWindow?.isDrainingKeys != true, let executable = Bundle.main.executableURL else { return }
        // A small mode of this executable waits until this instance has exited.
        // Launching another GUI instance before termination lost its window on
        // this OS, so relaunch only after the old process is gone.
        let helper = Process()
        helper.executableURL = executable
        helper.arguments = ["--relaunch-after", String(ProcessInfo.processInfo.processIdentifier)]
        do { try helper.run(); NSApp.terminate(nil) }
        catch { let alert = NSAlert(error: error); alert.runModal() }
    }
    @objc private func quit() { NSApp.terminate(nil) }
    private func observeLifecycle() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.suspended = true; self?.detector.invalidate(); self?.refresh()
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.suspended = false; self?.detector.invalidate(); self?.input.reset(); self?.refresh()
            })
        }
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      ["com.apple.dock", "com.apple.WindowManager", "com.hegenberg.BetterTouchTool"].contains(app.bundleIdentifier ?? "") else { return }
                self?.detector.invalidate(); self?.input.reset(); self?.refresh()
            })
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        settingsWindow?.stopRecording()
        heartbeat?.invalidate()
        detector.setActive(false); input.stop()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        settingsWindow?.stopRecording()
        return settingsWindow?.isDrainingKeys == true ? .terminateCancel : .terminateNow
    }
}
