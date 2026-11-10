import Foundation
import UIKit

/// Port `app_lifecycle_reactor.dart`: show App Open khi app quay lại từ background.
/// Chỉ tính khi app thật sự vào background (didEnterBackground), không tính kéo Control Center / alert hệ thống.
public final class AppLifecycleReactor {
    let idAds: String
    let nameResumeConfig: String
    /// false: show WelcomeBack trước ads, true: show WelcomeBack sau ads.
    let isShowWelcomeScreenAfterAppOpenAds: Bool
    let name: String
    let onGotoWelcomeBack: (() -> Void)?

    /// Tắt resume 1 lần (vd: trước khi mở share sheet, mở app khác...). Tự reset sau lần quay lại kế tiếp.
    public var isDisableAdResume = false
    public var isShowScreenWelcomeBack = false
    var isOnSplashScreen = true

    /// Hook đóng / mở lại collapsible banner khi show màn welcome back.
    public var onCloseCollapseBanner: (() -> Void)?
    public var onReloadCollapseBanner: (() -> Void)?

    private var wasInBackground = false
    private var observers: [NSObjectProtocol] = []

    init(idAds: String, nameResumeConfig: String, isShowWelcomeScreenAfterAppOpenAds: Bool, name: String, onGotoWelcomeBack: (() -> Void)?) {
        self.idAds = idAds
        self.nameResumeConfig = nameResumeConfig
        self.isShowWelcomeScreenAfterAppOpenAds = isShowWelcomeScreenAfterAppOpenAds
        self.name = name
        self.onGotoWelcomeBack = onGotoWelcomeBack
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    public func setDisableAdResume(_ value: Bool) {
        isDisableAdResume = value
    }

    func listenToAppStateChanges() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.wasInBackground = true
        })
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.wasInBackground else { return }
            self.wasInBackground = false
            self.onForeground()
        })
    }

    public func setShowScreenWelcomeBack() {
        guard let onGotoWelcomeBack, !isShowScreenWelcomeBack else { return }
        AdsLog.d("app_open: show screen welcomeback")
        isShowScreenWelcomeBack = true
        onGotoWelcomeBack()
    }

    private func onForeground() {
        if isOnSplashScreen { return }

        onCloseCollapseBanner?()

        let config = AdsRemoteConfig.getBool(nameResumeConfig)
        AdsLog.d("app_open: start, config = \(config)")
        if !config {
            isShowScreenWelcomeBack = false
            setShowScreenWelcomeBack()
            return
        }

        if isDisableAdResume {
            AdsLog.d("app_open: disable ads resume")
            isDisableAdResume = false
            return
        }

        let admob = Admob.shared
        if admob.isFullScreenAdShowing || !admob.isShowAllAds || !admob.isNetworkActive() || !ConsentManager.shared.canRequestAds {
            AdsLog.d("app_open: not show")
            return
        }

        guard isShowWelcomeScreenAfterAppOpenAds else {
            AdsLog.d("app_open: show welcomeback before ads")
            isShowScreenWelcomeBack = false
            setShowScreenWelcomeBack()
            return
        }

        let next: () -> Void = { [weak self] in
            self?.isShowScreenWelcomeBack = false
            self?.setShowScreenWelcomeBack()
        }

        if admob.isUseAdPreloading {
            AppOpenAdManager.shared.loadAndShowAppOpenAdPreload(idAds: idAds, config: config, name: name, onNext: next)
        } else {
            admob.loadAndShowAppOpenAds(idAds: idAds, config: config, name: name, callbacks: AdCallbacks(
                onAdDisable: next,
                onAdFailedToLoad: { _ in next() },
                onAdFailedToShow: { _ in next() },
                onAdDismiss: next
            ))
        }
    }

    /// Dùng ở màn Welcome Back (trường hợp show WelcomeBack trước ads): bấm tiếp tục -> show app open.
    public func loadAndShowAppOpenAds(callbacks: AdCallbacks) {
        onCloseCollapseBanner?()
        let finish: (() -> Void) -> Void = { [weak self] action in
            self?.isShowScreenWelcomeBack = false
            action()
            self?.onReloadCollapseBanner?()
        }
        guard !isShowWelcomeScreenAfterAppOpenAds else {
            finish { callbacks.onAdDisable?() }
            return
        }
        Admob.shared.loadAndShowAppOpenAds(
            idAds: idAds,
            config: AdsRemoteConfig.getBool(nameResumeConfig),
            name: name,
            callbacks: AdCallbacks(
                onAdDisable: { finish { callbacks.onAdDisable?() } },
                onAdImpression: callbacks.onAdImpression,
                onAdClicked: callbacks.onAdClicked,
                onAdFailedToLoad: { e in finish { callbacks.onAdFailedToLoad?(e) } },
                onAdFailedToShow: { e in finish { callbacks.onAdFailedToShow?(e) } },
                onAdDismiss: { finish { callbacks.onAdDismiss?() } }
            )
        )
    }
}
