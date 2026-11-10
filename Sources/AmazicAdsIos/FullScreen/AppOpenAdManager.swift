import Foundation
import GoogleMobileAds
import UIKit

/// Port `app_open_manager.dart`.
/// - Load thường: `AppOpenAd.load`.
/// - Preload: Ad Preloading của SDK (`AppOpenAdPreloader`, preload ID = ad unit id).
/// Đã bỏ timeout 20s splash và timeout 12s resume preload.
public final class AppOpenAdManager {
    public static let shared = AppOpenAdManager()
    private init() {}

    private var splashAd: AppOpenAd?
    var hasSplashAd: Bool { splashAd != nil }

    public func isAdAvailable(idAds: String) -> Bool {
        AdPreloadCenter.shared.isAvailable(.appOpen, adUnitId: idAds)
    }

    public func destroy(idAds: String) {
        AdPreloadCenter.shared.stop(.appOpen, adUnitId: idAds)
    }

    // MARK: - Helper

    private func attachRevenue(_ ad: AppOpenAd, idAds: String, format: String) {
        ad.paidEventHandler = { [weak ad] adValue in
            Revenue.track(adValue, responseInfo: ad?.responseInfo, adUnitId: idAds, format: format)
        }
    }

    private func present(_ ad: AppOpenAd, idAds: String, logName: String?, format: String, closeLoading: Bool, callbacks: AdCallbacks) {
        attachRevenue(ad, idAds: idAds, format: format)
        FullScreenPresenter.show(ad: ad, logName: logName, closeLoading: closeLoading, callbacks: callbacks) { vc in
            ad.present(from: vc)
        }
    }

    private func presentPreloaded(idAds: String, name: String, closeLoading: Bool, callbacks: AdCallbacks) -> Bool {
        guard let ad = AdPreloadCenter.shared.takeAppOpen(idAds) else { return false }
        present(ad, idAds: idAds, logName: name, format: name, closeLoading: closeLoading, callbacks: callbacks)
        return true
    }

    // MARK: - Splash (load thường)

    func loadAndShowAppOpenSplash(idAds: String, config: Bool, callbacks: AdCallbacks) {
        guard Admob.shared.canRequestAds(config: config, logName: "open_splash") else {
            callbacks.onAdDisable?()
            return
        }
        let showLoading = !Admob.shared.isUseNativeSplash
        if showLoading { LoadingOverlay.shared.show() }
        EventLog.logEvent("app_open_splash_true")

        AppOpenAd.load(with: idAds, request: Request()) { [weak self] ad, error in
            onMain {
                guard let self else { return }
                if let ad {
                    AdsLog.d("app_open_ads_splash: onAdLoaded")
                    self.attachRevenue(ad, idAds: idAds, format: "app_open_splash")
                    self.splashAd = ad
                    callbacks.onAdLoaded?()
                    EventLog.logEvent("open_splash_check_show", parameters: ["message": "isNextTimeout_\(Admob.shared.isNextTimeout)"])
                    if Admob.shared.beginSplashAdPresentation() {
                        self.showAppOpenAdsSplash(callbacks: callbacks)
                    }
                } else {
                    let message = error?.localizedDescription ?? "unknown"
                    AdsLog.d("app_open_ads_splash: onAdFailedToLoad \(message)")
                    EventLog.logEvent("open_splash_fail", parameters: ["error": message])
                    Admob.shared.isFullScreenAdShowing = false
                    if showLoading { LoadingOverlay.shared.hide() }
                    callbacks.onAdFailedToLoad?(message)
                }
            }
        }
    }

    func showAppOpenAdsSplash(callbacks: AdCallbacks) {
        let closeLoading = !Admob.shared.isUseNativeSplash
        guard let ad = splashAd else {
            if closeLoading { LoadingOverlay.shared.hide() }
            Admob.shared.isFullScreenAdShowing = false
            callbacks.onAdDismiss?()
            return
        }
        var wrapped = callbacks
        wrapped.onAdImpression = { [weak self] in
            EventLog.logEvent("open_splash_view")
            self?.splashAd = nil
            callbacks.onAdImpression?()
        }
        wrapped.onAdFailedToShow = { [weak self] message in
            EventLog.logEvent("open_splash_fail", parameters: ["error": message])
            self?.splashAd = nil
            callbacks.onAdFailedToShow?(message)
        }
        FullScreenPresenter.show(ad: ad, logName: nil, closeLoading: closeLoading, callbacks: wrapped) { vc in
            ad.present(from: vc)
        }
    }

