import Foundation
import UIKit

/// Timer refresh banner / native: dừng khi app vào background hoặc view bị ẩn, chạy lại khi quay lại.
final class AdRefreshTimer {
    private let interval: Int
    private let action: () -> Void
    private var timer: Timer?
    private var isVisible = false
    private var isArmed = false
    private var observers: [NSObjectProtocol] = []

    init(intervalSec: Int, action: @escaping () -> Void) {
        self.interval = intervalSec
        self.action = action
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.invalidate()
        })
        observers.append(center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.scheduleIfNeeded()
        })
    }

    deinit {
        timer?.invalidate()
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// Gọi khi ads có impression / load fail (giống startRefreshTime bên Flutter).
    func start() {
        isArmed = true
        scheduleIfNeeded()
    }

    func stop() {
        isArmed = false
        invalidate()
    }

    func setVisible(_ visible: Bool) {
        isVisible = visible
        if visible { scheduleIfNeeded() } else { invalidate() }
    }

    private func scheduleIfNeeded() {
        guard interval > 0, isArmed, isVisible, timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
            self?.action()
        }
    }

    private func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}
