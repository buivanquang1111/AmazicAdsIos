import Foundation
import GoogleMobileAds
import UIKit
#if canImport(GoogleMobileAds_Private)
import GoogleMobileAds_Private
#endif

/// Loại ads full screen dùng preload.
enum PreloadFormat: String {
    case inter
    case appOpen
    case reward
}

/// Preload inter / app open / reward. Preload ID = ad unit id.
///
/// Có 2 cách chạy, tự chọn lúc build:
/// - **GMA SDK >= 13.4.0** (có module `GoogleMobileAds_Private`): dùng Ad Preloading (beta) của SDK
///   `InterstitialAdPreloader` / `AppOpenAdPreloader` / `RewardedAdPreloader`.
/// - **GMA SDK 12.x**: Ad Preloading chưa có public API -> dùng bộ đệm của thư viện,
///   cùng hành vi: giữ `bufferSize` ads, lấy ra thì tự load bù, lỗi thì tự retry (backoff),
///   tự bỏ ads hết hạn (inter / reward 1h, app open 4h).
///
/// Giới hạn của Google khi dùng SDK preload: tối đa 6 ads preload toàn app.
final class AdPreloadCenter: NSObject {
    static let shared = AdPreloadCenter()

    private struct Waiter {
        let onAvailable: () -> Void
        let onFailed: (String) -> Void
    }

    /// preloadID -> format đang preload
    private var started: [String: PreloadFormat] = [:]
    private var waiters: [String: [Waiter]] = [:]

