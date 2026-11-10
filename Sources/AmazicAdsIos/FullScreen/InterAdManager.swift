import Foundation
import GoogleMobileAds
import UIKit

/// Port `inter_ads_manager.dart`.
/// - Load thường: `InterstitialAd.load`.
/// - Preload: Ad Preloading của SDK (`InterstitialAdPreloader`, preload ID = ad unit id).
/// Đã bỏ timeout 20s và delay 7s native splash — splash chỉ còn timeout 12s ở `Admob`.
public final class InterAdManager {
    public static let shared = InterAdManager()
    private init() {}

    /// Inter splash load xong nhưng chưa show (vd: về sau timeout) -> dùng cho `Admob.showAdsSplash`.
    private var splashAd: InterstitialAd?
    var hasSplashAd: Bool { splashAd != nil }

    public func isAdAvailable(idAds: String) -> Bool {
        AdPreloadCenter.shared.isAvailable(.inter, adUnitId: idAds)
    }

    /// Dừng preload + xoá ads của id.
    public func destroy(idAds: String) {
        AdPreloadCenter.shared.stop(.inter, adUnitId: idAds)
    }

    // MARK: - Helper

    private func attachRevenue(_ ad: InterstitialAd, idAds: String, format: String) {
        ad.paidEventHandler = { [weak ad] adValue in
            Revenue.track(adValue, responseInfo: ad?.responseInfo, adUnitId: idAds, format: format)
        }
    }

    private func logMediation(_ ad: InterstitialAd, name: String) {
        let winner = ad.responseInfo.loadedAdNetworkResponseInfo
        AdsLog.d("=== MEDIATION WINNER \(name) === network: \(winner?.adSourceName ?? "") class: \(winner?.adNetworkClassName ?? "")")
    }

    private func present(_ ad: InterstitialAd, idAds: String, logName: String?, format: String, closeLoading: Bool, isInter: Bool, callbacks: AdCallbacks) {
        attachRevenue(ad, idAds: idAds, format: format)
        FullScreenPresenter.show(
            ad: ad,
            logName: logName,
            closeLoading: closeLoading,
            callbacks: callbacks,
            onDismissExtra: isInter ? { AdHelper.setLastTimeDismissInter() } : nil
        ) { vc in
            ad.present(from: vc)
        }
    }

    /// Lấy 1 inter từ preloader rồi present.
    private func presentPreloaded(idAds: String, name: String, closeLoading: Bool, callbacks: AdCallbacks) -> Bool {
        guard let ad = AdPreloadCenter.shared.takeInter(idAds) else { return false }
        present(ad, idAds: idAds, logName: name, format: name, closeLoading: closeLoading, isInter: true, callbacks: callbacks)
        return true
    }

    // MARK: - Splash (load thường)

    func loadAndShowInterSplash(idAds: String, config: Bool, callbacks: AdCallbacks) {
        guard Admob.shared.canRequestAds(config: config, logName: "inter_splash") else {
            callbacks.onAdDisable?()
            return
        }
        let showLoading = !Admob.shared.isUseNativeSplash
        if showLoading { LoadingOverlay.shared.show() }
        EventLog.logEvent("inter_splash_true")
        AdsLog.d("inter_ads_splash: start request")

        InterstitialAd.load(with: idAds, request: Request()) { [weak self] ad, error in
            onMain {
                guard let self else { return }
                if let ad {
                    AdsLog.d("inter_ads_splash: onAdLoaded")
                    self.logMediation(ad, name: "Inter splash")
                    self.attachRevenue(ad, idAds: idAds, format: "inter_splash")
                    self.splashAd = ad
                    callbacks.onAdLoaded?()
                    EventLog.logEvent("inter_splash_check_show", parameters: ["message": "isNextTimeout_\(Admob.shared.isNextTimeout)"])
                    if Admob.shared.beginSplashAdPresentation() {
                        self.showInterAdsSplash(callbacks: callbacks)
                    } else {
                        AdsLog.d("inter_ads_splash: đã timeout -> giữ ads cho showAdsSplash")
                    }
                } else {
                    let message = error?.localizedDescription ?? "unknown"
                    AdsLog.d("inter_ads_splash: onAdFailedToLoad \(message)")
                    EventLog.logEvent("inter_splash_fail", parameters: ["error": message])
                    Admob.shared.isFullScreenAdShowing = false
                    if showLoading { LoadingOverlay.shared.hide() }
                    callbacks.onAdFailedToLoad?(message)
                }
            }
        }
    }

    func showInterAdsSplash(callbacks: AdCallbacks) {
        let closeLoading = !Admob.shared.isUseNativeSplash
        guard let ad = splashAd else {
            AdsLog.d("inter_ads_splash: not show ad = null")
            EventLog.logEvent("inter_splash_show_fail", parameters: ["error": "mInterstitialAdSplash_null"])
            if closeLoading { LoadingOverlay.shared.hide() }
            Admob.shared.isFullScreenAdShowing = false
            callbacks.onAdDismiss?()
            return
        }
        var wrapped = callbacks
        wrapped.onAdImpression = { [weak self] in
            EventLog.logEvent("inter_splash_view")
            self?.splashAd = nil
            callbacks.onAdImpression?()
        }
        wrapped.onAdFailedToShow = { [weak self] message in
            EventLog.logEvent("inter_splash_fail", parameters: ["error": message])
            self?.splashAd = nil
            callbacks.onAdFailedToShow?(message)
        }
        FullScreenPresenter.show(ad: ad, logName: nil, closeLoading: closeLoading, callbacks: wrapped) { vc in
            AdsLog.d("inter_ads_splash: show")
            ad.present(from: vc)
        }
    }

