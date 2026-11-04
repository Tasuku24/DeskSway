import AppKit
import DeskSwayCore

// All state belongs to the main run loop; AX IPC runs on one utility queue.
final class DetectionMonitor {
    private let queue = DispatchQueue(label: "DeskSway.AX", qos: .utility)
    private var cache = DetectionCache()
    private var timer: Timer?
    private var inFlight = false
    var detection: Detection { cache.detection }

    func setActive(_ active: Bool) {
        if active, timer == nil {
            let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.poll() }
            timer.tolerance = 0.02
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
            poll()
        } else if !active, timer != nil {
            timer?.invalidate(); timer = nil
            invalidate()
        }
    }
    func invalidate() { cache.invalidate() }
    private func poll() {
        guard !inFlight else { return }
        inFlight = true
        let generation = cache.generation
        queue.async { [weak self] in
            let result = MissionControlReader().scan().detection
            DispatchQueue.main.async {
                guard let self else { return }
                self.inFlight = false
                self.cache.accept(result, generation: generation)
            }
        }
    }
    deinit { timer?.invalidate() }
}