    // MARK: - Splash (preload)

    func loadAndShowAppOpenSplashAdPreload(idAds: String, config: Bool, callbacks: AdCallbacks) {
        guard Admob.shared.canRequestAds(config: config, logName: "open_splash") else {
            callbacks.onAdDisable?()
            return
        }
        let center = AdPreloadCenter.shared
        let showLoading = !Admob.shared.isUseNativeSplash
        if showLoading { LoadingOverlay.shared.show() }
        EventLog.logEvent("app_open_splash_true")
        center.start(.appOpen, adUnitId: idAds, bufferSize: Admob.shared.splashPreloadBuffer)

        let showNow: () -> Void = { [weak self] in
            guard let self else { return }
            callbacks.onAdLoaded?()
            guard Admob.shared.beginSplashAdPresentation(), let ad = center.takeAppOpen(idAds) else { return }
            center.stop(.appOpen, adUnitId: idAds)
            var wrapped = callbacks
            wrapped.onAdFailedToShow = { message in
                EventLog.logEvent("open_splash_fail", parameters: ["error": message])
                callbacks.onAdFailedToShow?(message)
            }
            self.present(ad, idAds: idAds, logName: nil, format: "app_open_splash_preload", closeLoading: showLoading, callbacks: wrapped)
        }

        if center.isAvailable(.appOpen, adUnitId: idAds) {
            showNow()
            return
        }
        center.waitForAd(idAds, onAvailable: showNow, onFailed: { message in
            Admob.shared.isFullScreenAdShowing = false
            if showLoading { LoadingOverlay.shared.hide() }
            center.stop(.appOpen, adUnitId: idAds)
            callbacks.onAdFailedToLoad?(message)
        })
    }

    // MARK: - Load & show thường (resume / thủ công)

    func loadAndShowAppOpenAds(idAds: String, config: Bool, name: String, callbacks: AdCallbacks) {
        guard Admob.shared.canRequestAds(config: config, logName: name) else {
            callbacks.onAdDisable?()
            return
        }
        LoadingOverlay.shared.show()
        EventLog.logEvent("\(name)_true")

        AppOpenAd.load(with: idAds, request: Request()) { [weak self] ad, error in
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

    // MARK: - Preload

    public func loadAppOpenAdPreload(idAds: String, config: Bool, onAdLoaded: (() -> Void)? = nil, onAdFailedToLoad: ((String) -> Void)? = nil) {
        guard Admob.shared.canRequestAds(config: config, logName: "app_open_preload") else {
            onAdFailedToLoad?("can_not_request")
            return
        }
        PreloadFlow.load(.appOpen, idAds: idAds, bufferSize: Admob.shared.appOpenPreloadBuffer, logName: "app_open_preload",
                         onAdLoaded: onAdLoaded, onAdFailedToLoad: onAdFailedToLoad)
    }

    public func showAppOpenAdPreload(idAds: String, config: Bool, name: String, isShowLoading: Bool = true, callbacks: AdCallbacks = AdCallbacks(), onNext: (() -> Void)? = nil) {
        let (resolved, next) = callbacks.withNext(onNext)
        guard Admob.shared.canRequestAds(config: config, logName: name) else {
            next()
            return
        }
        PreloadFlow.show(isShowLoading: isShowLoading, callbacks: resolved, onNext: next) { closeLoading, wrapped in
            self.presentPreloaded(idAds: idAds, name: name, closeLoading: closeLoading, callbacks: wrapped)
        }
    }

    /// Dùng cho resume khi bật preload.
    public func loadAndShowAppOpenAdPreload(idAds: String, config: Bool, name: String, callbacks: AdCallbacks = AdCallbacks(), onNext: (() -> Void)? = nil) {
        let (resolved, next) = callbacks.withNext(onNext)
        PreloadFlow.loadAndShow(.appOpen, idAds: idAds, bufferSize: Admob.shared.appOpenPreloadBuffer, config: config,
                                name: name, callbacks: resolved, onNext: next) { [weak self] closeLoading, wrapped in
            self?.presentPreloaded(idAds: idAds, name: name, closeLoading: closeLoading, callbacks: wrapped) ?? false
        }
    }
}