    /// true nếu đang dùng Ad Preloading của SDK.
    static var isUsingSdkPreloader: Bool {
        #if canImport(GoogleMobileAds_Private)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Start / stop

    /// Bắt đầu preload (gọi nhiều lần cũng chỉ preload 1 lần cho mỗi id).
    @discardableResult
    func start(_ format: PreloadFormat, adUnitId: String, bufferSize: Int) -> Bool {
        guard !adUnitId.isEmpty else { return false }
        if started[adUnitId] != nil { return true }
        let size = max(1, bufferSize)
        let ok = backendStart(format, adUnitId: adUnitId, bufferSize: size)
        AdsLog.d("[Preload] start \(format.rawValue) \(adUnitId) buffer = \(size) sdk = \(Self.isUsingSdkPreloader) -> \(ok)")
        if ok { started[adUnitId] = format }
        return ok
    }

    /// Dừng preload + xoá ads của id (thay cho destroy bên Flutter).
    func stop(_ format: PreloadFormat, adUnitId: String) {
        backendStop(format, adUnitId: adUnitId)
        started.removeValue(forKey: adUnitId)
        AdsLog.d("[Preload] stop \(format.rawValue) \(adUnitId)")
    }

    func isStarted(_ adUnitId: String) -> Bool {
        started[adUnitId] != nil
    }

    // MARK: - Chờ ads

    /// Đợi lần "có ads" / "lỗi" kế tiếp của id.
    func waitForAd(_ adUnitId: String, onAvailable: @escaping () -> Void, onFailed: @escaping (String) -> Void) {
        waiters[adUnitId, default: []].append(Waiter(onAvailable: onAvailable, onFailed: onFailed))
    }

    fileprivate func notifyAvailable(_ preloadID: String, network: String?) {
        onMain { [self] in
            AdsLog.d("[Preload] adAvailable \(preloadID) - \(network ?? "")")
            let pending = waiters.removeValue(forKey: preloadID) ?? []
            pending.forEach { $0.onAvailable() }
        }
    }

    fileprivate func notifyFailed(_ preloadID: String, message: String) {
        onMain { [self] in
            AdsLog.d("[Preload] adFailedToPreload \(preloadID) - \(message)")
            EventLog.logEvent("preload_fail", parameters: ["id": preloadID, "error": message])
            let pending = waiters.removeValue(forKey: preloadID) ?? []
            pending.forEach { $0.onFailed(message) }
        }
    }

    // MARK: - Backend: Ad Preloading của SDK (GMA >= 13.4.0)

    #if canImport(GoogleMobileAds_Private)

    private func backendStart(_ format: PreloadFormat, adUnitId: String, bufferSize: Int) -> Bool {
        let config = PreloadConfigurationV2(adUnitID: adUnitId, request: Request())
        config.bufferSize = UInt(bufferSize)
        switch format {
        case .inter: return InterstitialAdPreloader.shared.preload(for: adUnitId, configuration: config, delegate: self)
        case .appOpen: return AppOpenAdPreloader.shared.preload(for: adUnitId, configuration: config, delegate: self)
        case .reward: return RewardedAdPreloader.shared.preload(for: adUnitId, configuration: config, delegate: self)
        }
    }

    private func backendStop(_ format: PreloadFormat, adUnitId: String) {
        switch format {
        case .inter: InterstitialAdPreloader.shared.stopPreloadingAndRemoveAds(for: adUnitId)
        case .appOpen: AppOpenAdPreloader.shared.stopPreloadingAndRemoveAds(for: adUnitId)
        case .reward: RewardedAdPreloader.shared.stopPreloadingAndRemoveAds(for: adUnitId)
        }
    }

    func isAvailable(_ format: PreloadFormat, adUnitId: String) -> Bool {
        guard !adUnitId.isEmpty else { return false }
        switch format {
        case .inter: return InterstitialAdPreloader.shared.isAdAvailable(with: adUnitId)
        case .appOpen: return AppOpenAdPreloader.shared.isAdAvailable(with: adUnitId)
        case .reward: return RewardedAdPreloader.shared.isAdAvailable(with: adUnitId)
        }
    }

    /// Chỉ gọi khi chuẩn bị show ngay (theo khuyến nghị của Google).
    func takeInter(_ adUnitId: String) -> InterstitialAd? { InterstitialAdPreloader.shared.ad(with: adUnitId) }
    func takeAppOpen(_ adUnitId: String) -> AppOpenAd? { AppOpenAdPreloader.shared.ad(with: adUnitId) }
    func takeReward(_ adUnitId: String) -> RewardedAd? { RewardedAdPreloader.shared.ad(with: adUnitId) }

    #else

    // MARK: - Backend: bộ đệm của thư viện (GMA 12.x)

    private struct Entry {
        let ad: AnyObject
        let loadedAt: Date
    }

    private struct Slot {
        let format: PreloadFormat
        var bufferSize: Int
        var ads: [Entry] = []
        var inFlight = 0
        var retryCount = 0
        var retryScheduled = false
    }

    private var slots: [String: Slot] = [:]

    private func maxAge(_ format: PreloadFormat) -> TimeInterval {
        format == .appOpen ? 4 * 3600 : 3600
    }

    private func backendStart(_ format: PreloadFormat, adUnitId: String, bufferSize: Int) -> Bool {
        slots[adUnitId] = Slot(format: format, bufferSize: bufferSize)
        fill(adUnitId)
        return true
    }

    private func backendStop(_ format: PreloadFormat, adUnitId: String) {
        slots.removeValue(forKey: adUnitId)
    }

    private func purgeExpired(_ id: String) {
        guard var slot = slots[id] else { return }
        let age = maxAge(slot.format)
        let before = slot.ads.count
        slot.ads.removeAll { Date().timeIntervalSince($0.loadedAt) >= age }
        slots[id] = slot
        if slot.ads.count != before { fill(id) }
    }

    /// Load bù cho đủ bufferSize.
    private func fill(_ id: String) {
        guard var slot = slots[id] else { return }
        let needed = slot.bufferSize - slot.ads.count - slot.inFlight
        guard needed > 0 else { return }
        slot.inFlight += needed
        slots[id] = slot
        for _ in 0..<needed {
            load(slot.format, adUnitId: id) { [weak self] ad, error in
                onMain { self?.handleResult(id, ad: ad, error: error) }
            }
        }
    }

    private func load(_ format: PreloadFormat, adUnitId: String, done: @escaping (AnyObject?, Error?) -> Void) {
        switch format {
        case .inter:
            InterstitialAd.load(with: adUnitId, request: Request()) { ad, error in done(ad, error) }
        case .appOpen:
            AppOpenAd.load(with: adUnitId, request: Request()) { ad, error in done(ad, error) }
        case .reward:
            RewardedAd.load(with: adUnitId, request: Request()) { ad, error in done(ad, error) }
        }
    }

    private func handleResult(_ id: String, ad: AnyObject?, error: Error?) {
        guard var slot = slots[id] else { return } // đã stop
        slot.inFlight = max(0, slot.inFlight - 1)

        if let ad {
            slot.ads.append(Entry(ad: ad, loadedAt: Date()))
            slot.retryCount = 0
            slots[id] = slot
            notifyAvailable(id, network: nil)
            return
        }

        slot.retryCount += 1
        slots[id] = slot
        notifyFailed(id, message: error?.localizedDescription ?? "unknown error")
        scheduleRetry(id)
    }

    /// Retry kiểu exponential backoff: 5s, 10s, 20s, 40s, tối đa 60s.
    private func scheduleRetry(_ id: String) {
        guard var slot = slots[id], !slot.retryScheduled else { return }
        let delay = min(60, 5 * pow(2, Double(max(0, slot.retryCount - 1))))
        slot.retryScheduled = true
        slots[id] = slot
        AdsLog.d("[Preload] retry \(id) sau \(Int(delay))s")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, var slot = self.slots[id] else { return }
            slot.retryScheduled = false
            self.slots[id] = slot
            self.fill(id)
        }
    }

    func isAvailable(_ format: PreloadFormat, adUnitId: String) -> Bool {
        guard !adUnitId.isEmpty else { return false }
        purgeExpired(adUnitId)
        return !(slots[adUnitId]?.ads.isEmpty ?? true)
    }

    private func take(_ id: String) -> AnyObject? {
        purgeExpired(id)
        guard var slot = slots[id], !slot.ads.isEmpty else { return nil }
        let entry = slot.ads.removeFirst()
        slots[id] = slot
        fill(id) // lấy ra thì load bù
        return entry.ad
    }

