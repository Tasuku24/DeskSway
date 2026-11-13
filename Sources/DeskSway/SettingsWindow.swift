import AppKit
import DeskSwayCore
import ServiceManagement

private final class SettingsContentStack: NSStackView {
    override var isFlipped: Bool { true }
}

struct SettingsStatus {
    var running: Bool
    var accessibility: Bool
    var listening: Bool
    var posting: Bool
    var summary: String
    var detection: String
    var loginItem: SMAppService.Status = .notRegistered
}

final class SettingsWindow: NSWindowController, NSWindowDelegate {
    var onSave: ((InputConfiguration) throws -> Void)?
    var onClose: (() -> Void)?
    var onToggleRunning: (() -> Void)?
    var onAccessibility: (() -> Void)?
    var onInputMonitoring: (() -> Void)?
    var onPosting: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onRestart: (() -> Void)?
    var onSetLaunchAtLogin: ((Bool) throws -> Void)?
    var onOpenLoginItems: (() -> Void)?
    private let recorder = InputRecorder()
    private var draft = InputConfiguration.standard
    private var original: InputConfiguration?
    private var target: SpaceDirection = .left
    private var discarding = false
    private let summary = NSTextField(wrappingLabelWithString: "")
    private let detection = NSTextField(labelWithString: "")
    private let runSwitch = NSSwitch()
    private let loginSwitch = NSSwitch()
    private let loginStatus = NSTextField(wrappingLabelWithString: "")
    private let loginSettings = NSButton(title: L("ログイン項目を開く…"), target: nil, action: nil)
    private let permissionDetails = NSStackView()
    private let inputSections = NSStackView()
    private let tabs = NSTabView()
    private let languagePicker = NSPopUpButton()
    private var originalLanguage = InterfaceLanguage.saved
    private var selectedLanguage = InterfaceLanguage.saved
    private let permissionIndicators = [NSImageView(), NSImageView(), NSImageView()]
    private let leftScrollValue = NSTextField(labelWithString: "")
    private let rightScrollValue = NSTextField(labelWithString: "")
    private let axStatus = NSTextField(labelWithString: L("確認中"))
    private let listenStatus = NSTextField(labelWithString: L("確認中"))
    private let postStatus = NSTextField(labelWithString: L("確認中"))
    private let leftKey = NSButton(title: "", target: nil, action: nil)
    private let rightKey = NSButton(title: "", target: nil, action: nil)
    private let leftScroll = NSButton(title: "", target: nil, action: nil)
    private let rightScroll = NSButton(title: "", target: nil, action: nil)
    private let message = NSTextField(wrappingLabelWithString: "")
    private let cancelRecord = NSButton(title: L("記録を中止"), target: nil, action: nil)
    private let repeatSlider = NSSlider(value: InputConfiguration.defaultRepeatInterval,
                                       minValue: InputConfiguration.repeatIntervalRange.lowerBound,
                                       maxValue: InputConfiguration.repeatIntervalRange.upperBound,
                                       target: nil, action: nil)
    private let repeatValue = NSTextField(labelWithString: "")

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 700),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = L("DeskSway — 設定")
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 800, height: 700)
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        super.init(window: window)
        window.delegate = self
        buildContent(window)
        recorder.onMessage = { [weak self] value in self?.setMessage(value, error: true) }
        recorder.onStopped = { [weak self] in self?.cancelRecord.isHidden = true }
        recorder.onShortcut = { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .shortcut(let shortcut):
                if self.target == .left { self.draft.shortcuts.left = shortcut } else { self.draft.shortcuts.right = shortcut }
                self.refreshBindings()
                self.setMessage(L("%@のキーを記録しました。保存して反映してください。", self.targetName))
            case .invalid: self.setMessage(L("修飾キー（Control・Option・Shift・Command）とキーを同時に押してください。"), error: true)
            case .cancelled: self.setMessage(L("記録を中止しました。"))
            }
        }
        recorder.onScroll = { [weak self] binding in
            guard let self else { return }
            if self.target == .left { self.draft.scrollMapping.left = binding } else { self.draft.scrollMapping.right = binding }
            self.refreshBindings()
            self.setMessage(L("%@の横入力を受信しました（%@）。左右とも記録して保存してください。", self.targetName, self.scrollLabel(binding)))
        }
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var targetName: String { target == .left ? L("左") : L("右") }
    private func buildContent(_ window: NSWindow) {
        guard let content = window.contentView else { return }
        let title = NSTextField(labelWithString: "DeskSway")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        summary.font = .systemFont(ofSize: 13, weight: .regular)
        summary.textColor = .secondaryLabelColor
        detection.font = .systemFont(ofSize: 12)
        detection.textColor = .secondaryLabelColor
        detection.lineBreakMode = .byTruncatingTail
        let identity = vertical([title, summary, detection], spacing: 5)
        let iconURL = Bundle.module.url(forResource: "DeskSway", withExtension: "icns")
        let icon = NSImageView(image: iconURL.flatMap { NSImage(contentsOf: $0) } ?? NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 48).isActive = true
        runSwitch.target = self
        runSwitch.action = #selector(toggleRun)
        runSwitch.setAccessibilityLabel(L("DeskSwayを有効にする"))
        let header = row([icon, identity, spacer(), NSTextField(labelWithString: L("有効")), runSwitch])
        header.spacing = 12
        header.heightAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true

        leftKey.target = self; leftKey.action = #selector(recordLeftKey)
        rightKey.target = self; rightKey.action = #selector(recordRightKey)
        leftScroll.target = self; leftScroll.action = #selector(recordLeftScroll)
        rightScroll.target = self; rightScroll.action = #selector(recordRightScroll)
        let columnHeadings = row([note(L("移動方向")), note(L("ショートカット")), note(L("横スクロール"))])
        columnHeadings.views[0].widthAnchor.constraint(equalToConstant: 130).isActive = true
        columnHeadings.views[1].widthAnchor.constraint(equalToConstant: 220).isActive = true
        let bindings = vertical([
            heading(L("入力")), columnHeadings, divider(),
            bindingRow(L("左のSpace"), key: leftKey, scroll: leftScroll, value: leftScrollValue),
            divider(),
            bindingRow(L("右のSpace"), key: rightKey, scroll: rightScroll, value: rightScrollValue)
        ], spacing: 14)

        repeatSlider.target = self
        repeatSlider.action = #selector(repeatIntervalChanged)
        repeatSlider.isContinuous = true
        repeatSlider.setAccessibilityLabel(L("次の入力までの待ち時間（秒）"))
        repeatSlider.toolTip = L("0.00〜2.00秒。0秒は待ち時間なし。0.05秒刻みで調整できます。")
        repeatValue.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        repeatValue.widthAnchor.constraint(equalToConstant: 86).isActive = true
        let timingRow = row([note(L("0.00 秒")), repeatSlider, note(L("2.00 秒")), repeatValue,
                             button(L("標準に戻す"), #selector(resetRepeatInterval))])
        repeatSlider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let timing = vertical([heading(L("連続入力")), note(L("次の入力までの待ち時間")), timingRow], spacing: 12)

        let names = [L("アクセシビリティ"), L("入力監視"), L("キー送信")]
        let summaries = zip(permissionIndicators, names).map { indicator, name in
            indicator.widthAnchor.constraint(equalToConstant: 18).isActive = true
            indicator.heightAnchor.constraint(equalToConstant: 18).isActive = true
            let label = NSTextField(labelWithString: name)
            label.font = .systemFont(ofSize: 13)
            return row([indicator, label])
        }
        let permissionSummary = row([heading(L("権限"))] + summaries + [spacer()])
        permissionSummary.spacing = 14
        permissionDetails.orientation = .vertical
        permissionDetails.alignment = .leading
        permissionDetails.spacing = 14
        let detailViews: [NSView] = [
            permissionRow(L("アクセシビリティ"), status: axStatus, action: #selector(accessibility)),
            permissionRow(L("入力監視"), status: listenStatus, action: #selector(inputMonitoring)),
            permissionRow(L("キー送信"), status: postStatus, action: #selector(posting), buttonTitle: L("キー送信を許可…")),
            note(L("許可が認識されない場合は、システム設定でこのアプリを再登録し、再起動してください。")),
            row([button(L("権限を再確認"), #selector(refresh)), button(L("アプリを再起動"), #selector(restart)),
                 button(L("アプリの場所を表示"), #selector(revealApp))])
        ]
        for view in detailViews {
            permissionDetails.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: permissionDetails.widthAnchor).isActive = true
        }


        cancelRecord.target = self
        cancelRecord.action = #selector(cancelRecording)
        cancelRecord.bezelStyle = .rounded
        cancelRecord.isHidden = true
        message.font = .systemFont(ofSize: 12)
        message.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let feedback = row([message, cancelRecord])
        feedback.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        inputSections.orientation = .vertical
        inputSections.alignment = .leading
        inputSections.spacing = 16
        languagePicker.addItems(withTitles: InterfaceLanguage.allCases.map(\.title))
        languagePicker.selectItem(at: InterfaceLanguage.allCases.firstIndex(of: selectedLanguage) ?? 0)
        languagePicker.target = self
        languagePicker.action = #selector(changeLanguage)
        languagePicker.setAccessibilityLabel(L("言語"))
        let language = vertical([
            row([NSTextField(labelWithString: L("言語")), languagePicker, spacer(),
                 button(L("アプリを再起動"), #selector(restart))]),
            note(L("言語の変更は保存後、アプリを再起動すると反映されます。"))
        ], spacing: 8)
        loginSwitch.target = self
        loginSwitch.action = #selector(toggleLaunchAtLogin)
        loginSwitch.setAccessibilityLabel(L("ログイン時に起動"))
        loginSettings.target = self
        loginSettings.action = #selector(openLoginItems)
        loginSettings.bezelStyle = .rounded
        loginSettings.isHidden = true
        loginStatus.font = .systemFont(ofSize: 12)
        loginStatus.textColor = .secondaryLabelColor
        let login = vertical([
            row([NSTextField(labelWithString: L("ログイン時に起動")), loginSwitch, spacer(), loginSettings]),
            loginStatus
        ], spacing: 8)
        for view in [bindings, divider(), timing, divider(), language, divider(), login] {
            inputSections.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: inputSections.widthAnchor).isActive = true
        }
        let permissions = vertical([permissionSummary, permissionDetails], spacing: 16)
        let tabHeight: CGFloat = 430
        // AppKit sizes inserted tab contents before the first Auto Layout pass.
        // Seed both tabs with real geometry, including the initially hidden tab.
        tabs.setFrameSize(NSSize(width: content.bounds.width - 56, height: tabHeight))
        for (title, body) in [(L("一般"), inputSections), (L("権限"), permissions)] {
            let item = NSTabViewItem(identifier: title)
            item.label = title
            let container = NSView(frame: tabs.contentRect)
            container.autoresizingMask = [.width, .height]
            body.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(body)
            NSLayoutConstraint.activate([
                body.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
                body.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                body.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
                body.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -16)
            ])
            item.view = container
            tabs.addTabViewItem(item)
        }
        tabs.heightAnchor.constraint(equalToConstant: tabHeight).isActive = true
        let stack = SettingsContentStack(views: [header, tabs, feedback])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 16, right: 28)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        for view in stack.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -56).isActive = true
        }

        let save = button(L("保存"), #selector(saveSettings))
        save.keyEquivalent = "s"
        save.keyEquivalentModifierMask = .command
        let footer = row([button(L("変更を破棄"), #selector(discardSettings)), spacer(), save])
        let footerRule = divider()
        for view in [footerRule, footer] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: footerRule.topAnchor, constant: -8),
            footerRule.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            footerRule.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            footerRule.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -16),
            footer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            footer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])
        refreshBindings()
    }

    private func heading(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: 13, weight: .semibold)
        return field
    }
    private func note(_ text: String) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: 13)
        field.textColor = .secondaryLabelColor
        return field
    }
    private func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        return stack
    }
    private func vertical(_ views: [NSView], spacing: CGFloat) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        for view in views { view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        return stack
    }
    private func spacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }
    private func divider() -> NSBox {
        let line = NSBox()
        line.boxType = .separator
        return line
    }
    private func button(_ title: String, _ action: Selector) -> NSButton {
        let control = NSButton(title: title, target: self, action: action)
        control.bezelStyle = .rounded
        control.controlSize = .regular
        control.font = .systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        return control
    }
    private func permissionRow(_ label: String, status: NSTextField, action: Selector,
                               buttonTitle: String = L("システム設定を開く…")) -> NSStackView {
        let name = NSTextField(labelWithString: label)
        name.widthAnchor.constraint(equalToConstant: 150).isActive = true
        status.font = .systemFont(ofSize: 13)
        status.widthAnchor.constraint(equalToConstant: 180).isActive = true
        return row([name, status, spacer(), button(buttonTitle, action)])
    }
    private func bindingRow(_ label: String, key: NSButton, scroll: NSButton, value: NSTextField) -> NSStackView {
        let name = NSTextField(labelWithString: label)
        name.font = .systemFont(ofSize: 13, weight: .regular)
        name.widthAnchor.constraint(equalToConstant: 130).isActive = true
        key.bezelStyle = .rounded
        key.controlSize = .regular
        key.font = .systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        key.widthAnchor.constraint(equalToConstant: 150).isActive = true
        let keyCell = row([key, spacer()])
        keyCell.widthAnchor.constraint(equalToConstant: 220).isActive = true
        scroll.bezelStyle = .rounded
        scroll.controlSize = .regular
        scroll.font = .systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        value.font = .systemFont(ofSize: 12)
        value.textColor = .secondaryLabelColor
        key.setAccessibilityLabel(L("%@のショートカットを直接記録", label))
        key.toolTip = L("macOSのSpace移動と同じキーを記録します。入力待ちは15秒、Escで中止。")
        scroll.setAccessibilityLabel(L("%@の横スクロールを記録", label))
        scroll.toolTip = L("このウィンドウ上でマウスを横に操作してください。入力待ちは15秒です。")
        let result = row([name, keyCell, scroll, value])
        result.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return result
    }
    @objc private func changeLanguage() {
        selectedLanguage = InterfaceLanguage.allCases[languagePicker.indexOfSelectedItem]
    }
    func present(_ configuration: InputConfiguration?) {
        if window?.isVisible != true && window?.isMiniaturized != true {
            original = configuration; draft = configuration ?? .standard; discarding = false
            originalLanguage = InterfaceLanguage.saved
            selectedLanguage = originalLanguage
            languagePicker.selectItem(at: InterfaceLanguage.allCases.firstIndex(of: selectedLanguage) ?? 0)
            refreshBindings()
            setMessage(configuration == nil ? L("保存済みの設定が無効です。左右の入力を記録して保存してください。") : L("キーはmacOSのSpace移動と同じ組み合わせを登録します。"), error: configuration == nil)
        }
        // Order out before activation so an already-visible window on another Space
        // doesn't pull the user back there. Preserve its current draft above.
        if window?.isOnActiveSpace == false { window?.orderOut(nil) }
        if window?.isMiniaturized == true { window?.deminiaturize(nil) }
        showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func update(_ status: SettingsStatus) {
        summary.stringValue = status.summary
        detection.stringValue = L("Mission Controlの検知: %@", status.detection)
        detection.textColor = .secondaryLabelColor
        runSwitch.state = status.running ? .on : .off
        // Approval-pending items are registered and can still be switched off.
        loginSwitch.state = status.loginItem == .enabled || status.loginItem == .requiresApproval ? .on : .off
        loginSettings.isHidden = status.loginItem != .requiresApproval
        switch status.loginItem {
        case .enabled:
            loginStatus.stringValue = L("ログイン時に自動起動します。変更はすぐに反映されます。")
        case .requiresApproval:
            loginStatus.stringValue = L("自動起動には、システム設定のログイン項目で許可が必要です。")
        case .notRegistered:
            loginStatus.stringValue = L("ログイン時に自動起動しません。変更はすぐに反映されます。")
        case .notFound:
            loginStatus.stringValue = L("アプリが見つかりません。DeskSway.appをアプリケーションから開いてください。")
        @unknown default:
            loginStatus.stringValue = L("ログイン項目の状態を確認できません。")
        }
        for (index, item) in [(axStatus, status.accessibility), (listenStatus, status.listening), (postStatus, status.posting)].enumerated() {
            let (field, allowed) = item
            let indicator = permissionIndicators[index]
            indicator.image = NSImage(systemSymbolName: allowed ? "checkmark.circle.fill" : "exclamationmark.circle.fill", accessibilityDescription: allowed ? L("許可を認識済み") : L("権限の確認が必要"))
            indicator.contentTintColor = allowed ? .systemGreen : .systemOrange
            indicator.toolTip = allowed ? L("許可を認識済み") : L("詳細を開いて権限を確認してください")
            field.stringValue = allowed ? L("許可を認識済み") : L("未許可／未認識")
            field.textColor = allowed ? .systemGreen : .systemRed
        }
    }
    private func scrollLabel(_ binding: ScrollBinding) -> String {
        let kind = binding.phased ? L("ジェスチャー") : L("ホイール")
        return "\(binding.sign > 0 ? "+" : "−") · \(kind)"
    }
    private func refreshBindings() {
        leftKey.title = draft.shortcuts.left.label
        rightKey.title = draft.shortcuts.right.label
        leftScroll.title = L("左を記録")
        leftScrollValue.stringValue = scrollLabel(draft.scrollMapping.left)
        rightScroll.title = L("右を記録")
        rightScrollValue.stringValue = scrollLabel(draft.scrollMapping.right)
        refreshRepeatInterval()
    }
    private func refreshRepeatInterval() {
        repeatSlider.doubleValue = draft.repeatInterval
        repeatValue.stringValue = String(format: L("%.2f 秒"), draft.repeatInterval)
    }
    @objc private func repeatIntervalChanged() {
        draft.repeatInterval = (repeatSlider.doubleValue * 20).rounded() / 20
        refreshRepeatInterval()
    }
    @objc private func resetRepeatInterval() {
        draft.repeatInterval = InputConfiguration.defaultRepeatInterval
        refreshRepeatInterval()
    }
    private func setMessage(_ text: String, error: Bool = false) { message.stringValue = text; message.textColor = error ? .systemRed : .secondaryLabelColor }
    private func record(_ mode: InputRecorder.Mode, direction: SpaceDirection) {
        guard let window else { return }
        target = direction
        if recorder.start(mode, in: window) {
            cancelRecord.isHidden = false
            setMessage(mode == .shortcut ? L("%@へ移動するキーを押して離してください。Escで中止します。", targetName) : L("%@へ移動させたい横スクロールを操作してください。縦入力・慣性は登録しません。", targetName))
        }
    }
    @objc private func recordLeftKey() { record(.shortcut, direction: .left) }
    @objc private func recordRightKey() { record(.shortcut, direction: .right) }
    @objc private func recordLeftScroll() { record(.scroll, direction: .left) }
    @objc private func recordRightScroll() { record(.scroll, direction: .right) }
    @objc private func cancelRecording() { recorder.cancel() }
    @objc private func toggleRun() { recorder.stop(); onToggleRunning?() }
    @objc private func toggleLaunchAtLogin() {
        recorder.stop()
        do {
            try onSetLaunchAtLogin?(loginSwitch.state == .on)
            onRefresh?()
        } catch {
            onRefresh?()
            setMessage(L("ログイン時の起動を変更できませんでした: %@", error.localizedDescription), error: true)
        }
    }
    @objc private func openLoginItems() { recorder.stop(); onOpenLoginItems?() }
    @objc private func accessibility() { recorder.stop(); onAccessibility?() }
    @objc private func inputMonitoring() { recorder.stop(); onInputMonitoring?() }
    @objc private func posting() {
        recorder.stop()
        onPosting?()
    }
    @objc private func refresh() { onRefresh?() }
    @objc private func revealApp() { recorder.stop(); NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
    @objc private func restart() {
        recorder.stop()
        guard !recorder.isDrainingKeys else { return }
        guard confirmDiscardIfNeeded() else { return }
        let wasDiscarding = discarding
        discarding = true // The termination callback must not ask a second time.
        defer { discarding = wasDiscarding } // Keep protection if relaunch fails.
        onRestart?()
    }
    @objc private func saveSettings() {
        if persistSettings() { setMessage(L("保存して反映しました。設定画面を開いたまま動作を試せます。")) }
    }
    private func persistSettings() -> Bool {
        recorder.stop()
        guard draft.shortcuts.isValid else { setMessage(L("左右のキーが同じ、または修飾キーがありません。異なる組み合わせを記録してください。"), error: true); return false }
        guard draft.scrollMapping.isValid else { setMessage(L("左右の横入力は逆方向・同じ入力形式で登録してください。同じマウスで両方を記録し直してください。"), error: true); return false }
        do {
            try onSave?(draft)
            InterfaceLanguage.saved = selectedLanguage
            originalLanguage = selectedLanguage
            original = draft
            return true
        }
        catch { setMessage(L("設定を保存できませんでした。"), error: true); return false }
    }
    func showPostingRequestResult(granted: Bool) {
        setMessage(granted ? L("キー送信の許可を認識しました。") : L("キー送信の許可を要求しました。macOSの案内に従ってください。以前拒否した場合はアクセシビリティのシステム設定で許可し、アプリを再起動してください。"), error: !granted)
    }
    @objc private func discardSettings() { discarding = true; recorder.stop(); close() }
    private func confirmDiscardIfNeeded() -> Bool {
        guard !discarding, original != draft || originalLanguage != selectedLanguage else { return true }
        let alert = NSAlert(); alert.messageText = L("未保存の変更を破棄しますか？")
        alert.addButton(withTitle: L("変更に戻る")); alert.addButton(withTitle: L("破棄する"))
        return alert.runModal() == .alertSecondButtonReturn
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { recorder.stop(); return confirmDiscardIfNeeded() }
    func windowWillClose(_ notification: Notification) { recorder.stop(); onClose?() }
    func stopRecording() { recorder.stop() }
    func prepareForTermination() -> Bool {
        recorder.stop()
        guard !recorder.isDrainingKeys else { return false }
        guard window?.isVisible == true || window?.isMiniaturized == true else { return true }
        return confirmDiscardIfNeeded()
    }
    var isDrainingKeys: Bool { recorder.isDrainingKeys }
    var isRecording: Bool { recorder.isRecording }
}
