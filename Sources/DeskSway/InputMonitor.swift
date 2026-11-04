import AppKit
import ApplicationServices
import DeskSwayCore

final class InputMonitor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var policy = ScrollPolicy()
    private var lastAttempt = -Double.infinity
    // These closures are evaluated only on the main run loop.
    var gate: () -> InputGate = { InputGate(running: false, permissionsGranted: false, tapEnabled: false, settingsValid: false, detection: .unknown) }
    var configuration: InputConfiguration?
    var onDisabled: (() -> Void)?
    var isEnabled: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func reconcile(active: Bool) {
        guard active else { stop(); return }
        guard !isEnabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastAttempt >= 2 else { return }
        lastAttempt = now
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            if isEnabled { return }
            stop()
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                         options: .defaultTap,
                                         eventsOfInterest: CGEventMask(1) << CGEventType.scrollWheel.rawValue,
                                         callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let owner = Unmanaged<InputMonitor>.fromOpaque(context).takeUnretainedValue()
            return owner.handle(type: type, event: event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap); return
        }
        self.tap = tap; self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    func reset() { policy = ScrollPolicy() }
    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
        reset()
    }
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            reset()
            onDisabled?()
            // Re-enable only on the next permission-checked reconciliation tick.
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }
        var currentGate = gate()
        currentGate.tapEnabled = isEnabled
        // Re-check before every conversion; never prompt from an input callback.
        currentGate.permissionsGranted = currentGate.permissionsGranted && AXIsProcessTrusted() && CGPreflightPostEventAccess() && CGPreflightListenEventAccess()
        guard let prepared = ScrollEventAdapter.prepare(event, at: ProcessInfo.processInfo.systemUptime,
                                                        gate: currentGate, shortcuts: configuration?.shortcuts, mapping: configuration?.scrollMapping ?? .standard,
                                                        repeatInterval: configuration?.repeatInterval ?? InputConfiguration.defaultRepeatInterval, policy: &policy) else {
            return Unmanaged.passUnretained(event)
        }
        if let keys = prepared.keys {
            keys.down.post(tap: .cghidEventTap)
            keys.up.post(tap: .cghidEventTap)
        }
        return Unmanaged.passRetained(prepared.event)
    }
    deinit { stop() }
}