    func takeInter(_ adUnitId: String) -> InterstitialAd? { take(adUnitId) as? InterstitialAd }
    func takeAppOpen(_ adUnitId: String) -> AppOpenAd? { take(adUnitId) as? AppOpenAd }
    func takeReward(_ adUnitId: String) -> RewardedAd? { take(adUnitId) as? RewardedAd }

    #endif
}

// MARK: - PreloadDelegate của SDK (chỉ log + báo cho nơi đang chờ, không gọi preload ở đây)

#if canImport(GoogleMobileAds_Private)
extension AdPreloadCenter: PreloadDelegate {
    func adAvailable(forPreloadID preloadID: String, responseInfo: ResponseInfo) {
        notifyAvailable(preloadID, network: responseInfo.loadedAdNetworkResponseInfo?.adSourceName)
    }

    func adFailedToPreload(forPreloadID preloadID: String, error: Error) {
        notifyFailed(preloadID, message: error.localizedDescription)
    }

    func adsExhausted(forPreloadID preloadID: String) {
        onMain { AdsLog.d("[Preload] adsExhausted \(preloadID)") }
    }
}
#endif

// MARK: - Flow chung cho preload

/// Các flow preload dùng chung cho inter / app open / reward.
/// `presentNext(closeLoading, callbacks)`: lấy 1 ads từ preloader và present, trả false nếu không có ads.
enum PreloadFlow {
    typealias PresentNext = (_ closeLoading: Bool, _ callbacks: AdCallbacks) -> Bool

    /// Bắt đầu preload; có ads sẵn -> onAdLoaded ngay, chưa có -> đợi kết quả đầu tiên.
    static func load(
        _ format: PreloadFormat,
        idAds: String,
        bufferSize: Int,
        logName: String,
        onAdLoaded: (() -> Void)?,
        onAdFailedToLoad: ((String) -> Void)?
    ) {
        let center = AdPreloadCenter.shared
        guard center.start(format, adUnitId: idAds, bufferSize: bufferSize) else {
            onAdFailedToLoad?("preload_start_failed")
            return
        }
        if center.isAvailable(format, adUnitId: idAds) {
            onAdLoaded?()
            return
        }
        center.waitForAd(idAds, onAvailable: {
            onAdLoaded?()
        }, onFailed: { message in
            EventLog.logEvent("\(logName)_fail", parameters: ["error": message])
            onAdFailedToLoad?(message)
        })
    }

    /// Show ads đã preload. Không có ads -> onAdFailedToShow("ad_not_available") + onNext.
    static func show(
        isShowLoading: Bool,
        callbacks: AdCallbacks,
        onNext: @escaping () -> Void,
        presentNext: PresentNext
    ) {
        var wrapped = callbacks
        wrapped.onAdDismiss = { callbacks.onAdDismiss?(); onNext() }
        wrapped.onAdFailedToShow = { message in callbacks.onAdFailedToShow?(message); onNext() }

        if isShowLoading { LoadingOverlay.shared.show() }
        if !presentNext(isShowLoading, wrapped) {
            AdsLog.d("preload: no ad available")
            if isShowLoading { LoadingOverlay.shared.hide() }
            Admob.shared.isFullScreenAdShowing = false
            callbacks.onAdFailedToShow?("ad_not_available")
            onNext()
        }
    }

    /// Có ads sẵn -> show; chưa có -> hiện Loading, đợi ads về rồi show; lỗi -> onNext.
    /// (Đã bỏ timeout 12s của resume preload bên Flutter.)
    static func loadAndShow(
        _ format: PreloadFormat,
        idAds: String,
        bufferSize: Int,
        config: Bool,
        name: String,
        callbacks: AdCallbacks,
        onNext: @escaping () -> Void,
        presentNext: @escaping PresentNext
    ) {
        let center = AdPreloadCenter.shared
        guard Admob.shared.canRequestAds(config: config, logName: name) else {
            onNext()
            return
        }
        center.start(format, adUnitId: idAds, bufferSize: bufferSize)

        if center.isAvailable(format, adUnitId: idAds) {
            AdsLog.d("\(name): HAVE DATA -> show")
            EventLog.logEvent("\(name)_true")
            show(isShowLoading: true, callbacks: callbacks, onNext: onNext, presentNext: presentNext)
            return
        }

        AdsLog.d("\(name): NO DATA -> đợi preload")
        LoadingOverlay.shared.show()
        var handled = false
        center.waitForAd(idAds, onAvailable: {
            guard !handled else { return }
            handled = true
            callbacks.onAdLoaded?()
            var wrapped = callbacks
            wrapped.onAdDismiss = { callbacks.onAdDismiss?(); onNext() }
            wrapped.onAdFailedToShow = { message in callbacks.onAdFailedToShow?(message); onNext() }
            if !presentNext(true, wrapped) {
                LoadingOverlay.shared.hide()
                Admob.shared.isFullScreenAdShowing = false
                onNext()
            }
        }, onFailed: { message in
            guard !handled else { return }
            handled = true
            LoadingOverlay.shared.hide()
            Admob.shared.isFullScreenAdShowing = false
            EventLog.logEvent("\(name)_fail", parameters: ["error": message])
            callbacks.onAdFailedToLoad?(message)
            onNext()
        })
    }
}
