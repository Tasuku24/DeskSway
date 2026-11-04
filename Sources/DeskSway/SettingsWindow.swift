import AppKit
import DeskSwayCore

struct SettingsStatus {
    var running: Bool
    var accessibility: Bool
    var listening: Bool
    var posting: Bool
    var summary: String
    var detection: String
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
    private let recorder = InputRecorder()
    private var draft = InputConfiguration.standard
    private var original: InputConfiguration?
    private var target: SpaceDirection = .left
    private var discarding = false
    private let summary = NSTextField(wrappingLabelWithString: "")
    private let detection = NSTextField(labelWithString: "")
    private let runButton = NSButton(title: "実行", target: nil, action: nil)
    private let axStatus = NSTextField(labelWithString: "確認中")
    private let listenStatus = NSTextField(labelWithString: "確認中")
    private let postStatus = NSTextField(labelWithString: "確認中")
    private let leftKey = NSButton(title: "", target: nil, action: nil)
    private let rightKey = NSButton(title: "", target: nil, action: nil)
    private let leftScroll = NSButton(title: "", target: nil, action: nil)
    private let rightScroll = NSButton(title: "", target: nil, action: nil)
    private let message = NSTextField(wrappingLabelWithString: "")
    private let cancelRecord = NSButton(title: "記録を中止", target: nil, action: nil)
    private let repeatSlider = NSSlider(value: InputConfiguration.defaultRepeatInterval,
                                       minValue: InputConfiguration.repeatIntervalRange.lowerBound,
                                       maxValue: InputConfiguration.repeatIntervalRange.upperBound,
                                       target: nil, action: nil)
    private let repeatValue = NSTextField(labelWithString: "")

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 760),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "DeskSway — 設定"
        window.isReleasedWhenClosed = false
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
                self.setMessage("\(self.targetName)のキーを記録しました。保存して反映してください。")
            case .invalid: self.setMessage("修飾キー（Control・Option・Shift・Command）とキーを同時に押してください。", error: true)
            case .cancelled: self.setMessage("記録を中止しました。")
            }
        }
        recorder.onScroll = { [weak self] binding in
            guard let self else { return }
            if self.target == .left { self.draft.scrollMapping.left = binding } else { self.draft.scrollMapping.right = binding }
            self.refreshBindings()
            self.setMessage("\(self.targetName)の横入力を受信しました（\(binding.label)）。左右とも記録して保存してください。")
        }
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private var targetName: String { target == .left ? "左" : "右" }
    private func buildContent(_ window: NSWindow) {
        let title = NSTextField(labelWithString: "DeskSway")
        title.font = .systemFont(ofSize: 23, weight: .semibold)
        let intro = note("権限を確認し、キーと横スクロールを実際に入力して登録します。設定画面を開いたまま動作を試せます。入力を記録している間だけSpace移動を停止します。")
        runButton.target = self; runButton.action = #selector(toggleRun)
        let state = section("動作", [row([summary, runButton]), detection])

        let permissionRows: [NSView] = [
            permissionRow("アクセシビリティ", status: axStatus, action: #selector(accessibility)),
            permissionRow("入力監視", status: listenStatus, action: #selector(inputMonitoring)),
            permissionRow("キー送信", status: postStatus, action: #selector(posting), buttonTitle: "キー送信を許可…"),
            note("許可しても未認識の場合は、実行中のこのアプリをシステム設定で確認し、再起動してください。ビルド更新後は再登録が必要な場合があります。"),
            row([button("権限を再確認", #selector(refresh)), button("アプリを再起動", #selector(restart)), button("アプリの場所を表示", #selector(revealApp))])
        ]
        let permissions = section("権限", permissionRows)
        let path = NSTextField(wrappingLabelWithString: Bundle.main.bundleURL.path)
        path.isSelectable = true; path.font = .systemFont(ofSize: 11); path.textColor = .secondaryLabelColor

        leftKey.target = self; leftKey.action = #selector(recordLeftKey)
        rightKey.target = self; rightKey.action = #selector(recordRightKey)
        leftScroll.target = self; leftScroll.action = #selector(recordLeftScroll)
        rightScroll.target = self; rightScroll.action = #selector(recordRightScroll)
        let bindings = section("入力を登録", [
            note("キーはmacOSの「左／右の操作スペースに移動」と同じ組み合わせを押してください。横入力は、それぞれの方向へマウスを操作して登録します。"),
            bindingRow("左のSpace", key: leftKey, scroll: leftScroll),
            bindingRow("右のSpace", key: rightKey, scroll: rightScroll),
            note("入力待ちは15秒です。キーを押して離すと登録されます。中止時も押したキーを離すまでそのキーだけを抑止します。横入力はこの画面にポインタを置いて操作してください。")
        ])
        repeatSlider.target = self; repeatSlider.action = #selector(repeatIntervalChanged)
        repeatSlider.isContinuous = true
        repeatSlider.widthAnchor.constraint(equalToConstant: 320).isActive = true
        repeatSlider.setAccessibilityLabel("次の入力までの待ち時間（秒）")
        repeatSlider.toolTip = "0.00〜2.00秒。0秒は待ち時間なしです。"
        repeatValue.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        repeatValue.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let timing = section("連続入力", [
            row([NSTextField(labelWithString: "次の入力までの待ち時間"), repeatSlider, repeatValue,
                 button("標準に戻す", #selector(resetRepeatInterval))]),
            note("0.00〜2.00秒で調整できます。0秒は待ち時間なしです。横操作が続いている間だけ繰り返し、慣性では追加移動しません。")
        ])
        cancelRecord.target = self; cancelRecord.action = #selector(cancelRecording); cancelRecord.isHidden = true
        message.font = .systemFont(ofSize: 12)
        message.heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
        let save = button("保存", #selector(saveSettings))
        save.keyEquivalent = "s"; save.keyEquivalentModifierMask = .command
        let saveAndClose = button("保存して閉じる", #selector(saveAndCloseSettings)); saveAndClose.keyEquivalent = "\r"
        let cancel = button("変更を破棄して閉じる", #selector(discardSettings))
        let footer = row([cancel, save, saveAndClose]); footer.alignment = .centerY
        let stack = NSStackView(views: [title, intro, state, permissions, path, bindings, timing, row([message, cancelRecord]), footer])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        if let content = window.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
                stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
                stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20)
            ])
            for view in [intro, state, permissions, path, bindings, timing] { view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
            message.widthAnchor.constraint(equalToConstant: 550).isActive = true
        }
    }
    private func note(_ text: String) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: 12); field.textColor = .secondaryLabelColor
        return field
    }
    private func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views); stack.orientation = .horizontal; stack.spacing = 12; stack.alignment = .centerY
        return stack
    }
    private func button(_ title: String, _ action: Selector) -> NSButton { NSButton(title: title, target: self, action: action) }
    private func section(_ title: String, _ views: [NSView]) -> NSStackView {
        let heading = NSTextField(labelWithString: title); heading.font = .boldSystemFont(ofSize: 13)
        let stack = NSStackView(views: [heading] + views)
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 8
        for view in views where view is NSTextField { view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        return stack
    }
    private func permissionRow(_ label: String, status: NSTextField, action: Selector, buttonTitle: String = "システム設定を開く…") -> NSStackView {
        let name = NSTextField(labelWithString: label); name.widthAnchor.constraint(equalToConstant: 150).isActive = true
        status.widthAnchor.constraint(equalToConstant: 140).isActive = true
        return row([name, status, button(buttonTitle, action)])
    }
    private func bindingRow(_ label: String, key: NSButton, scroll: NSButton) -> NSStackView {
        let name = NSTextField(labelWithString: label); name.widthAnchor.constraint(equalToConstant: 85).isActive = true
        key.widthAnchor.constraint(equalToConstant: 240).isActive = true
        scroll.widthAnchor.constraint(equalToConstant: 335).isActive = true
        key.setAccessibilityLabel("\(label)のショートカットを直接記録")
        scroll.setAccessibilityLabel("\(label)の横スクロールを記録")
        return row([name, key, scroll])
    }
    func present(_ configuration: InputConfiguration?) {
        if window?.isVisible != true {
            original = configuration; draft = configuration ?? .standard; discarding = false
            refreshBindings()
            setMessage(configuration == nil ? "保存済みの設定が無効です。左右の入力を記録して保存してください。" : "記録する入力のボタンを押してください。", error: configuration == nil)
        }
        showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func update(_ status: SettingsStatus) {
        summary.stringValue = status.summary
        detection.stringValue = "Mission Controlの検知: \(status.detection)"
        detection.textColor = .secondaryLabelColor
        runButton.title = status.running ? "一時停止にする" : "実行する"
        for (field, allowed) in [(axStatus, status.accessibility), (listenStatus, status.listening), (postStatus, status.posting)] {
            field.stringValue = allowed ? "許可を認識済み" : "未許可／未認識"
            field.textColor = allowed ? .systemGreen : .systemRed
        }
    }
    private func refreshBindings() {
        leftKey.title = "キーを記録: \(draft.shortcuts.left.label)"
        rightKey.title = "キーを記録: \(draft.shortcuts.right.label)"
        leftScroll.title = "横入力を記録: \(draft.scrollMapping.left.label)"
        rightScroll.title = "横入力を記録: \(draft.scrollMapping.right.label)"
        refreshRepeatInterval()
    }
    private func refreshRepeatInterval() {
        repeatSlider.doubleValue = draft.repeatInterval
        repeatValue.stringValue = String(format: "%.2f 秒", draft.repeatInterval)
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
            setMessage(mode == .shortcut ? "\(targetName)へ移動するキーを押して離してください。Escで中止します。" : "\(targetName)へ移動させたい横スクロールを操作してください。縦入力・慣性は登録しません。")
        }
    }
    @objc private func recordLeftKey() { record(.shortcut, direction: .left) }
    @objc private func recordRightKey() { record(.shortcut, direction: .right) }
    @objc private func recordLeftScroll() { record(.scroll, direction: .left) }
    @objc private func recordRightScroll() { record(.scroll, direction: .right) }
    @objc private func cancelRecording() { recorder.cancel() }
    @objc private func toggleRun() { recorder.stop(); onToggleRunning?() }
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
        onRestart?()
    }
    @objc private func saveSettings() {
        if persistSettings() { setMessage("保存して反映しました。設定画面を開いたまま動作を試せます。") }
    }
    @objc private func saveAndCloseSettings() {
        if persistSettings() { close() }
    }
    private func persistSettings() -> Bool {
        recorder.stop()
        guard draft.shortcuts.isValid else { setMessage("左右のキーが同じ、または修飾キーがありません。異なる組み合わせを記録してください。", error: true); return false }
        guard draft.scrollMapping.isValid else { setMessage("左右の横入力は逆方向・同じ入力形式で登録してください。同じマウスで両方を記録し直してください。", error: true); return false }
        do { try onSave?(draft); original = draft; return true }
        catch { setMessage("設定を保存できませんでした。", error: true); return false }
    }
    func showPostingRequestResult(granted: Bool) {
        setMessage(granted ? "キー送信の許可を認識しました。" : "キー送信の許可を要求しました。macOSの案内に従ってください。以前拒否した場合はアクセシビリティのシステム設定で許可し、アプリを再起動してください。", error: !granted)
    }
    @objc private func discardSettings() { discarding = true; recorder.stop(); close() }
    private func confirmDiscardIfNeeded() -> Bool {
        guard !discarding, original != draft else { return true }
        let alert = NSAlert(); alert.messageText = "未保存の変更を破棄しますか？"
        alert.addButton(withTitle: "変更に戻る"); alert.addButton(withTitle: "破棄する")
        return alert.runModal() == .alertSecondButtonReturn
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { recorder.stop(); return confirmDiscardIfNeeded() }
    func windowWillClose(_ notification: Notification) { recorder.stop(); onClose?() }
    func stopRecording() { recorder.stop() }
    var isDrainingKeys: Bool { recorder.isDrainingKeys }
    var isRecording: Bool { recorder.isRecording }
}
