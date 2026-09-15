import AppKit
import QuartzCore

@MainActor
final class MotionCoordinator {
    var onModeTransition: (() -> Void)?

    private let model: PresentationState
    private var timer: Timer?
    private var startValue: CGFloat = 0
    private var targetValue: CGFloat = 0
    private var startTime: CFTimeInterval = 0
    private var duration: CFTimeInterval = 0.42

    init(model: PresentationState) {
        self.model = model
    }

    func move(to mode: CenterMode) {
        let target = CGFloat(mode.rawValue)
        onModeTransition?()
        model.setCenterMode(mode)
        targetValue = target

        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            stop()
            model.transitionProgress = target
            return
        }

        startValue = model.transitionProgress
        let distance = abs(target - startValue)
        guard distance > 0.001 else {
            stop()
            model.transitionProgress = target
            return
        }

        duration = max(0.14, 0.42 * Double(distance))
        startTime = CACurrentMediaTime()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        let elapsed = CACurrentMediaTime() - startTime
        let linear = min(max(elapsed / duration, 0), 1)
        let eased = linear < 0.5
            ? 2 * linear * linear
            : 1 - pow(-2 * linear + 2, 2) / 2
        model.transitionProgress = startValue + (targetValue - startValue) * CGFloat(eased)

        if linear >= 1 {
            model.transitionProgress = targetValue
            stop()
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}