    // MARK: - Splash (preload)

    func loadAndShowInterSplashAdPreload(idAds: String, config: Bool, callbacks: AdCallbacks) {
        guard Admob.shared.canRequestAds(config: config, logName: "inter_splash") else {
            callbacks.onAdDisable?()
            return
        }
        let center = AdPreloadCenter.shared
        let showLoading = !Admob.shared.isUseNativeSplash
        if showLoading { LoadingOverlay.shared.show() }
        EventLog.logEvent("inter_splash_true")
        center.start(.inter, adUnitId: idAds, bufferSize: Admob.shared.splashPreloadBuffer)

        let showNow: () -> Void = { [weak self] in
            guard let self else { return }
            callbacks.onAdLoaded?()
            EventLog.logEvent("inter_splash_check_show", parameters: ["message": "isNextTimeout_\(Admob.shared.isNextTimeout)"])
            guard Admob.shared.beginSplashAdPresentation(), let ad = center.takeInter(idAds) else { return }
            // Splash chỉ dùng 1 lần -> dừng preload id splash để không chiếm chỗ (tối đa 6 ads toàn app).
            center.stop(.inter, adUnitId: idAds)
            var wrapped = callbacks
            wrapped.onAdFailedToShow = { message in
                EventLog.logEvent("inter_splash_fail", parameters: ["error": message])
                callbacks.onAdFailedToShow?(message)
            }
            self.present(ad, idAds: idAds, logName: nil, format: "inter_splash_preload", closeLoading: showLoading, isInter: false, callbacks: wrapped)
        }

        if center.isAvailable(.inter, adUnitId: idAds) {
            showNow()
            return
        }
        center.waitForAd(idAds, onAvailable: showNow, onFailed: { message in
            AdsLog.d("Inter Ad Preload Splash: onAdFailedToLoad \(message)")
            Admob.shared.isFullScreenAdShowing = false
            if showLoading { LoadingOverlay.shared.hide() }
            center.stop(.inter, adUnitId: idAds)
            callbacks.onAdFailedToLoad?(message)
        })
    }

    // MARK: - Load & show thường

    func loadAndShowInterAds(idAds: String, config: Bool, name: String, callbacks: AdCallbacks) {
        guard Admob.shared.canRequestAds(config: config, logName: name) else {
            callbacks.onAdDisable?()
            return
        }
        AdsLog.d("inter_ads: start request \(idAds)")
        LoadingOverlay.shared.show()
        EventLog.logEvent("\(name)_true")

        InterstitialAd.load(with: idAds, request: Request()) { [weak self] ad, error in
            onMain {
                guard let self else { return }
                guard let ad else {
                    let message = error?.localizedDescription ?? "unknown"
                    AdsLog.d("inter_ads: onAdFailedToLoad \(message)")
                    EventLog.logEvent("\(name)_fail", parameters: ["error": message])
                    Admob.shared.isFullScreenAdShowing = false
                    LoadingOverlay.shared.hide()
                    callbacks.onAdFailedToLoad?(message)
                    return
                }
                AdsLog.d("inter_ads: onAdLoaded")
                self.logMediation(ad, name: name)
                callbacks.onAdLoaded?()
                self.present(ad, idAds: idAds, logName: name, format: name, closeLoading: true, isInter: true, callbacks: callbacks)
            }
        }
    }

    // MARK: - Preload

    func loadInterAdPreload(idAds: String, nameConfig: String, onAdLoaded: (() -> Void)?, onAdFailedToLoad: ((String) -> Void)?) {
        let config = AdsRemoteConfig.getBool(nameConfig)
        guard Admob.shared.canRequestAds(config: config, logName: nameConfig) else {
            onAdFailedToLoad?("config_\(nameConfig),canRequestAds_\(Admob.shared.canRequestAdsConsent),isShowAllAds_\(Admob.shared.isShowAllAds),isNetwork_\(Admob.shared.isNetworkActive())")
            return
        }
        PreloadFlow.load(.inter, idAds: idAds, bufferSize: Admob.shared.interPreloadBuffer, logName: nameConfig,
                         onAdLoaded: onAdLoaded, onAdFailedToLoad: onAdFailedToLoad)
    }

    func showInterAdPreload(idAds: String, config: Bool, name: String, isShowLoading: Bool, callbacks: AdCallbacks, onNext: @escaping () -> Void) {
        guard Admob.shared.canRequestAds(config: config, logName: name) else {
            onNext()
            return
        }
        PreloadFlow.show(isShowLoading: isShowLoading, callbacks: callbacks, onNext: onNext) { closeLoading, wrapped in
            self.presentPreloaded(idAds: idAds, name: name, closeLoading: closeLoading, callbacks: wrapped)
        }
    }

    func loadAndShowInterAdPreload(idAds: String, config: Bool, name: String, callbacks: AdCallbacks, onNext: @escaping () -> Void) {
        PreloadFlow.loadAndShow(.inter, idAds: idAds, bufferSize: Admob.shared.interPreloadBuffer, config: config,
                                name: name, callbacks: callbacks, onNext: onNext) { [weak self] closeLoading, wrapped in
            self?.presentPreloaded(idAds: idAds, name: name, closeLoading: closeLoading, callbacks: wrapped) ?? false
        }
    }
}
