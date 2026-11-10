import Foundation
import Network
import UIKit

// MARK: - Log

enum AdsLog {
    static var isEnabled = true

    static func d(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        print("admob_ads --- \(message())")
    }
}

// MARK: - Main thread helper

func onMain(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.async(execute: block)
    }
}

// MARK: - Network

/// Tương ứng `isNetworkActive` (NWPathMonitor) của plugin cũ.
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "AmazicAdsIos.NetworkMonitor")
    private var isStarted = false
    /// Mặc định true cho tới khi có kết quả đầu tiên, tránh chặn ads ở giây đầu mở app.
    private var lastStatusConnected = true

    func start() {
        guard !isStarted else { return }
        isStarted = true
        monitor.pathUpdateHandler = { [weak self] path in
            self?.lastStatusConnected = (path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    var isConnected: Bool {
        start()
        return monitor.currentPath.status == .satisfied || lastStatusConnected
    }
}

// MARK: - Preferences

enum AdsPreferences {
    private static let keyCountOpenApp = "amazic_ads_count_open_app"

    static var countOpenApp: Int {
        UserDefaults.standard.integer(forKey: keyCountOpenApp)
    }

    static func increaseCountOpenApp() {
        UserDefaults.standard.set(countOpenApp + 1, forKey: keyCountOpenApp)
    }
}

// MARK: - UIKit helpers

enum UIHelper {
    static var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        return windows.first(where: { $0.isKeyWindow }) ?? windows.first
    }

    /// ViewController trên cùng (bỏ qua VC đang bị dismiss).
    static var topViewController: UIViewController? {
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    static var screenWidth: CGFloat {
        keyWindow?.bounds.width ?? UIScreen.main.bounds.width
    }
}

// MARK: - Consent purpose one

enum ConsentPurpose {
    /// Đọc `IABTCF_PurposeConsents`; nil nếu chưa có dữ liệu (giống `hasConsentPurposeOne`).
    static func hasConsentPurposeOne() -> Bool? {
        let value = UserDefaults.standard.string(forKey: "IABTCF_PurposeConsents") ?? ""
        guard let first = value.first else { return nil }
        return first == "1"
    }
}
