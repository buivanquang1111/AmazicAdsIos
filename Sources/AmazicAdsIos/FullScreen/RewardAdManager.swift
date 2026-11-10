import Foundation
import GoogleMobileAds
import UIKit

/// Port `reward_ad_manager.dart`.
/// - Load thường: `RewardedAd.load`.
/// - Preload: Ad Preloading của SDK (`RewardedAdPreloader`, preload ID = ad unit id).
public final class RewardAdManager {
    public static let shared = RewardAdManager()
    private init() {}

    /// Reward load trước cho chế độ xem liên tiếp.
    private var rewardAds: [String: RewardedAd] = [:]
    private var loadingConsecutive: Set<String> = []

    public func isAdAvailable(idAds: String) -> Bool {
        AdPreloadCenter.shared.isAvailable(.reward, adUnitId: idAds)
    }

    public func destroy(idAds: String) {
        AdPreloadCenter.shared.stop(.reward, adUnitId: idAds)
    }

    // MARK: - Helper

    private func attachRevenue(_ ad: RewardedAd, idAds: String, format: String) {
        ad.paidEventHandler = { [weak ad] adValue in
            Revenue.track(adValue, responseInfo: ad?.responseInfo, adUnitId: idAds, format: format)
        }
    }

    private func present(_ ad: RewardedAd, idAds: String, logName: String?, format: String, closeLoading: Bool, callbacks: AdCallbacks) {
        attachRevenue(ad, idAds: idAds, format: format)
        FullScreenPresenter.show(ad: ad, logName: logName, closeLoading: closeLoading, callbacks: callbacks) { vc in
            ad.present(from: vc) {
                onMain { callbacks.onUserEarnedReward?() }
            }
        }
    }

    private func presentPreloaded(idAds: String, name: String, closeLoading: Bool, callbacks: AdCallbacks) -> Bool {
        guard let ad = AdPreloadCenter.shared.takeReward(idAds) else { return false }
        present(ad, idAds: idAds, logName: name, format: name, closeLoading: closeLoading, callbacks: callbacks)
        return true
    }

    // MARK: - Load & show thường

    func loadAndShowRewardAds(idAds: String, config: Bool, name: String, callbacks: AdCallbacks) {
        guard Admob.shared.canRequestAds(config: config, logName: name) else {
            callbacks.onAdDisable?()
            return
        }
        LoadingOverlay.shared.show()
        EventLog.logEvent("\(name)_true")

        RewardedAd.load(with: idAds, request: Request()) { [weak self] ad, error in
            onMain {
                guard let self else { return }
                guard let ad else {
                    let message = error?.localizedDescription ?? "unknown"
                    EventLog.logEvent("\(name)_fail", parameters: ["error": message])
                    Admob.shared.isFullScreenAdShowing = false
                    LoadingOverlay.shared.hide()
                    callbacks.onAdFailedToLoad?(message)
                    return
                }
                callbacks.onAdLoaded?()
                self.present(ad, idAds: idAds, logName: name, format: name, closeLoading: true, callbacks: callbacks)
            }
        }
    }

    // MARK: - Xem liên tiếp nhiều reward

    func loadRewardAdConsecutive(idAds: String, config: Bool) {
        guard rewardAds[idAds] == nil, !loadingConsecutive.contains(idAds) else {
            AdsLog.d("reward_ads - load_before: đã có / đang load")
            return
        }
        guard Admob.shared.canRequestAds(config: config, logName: nil) else { return }
        loadingConsecutive.insert(idAds)
        RewardedAd.load(with: idAds, request: Request()) { [weak self] ad, _ in
            onMain {
                guard let self else { return }
                self.loadingConsecutive.remove(idAds)
                if let ad { self.rewardAds[idAds] = ad }
            }
        }
    }

    /// Show đủ `count` lần reward (chỉ tính lần user xem hết). Ads chưa sẵn sàng thì load & show.
    func showRewardConsecutive(idAds: String, config: Bool, count: Int, name: String, onFailed: (() -> Void)?, onCompleted: @escaping () -> Void) {
        var current = 0

        func showNext() {
            if current >= count {
                onCompleted()
                return
            }
            var isRewardEarned = false
            let callbacks = AdCallbacks(
                onAdDisable: { onFailed?() },
                onAdFailedToLoad: { _ in onFailed?() },
                onAdFailedToShow: { _ in onFailed?() },
                onAdDismiss: {
                    if isRewardEarned { current += 1 }
                    showNext()
                },
                onUserEarnedReward: { isRewardEarned = true }
            )

            if let ad = rewardAds.removeValue(forKey: idAds) {
                guard Admob.shared.canRequestAds(config: config, logName: name) else {
                    onFailed?()
                    return
                }
                present(ad, idAds: idAds, logName: name, format: "reward", closeLoading: false, callbacks: callbacks)
                loadRewardAdConsecutive(idAds: idAds, config: config)
            } else {
                loadAndShowRewardAds(idAds: idAds, config: config, name: name, callbacks: callbacks)
            }
        }

        showNext()
    }

    // MARK: - Preload

    func loadRewardAdPreload(idAds: String, config: Bool, onAdLoaded: (() -> Void)?, onAdFailedToLoad: ((String) -> Void)?) {
        guard Admob.shared.canRequestAds(config: config, logName: "reward_preload") else {
            onAdFailedToLoad?("can_not_request")
            return
        }
        PreloadFlow.load(.reward, idAds: idAds, bufferSize: Admob.shared.rewardPreloadBuffer, logName: "reward_preload",
                         onAdLoaded: onAdLoaded, onAdFailedToLoad: onAdFailedToLoad)
    }

    func showRewardAdPreload(idAds: String, config: Bool, name: String, isShowLoading: Bool, callbacks: AdCallbacks, onNext: @escaping () -> Void) {
        guard Admob.shared.canRequestAds(config: config, logName: name) else {
            onNext()
            return
        }
        PreloadFlow.show(isShowLoading: isShowLoading, callbacks: callbacks, onNext: onNext) { closeLoading, wrapped in
            self.presentPreloaded(idAds: idAds, name: name, closeLoading: closeLoading, callbacks: wrapped)
        }
    }

    func loadAndShowRewardAdPreload(idAds: String, config: Bool, name: String, callbacks: AdCallbacks, onNext: @escaping () -> Void) {
        PreloadFlow.loadAndShow(.reward, idAds: idAds, bufferSize: Admob.shared.rewardPreloadBuffer, config: config,
                                name: name, callbacks: callbacks, onNext: onNext) { [weak self] closeLoading, wrapped in
            self?.presentPreloaded(idAds: idAds, name: name, closeLoading: closeLoading, callbacks: wrapped) ?? false
        }
    }
}
