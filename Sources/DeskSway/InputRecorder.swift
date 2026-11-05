import AppKit
import ApplicationServices
import DeskSwayCore

// The only keyboard tap in the app. New input is accepted for at most 15 seconds
// in the active settings window. Cancellation drains ONLY already-swallowed
// keys until release; it must not leak their repeats into system shortcuts.
final class InputRecorder {
    enum Mode { case shortcut, scroll }
    var onShortcut: ((ShortcutCapture.Outcome) -> Void)?
    var onScroll: ((ScrollBinding) -> Void)?
    var onMessage: ((String) -> Void)?
    var onStopped: (() -> Void)?
    private var mode: Mode?
    private weak var window: NSWindow?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var timeout: Timer?
    private var observers: [NSObjectProtocol] = []
    private var keys = ShortcutCapture()
    private var finishing = false
    private var generation: UInt64 = 0
    private var draining = false
    var isDrainingKeys: Bool { draining }
    // Includes finishing and draining keys already swallowed by the recorder.
    var isRecording: Bool { mode != nil }

    func start(_ mode: Mode, in window: NSWindow) -> Bool {
        stop()
        guard !draining else { return false }
        guard NSApp.isActive, window.isKeyWindow else {
            onMessage?(L("設定画面を選択してから、もう一度「記録」を押してください。")); return false
        }
        guard CGPreflightListenEventAccess() else {
            onMessage?(L("入力監視が認識されていません。下の権限欄で許可し、再確認または再起動してください。")); return false
        }
        if case .shortcut = mode, !AXIsProcessTrusted() {
            onMessage?(L("キーを安全に記録するにはアクセシビリティの許可が必要です。")); return false
        }
        self.mode = mode; self.window = window; keys = ShortcutCapture(); finishing = false
        let mask: CGEventMask = mode == .shortcut
            ? (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.keyUp.rawValue)
            : CGEventMask(1) << CGEventType.scrollWheel.rawValue
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                         options: mode == .shortcut ? .defaultTap : .listenOnly,
                                         eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return Unmanaged<InputRecorder>.fromOpaque(context).takeUnretainedValue().handle(type, event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()),
              let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            stop(); onMessage?(L("入力の記録を開始できません。権限の再確認・アプリの再起動を試してください。")); return false
        }
        self.tap = tap; self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in self?.cancel(L("画面が切り替わったため記録を中止しました。")) })
        observers.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.cancel(L("他のアプリへ切り替わったため記録を中止しました。")) })
        let timer = Timer(timeInterval: 15, repeats: false) { [weak self] _ in self?.cancel(L("入力がなかったため記録を終了しました。もう一度「記録」を押してください。")) }
        RunLoop.main.add(timer, forMode: .common); timeout = timer
        return true
    }
    func stop() {
        if mode == .shortcut && keys.hasHeldKeys {
            keys.cancel(); draining = true
            timeout?.invalidate(); timeout = nil
            onMessage?(L("記録を中止しました。押したキーを離すと終了します。新しいキーは記録しません。"))
            return
        }
        tearDown()
    }
    private func tearDown() {
        generation &+= 1
        mode = nil; finishing = false; draining = false
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
        timeout?.invalidate(); timeout = nil
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll(); window = nil
        onStopped?()
    }
    func cancel(_ message: String = L("記録を中止しました。")) { stop(); if !draining { onMessage?(message) } }
    private func finish(_ completion: @escaping () -> Void) {
        guard !finishing else { return }
        finishing = true
        let generation = self.generation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.finishing, self.generation == generation else { return }
            self.stop(); completion()
        }
    }
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard !finishing, let mode else { return Unmanaged.passUnretained(event) }
        guard type != .tapDisabledByTimeout && type != .tapDisabledByUserInput else {
            tearDown()
            onMessage?(L("入力監視が停止しました。押しているキーを離し、権限を再確認してください。"))
            return Unmanaged.passUnretained(event)
        }
        if !draining && !(NSApp.isActive && window?.isKeyWindow == true) {
            stop()
            if !draining { return Unmanaged.passUnretained(event) }
        }
        switch mode {
        case .shortcut:
            guard type == .keyDown || type == .keyUp else { return Unmanaged.passUnretained(event) }
            let decision = keys.process(code: UInt16(clamping: event.getIntegerValueField(.keyboardEventKeycode)),
                                        modifiers: KeyModifiers(eventFlags: event.flags), isDown: type == .keyDown,
                                        isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
            switch decision {
            case .pass: return Unmanaged.passUnretained(event)
            case .consume: return nil
            case .finished(let outcome):
                finish { [weak self] in self?.onShortcut?(outcome) }
                return nil
            }
        case .scroll:
            guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }
            if let binding = ScrollBinding(capturing: ScrollEventAdapter.sample(event)) {
                finish { [weak self] in self?.onScroll?(binding) }
            }
            return Unmanaged.passUnretained(event)
        }
    }
    deinit { tearDown() }
}
