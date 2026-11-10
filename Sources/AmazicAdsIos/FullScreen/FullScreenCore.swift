import Foundation
import GoogleMobileAds
import UIKit

/// Gom các callback ads (thay cho các tham số onAdXxx rời rạc bên Flutter).
public struct AdCallbacks {
    public var onAdDisable: (() -> Void)?
    public var onAdLoaded: (() -> Void)?
    public var onAdImpression: (() -> Void)?
    public var onAdClicked: (() -> Void)?
    public var onAdFailedToLoad: ((String) -> Void)?
    public var onAdFailedToShow: ((String) -> Void)?
    public var onAdDismiss: (() -> Void)?
    public var onUserEarnedReward: (() -> Void)?
    /// Chạy **đúng 1 lần** khi ads kết thúc vì bất kỳ lý do nào:
    /// không đủ điều kiện (disable) / load lỗi / show lỗi / user đóng ads.
    /// Đặt chuyển màn ở đây là đủ, không cần đặt ở 4 callback kia.
    public var onNext: (() -> Void)?

    public init(
        onAdDisable: (() -> Void)? = nil,
        onAdLoaded: (() -> Void)? = nil,
        onAdImpression: (() -> Void)? = nil,
        onAdClicked: (() -> Void)? = nil,
        onAdFailedToLoad: ((String) -> Void)? = nil,
        onAdFailedToShow: ((String) -> Void)? = nil,
        onAdDismiss: (() -> Void)? = nil,
        onUserEarnedReward: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil
    ) {
        self.onAdDisable = onAdDisable
        self.onAdLoaded = onAdLoaded
        self.onAdImpression = onAdImpression
        self.onAdClicked = onAdClicked
        self.onAdFailedToLoad = onAdFailedToLoad
        self.onAdFailedToShow = onAdFailedToShow
        self.onAdDismiss = onAdDismiss
        self.onUserEarnedReward = onUserEarnedReward
        self.onNext = onNext
    }

    /// Gộp `onNext` (và `extraNext` nếu có) vào 4 callback kết thúc, đảm bảo chỉ chạy 1 lần.
    /// Trả về callbacks đã gộp + hàm `next` (gọi trực tiếp cũng chỉ chạy 1 lần).
    func withNext(_ extraNext: (() -> Void)? = nil) -> (callbacks: AdCallbacks, next: () -> Void) {
        let original = self
        var isDone = false
        let next: () -> Void = {
            guard !isDone else { return }
            isDone = true
            original.onNext?()
            extraNext?()
        }
        var merged = original
        merged.onNext = nil
        merged.onAdDisable = { original.onAdDisable?(); next() }
        merged.onAdFailedToLoad = { message in original.onAdFailedToLoad?(message); next() }
        merged.onAdFailedToShow = { message in original.onAdFailedToShow?(message); next() }
        merged.onAdDismiss = { original.onAdDismiss?(); next() }
        return (merged, next)
    }
}

// MARK: - Delegate proxy

/// `fullScreenContentDelegate` là weak nên object này được giữ lại cho tới khi ads đóng / lỗi.
final class FullScreenDelegate: NSObject, FullScreenContentDelegate {
    private static var retained: [ObjectIdentifier: FullScreenDelegate] = [:]

    var ad: AnyObject?
    var onImpression: (() -> Void)?
    var onClick: (() -> Void)?
    var onFailToPresent: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    func retain() {
        FullScreenDelegate.retained[ObjectIdentifier(self)] = self
    }

    private func release() {
        ad = nil
        FullScreenDelegate.retained.removeValue(forKey: ObjectIdentifier(self))
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        onMain { self.onImpression?() }
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        onMain { self.onClick?() }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        let message = error.localizedDescription
        onMain {
            self.onFailToPresent?(message)
            self.release()
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        onMain {
            self.onDismiss?()
            self.release()
        }
    }
}

// MARK: - Present

enum FullScreenPresenter {
    /// Logic chung khi show inter / app open / reward:
    /// impression -> fullScreenShowing = true + log `${name}_view`;
    /// fail / dismiss -> đóng loading, fullScreenShowing = false.
    static func show(
        ad: FullScreenPresentingAd,
        logName: String?,
        closeLoading: Bool,
        callbacks: AdCallbacks,
        onDismissExtra: (() -> Void)? = nil,
        present: @escaping (UIViewController?) -> Void
    ) {
        let delegate = FullScreenDelegate()
        delegate.ad = ad
        delegate.onImpression = {
            Admob.shared.isFullScreenAdShowing = true
            if let logName { EventLog.logEvent("\(logName)_view") }
            callbacks.onAdImpression?()
        }
        delegate.onClick = {
            if let logName { EventLog.logEvent("\(logName)_click") }
            callbacks.onAdClicked?()
        }
        delegate.onFailToPresent = { message in
            if let logName { EventLog.logEvent("\(logName)_fail", parameters: ["error": message]) }
            if closeLoading { LoadingOverlay.shared.hide() }
            Admob.shared.isFullScreenAdShowing = false
            callbacks.onAdFailedToShow?(message)
        }
        delegate.onDismiss = {
            if closeLoading { LoadingOverlay.shared.hide() }
            Admob.shared.isFullScreenAdShowing = false
            onDismissExtra?()
            callbacks.onAdDismiss?()
        }
        delegate.retain()
        ad.fullScreenContentDelegate = delegate

        Admob.shared.isFullScreenAdShowing = true
        Admob.shared.checkAndShowAdForeground {
            // Đợi màn Loading present xong rồi mới present ads lên trên.
            LoadingOverlay.shared.whenReady {
                present(UIHelper.topViewController)
            }
        }
    }
}
