import Foundation
import GoogleMobileAds
import SwiftUI
import UIKit

/// Tham số khởi tạo splash (tương ứng `Admob.instance.init(...)` bên Flutter).
public struct SplashConfig {
    public var linkServer: String
    public var appId: String
    public var packageName: String
    public var jsonIdAdsDefault: String

    public var nameIdAdsResume: String
    public var nameResumeConfig: String
    public var nameIdAdsAppOpenSplash: String
    public var nameIdAdsInterSplash: String
    /// Native after inter (giai đoạn 3).
    public var nameIdAdsNativeAfterInter: String?

    public var nameConfigAppOpenSplash: String
    public var nameConfigInterSplash: String
    public var nameConfigNativeAfterInter: String?

    public var nameRateAoa: String
    public var nameIntervalBetweenInter: String
    public var nameIntervalFromStart: String
    public var nameIntervalInterAll: String

    /// false: show WelcomeBack trước ads resume, true: show WelcomeBack sau ads resume.
    public var isShowWelcomeScreenAfterAppOpenAds: Bool
    public var remoteConfigKeys: [RemoteConfigKey]

    public init(
        linkServer: String,
        appId: String,
        packageName: String,
        jsonIdAdsDefault: String,
        nameIdAdsResume: String,
        nameResumeConfig: String,
        nameIdAdsAppOpenSplash: String,
        nameIdAdsInterSplash: String,
        nameIdAdsNativeAfterInter: String? = nil,
        nameConfigAppOpenSplash: String,
        nameConfigInterSplash: String,
        nameConfigNativeAfterInter: String? = nil,
        nameRateAoa: String,
        nameIntervalBetweenInter: String,
        nameIntervalFromStart: String,
        nameIntervalInterAll: String,
        isShowWelcomeScreenAfterAppOpenAds: Bool,
        remoteConfigKeys: [RemoteConfigKey]
    ) {
        self.linkServer = linkServer
        self.appId = appId
        self.packageName = packageName
        self.jsonIdAdsDefault = jsonIdAdsDefault
        self.nameIdAdsResume = nameIdAdsResume
        self.nameResumeConfig = nameResumeConfig
        self.nameIdAdsAppOpenSplash = nameIdAdsAppOpenSplash
        self.nameIdAdsInterSplash = nameIdAdsInterSplash
        self.nameIdAdsNativeAfterInter = nameIdAdsNativeAfterInter
        self.nameConfigAppOpenSplash = nameConfigAppOpenSplash
        self.nameConfigInterSplash = nameConfigInterSplash
        self.nameConfigNativeAfterInter = nameConfigNativeAfterInter
        self.nameRateAoa = nameRateAoa
        self.nameIntervalBetweenInter = nameIntervalBetweenInter
        self.nameIntervalFromStart = nameIntervalFromStart
        self.nameIntervalInterAll = nameIntervalInterAll
        self.isShowWelcomeScreenAfterAppOpenAds = isShowWelcomeScreenAfterAppOpenAds
        self.remoteConfigKeys = remoteConfigKeys
    }
}

/// Lớp chính của thư viện — tương ứng `Admob.instance` bên Flutter.
/// Tất cả hàm public gọi trên main thread.
public final class Admob {
    public static let shared = Admob()
    private init() {}

    // MARK: - Cấu hình

    /// Bật/tắt toàn bộ ads.
    public var isShowAllAds = true
    /// true khi đang có ads full screen hiển thị.
    public var isFullScreenAdShowing = false
    /// true: inter / app open / reward dùng Ad Preloading của SDK. false: load & show thường.
    public var isUseAdPreloading = false
    /// true: màn splash của app đã có native ads -> không hiện màn "Loading Ads" lúc splash.
    public var isUseNativeSplash = false
    /// Show native full màn sau inter splash (cần `nameIdAdsNativeAfterInter` + `nameConfigNativeAfterInter`).
    public var isUseNativeAfterInter = false
    /// Tự check công nghệ lõi (CNL) + log `inspector_info` lúc initSplash.
    public var isCheckCNLEnabled = true
    /// Layout + style cho màn native after inter của splash.
    public var nativeAfterInterLayout: NativeAdLayout = .fullScreen
    public var nativeAfterInterStyle: NativeAdStyle = .default
    /// Json id ads mặc định khi API lỗi / chậm / không có server.
    public var jsonIdAdsDefault = ""
    /// Timeout duy nhất: tính từ lúc gọi `initSplash` tới khi ads splash bắt đầu hiện.
    public var splashTimeout: TimeInterval = 12

    // Số ads giữ sẵn mỗi preload ID. Google giới hạn tối đa 6 ads preload toàn app.
    public var interPreloadBuffer = 2
    public var rewardPreloadBuffer = 1
    public var appOpenPreloadBuffer = 1
    public var splashPreloadBuffer = 1

    public private(set) var appLifecycleReactor: AppLifecycleReactor?

    // MARK: - Provider cắm từ ngoài (Firebase / Adjust)

    /// Ghi event (vd: Firebase Analytics). nil -> in log console.
    public var eventLogger: AdsEventLogger?
    /// Remote config (vd: Firebase Remote Config). nil -> dùng giá trị mặc định.
    public var remoteConfigProvider: AdsRemoteConfigProvider?
    /// Track doanh thu (vd: Adjust). nil -> in log console.
    public var revenueTracker: AdsRevenueTracker?

    /// Bật/tắt log `admob_ads ---` trên console.
    public var isLogEnabled: Bool {
        get { AdsLog.isEnabled }
        set { AdsLog.isEnabled = newValue }
    }

    // MARK: - Khởi tạo SDK

    private var isAdmobInitialized = false

    /// Gọi 1 lần trong `App.init()`.
    /// Gọi 1 lần lúc mở app.
    /// - Parameter useFirebase: true -> tự bật Firebase nếu app có `GoogleService-Info.plist`
    ///   (nếu app tự gọi `FirebaseApp.configure()` thì gọi trước hàm này).
    public func configure(useFirebase: Bool = true) {
        NetworkMonitor.shared.start()
        if useFirebase {
            FirebaseUtil.shared.setUp()
        }
    }

    /// Khởi động Google Mobile Ads SDK (tự gọi sau khi có consent UMP).
    public func initAdmob() {
        guard !isAdmobInitialized else { return }
        isAdmobInitialized = true
        MobileAds.shared.start(completionHandler: nil)
    }

    public func isNetworkActive() -> Bool {
        NetworkMonitor.shared.isConnected
    }

    /// Kết quả consent purpose 1 (nil nếu chưa có).
    public func getConsentResult() -> Bool? {
        ConsentPurpose.hasConsentPurposeOne()
    }

    var canRequestAdsConsent: Bool { ConsentManager.shared.canRequestAds }

    /// config && consent && isShowAllAds && có mạng. Nếu false thì log `${name}_config_...`.
    func canRequestAds(config: Bool, logName: String?) -> Bool {
        let ump = canRequestAdsConsent
        let network = isNetworkActive()
        let ok = config && ump && isShowAllAds && network
        if !ok, let logName {
            AdsLog.d("\(logName): not load/show (config=\(config), ump=\(ump), showAll=\(isShowAllAds), net=\(network))")
            EventLog.logEvent("\(logName)_config_\(config)_\(ump)_\(isShowAllAds)_\(network)")
        }
        return ok
    }

    /// Chỉ show ads khi app đang active, nếu không thì đợi app active lại.
    func checkAndShowAdForeground(onShow: @escaping () -> Void) {
        onMain {
            if UIApplication.shared.applicationState == .active {
                onShow()
                return
            }
            var token: NSObjectProtocol?
            token = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                if let token { NotificationCenter.default.removeObserver(token) }
                onShow()
            }
        }
    }

    // MARK: - Splash state

    private var splashConfig: SplashConfig?
    private var splashOnNext: (() -> Void)?
    private var splashStarted = false
    /// onNext của splash đã được gọi.
    private var splashCompleted = false
    /// Ads splash đã bắt đầu present -> hết tính timeout.
    private var splashAdPresented = false
    private var splashTimeoutWork: DispatchWorkItem?
    /// true nếu đã hết 12s mà chưa show được ads splash.
    public private(set) var isNextTimeout = false

    private var splashStartTime = Date()
    private var lastStepTime = Date()
    private var splashDeadline = Date()

    func logEventSplashToStep(_ name: String, moreParams: [String: Any] = [:]) {
        let now = Date()
        var params: [String: Any] = [
            "time_to_step": Int(now.timeIntervalSince(splashStartTime)),
            "time_between_step": Int(now.timeIntervalSince(lastStepTime))
        ]
        moreParams.forEach { params[$0.key] = $0.value }
        EventLog.logEvent(name, parameters: params)
        lastStepTime = now
    }

    private func startSplashTimeout(after seconds: TimeInterval? = nil) {
        let delay = seconds ?? splashTimeout
        splashTimeoutWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.handleSplashTimeout() }
        splashTimeoutWork = work
        splashDeadline = Date().addingTimeInterval(delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func handleSplashTimeout() {
        guard !splashCompleted, !splashAdPresented else { return }
        AdsLog.d("Timeout Splash \(Int(splashTimeout))s -> onNext")
        EventLog.logEvent("timeout_splash_12s")
        isNextTimeout = true
        // API chưa trả id thì dùng json mặc định để các màn sau vẫn có ads.
        AdsApi.shared.useDefault(reason: "timeout_splash")
        if !isUseNativeSplash { LoadingOverlay.shared.hide() }
        completeSplash()
    }

    /// Manager gọi ngay trước khi present ads splash. false = đã timeout, không được show.
    func beginSplashAdPresentation() -> Bool {
        guard !splashCompleted, !isNextTimeout else { return false }
        splashAdPresented = true
        splashTimeoutWork?.cancel()
        AdsLog.d("===> TỔNG THỜI GIAN CHỜ ADS SPLASH: \(String(format: "%.1f", Date().timeIntervalSince(splashStartTime))) giây")
        return true
    }

    private func completeSplash() {
        guard !splashCompleted else { return }
        splashCompleted = true
        splashTimeoutWork?.cancel()
        appLifecycleReactor?.isOnSplashScreen = false
        let callback = splashOnNext
        splashOnNext = nil
        callback?()
    }

    // MARK: - Init splash

    /// Khởi tạo (Remote Config + UMP + API id ads) rồi show ads splash.
    /// Có đúng 1 timeout `splashTimeout` (12s) bao toàn bộ splash (kể cả lúc hiện form UMP):
    /// ads load xong lúc nào show lúc đó; hết 12s mà ads chưa hiện -> `onNext`.
    public func initSplash(
        _ config: SplashConfig,
        onGotoScreenWelcomeBack: (() -> Void)? = nil,
        onStartLoadBanner: @escaping () -> Void = {},
        onNext: @escaping () -> Void
    ) {
        guard !splashStarted else { return }
        splashStarted = true
        configure()

        splashConfig = config
        splashOnNext = onNext
        splashStartTime = Date()
        lastStepTime = Date()
        jsonIdAdsDefault = config.jsonIdAdsDefault

        if isNetworkActive() { EventLog.logEvent("splash_open_have_internet") }
        AdsPreferences.increaseCountOpenApp()
        if isCheckCNLEnabled { CNLChecker.shared.startingCheckCNL() }

        startSplashTimeout()
        EventLog.logEvent("splash_async_init")

        var isUmpDone = false
        var isApiDone = false
        let continueIfReady = { [weak self] in
            guard let self, isUmpDone, isApiDone else { return }
            self.onUmpAndApiDone(config, onGotoScreenWelcomeBack: onGotoScreenWelcomeBack, onStartLoadBanner: onStartLoadBanner)
        }

        // Remote Config
        logEventSplashToStep("splash_start_firebase")
        AdsRemoteConfig.initialize(keys: config.remoteConfigKeys) { [weak self] in
            self?.logEventSplashToStep("splash_done_firebase")
        }

        // API id ads
        logEventSplashToStep("splash_start_idapi")
        AdsApi.shared.callAds(linkServer: config.linkServer, appId: config.appId, packageName: config.packageName) { [weak self] in
            self?.logEventSplashToStep("splash_done_idapi")
            isApiDone = true
            continueIfReady()
        }

        // UMP
        logEventSplashToStep("splash_start_ump")
        ConsentManager.shared.handleRequestUmp { [weak self] in
            guard let self else { return }
            if ConsentManager.shared.canRequestAds {
                self.logEventSplashToStep("splash_ump_done_consent")
                isUmpDone = true
                continueIfReady()
            } else {
                self.logEventSplashToStep("splash_ump_done_donotconsent")
                self.completeSplash()
            }
        }
    }

    private func onUmpAndApiDone(
        _ config: SplashConfig,
        onGotoScreenWelcomeBack: (() -> Void)?,
        onStartLoadBanner: @escaping () -> Void
    ) {
        AdsLog.d("Done UMP + API id ads -> init ads splash")

        if isUseNativeAfterInter, let key = config.nameIdAdsNativeAfterInter, let remote = config.nameConfigNativeAfterInter {
            preloadNativeAfterInter(adsKey: key, remoteKey: remote)
        }

        onStartLoadBanner()
        logEventSplashToStep("splash_init_ad_splash")

        let reactor = AppLifecycleReactor(
            idAds: AdsApi.shared.getFirstIDByName(config.nameIdAdsResume),
            nameResumeConfig: config.nameResumeConfig,
            isShowWelcomeScreenAfterAppOpenAds: config.isShowWelcomeScreenAfterAppOpenAds,
            name: config.nameIdAdsResume,
            onGotoWelcomeBack: onGotoScreenWelcomeBack
        )
        reactor.isOnSplashScreen = !splashCompleted
        reactor.listenToAppStateChanges()
        appLifecycleReactor = reactor

        AdHelper.initialize(
            intervalBetweenInter: Int64(AdsRemoteConfig.getInt(config.nameIntervalBetweenInter)) * 1000,
            intervalFromStart: Int64(AdsRemoteConfig.getInt(config.nameIntervalFromStart)) * 1000,
            intervalInterAll: Int64(AdsRemoteConfig.getInt(config.nameIntervalInterAll)) * 1000,
            configAppOpen: AdsRemoteConfig.getBool(config.nameConfigAppOpenSplash),
            configInter: AdsRemoteConfig.getBool(config.nameConfigInterSplash),
            rateAoa: AdsRemoteConfig.getString(config.nameRateAoa)
        )

        guard !splashCompleted, !isNextTimeout else { return }
        initAndShowAdSplash(config)
    }

    private func initAndShowAdSplash(_ config: SplashConfig) {
        let idAppOpen = AdsApi.shared.getFirstIDByName(config.nameIdAdsAppOpenSplash)
        let idInter = AdsApi.shared.getFirstIDByName(config.nameIdAdsInterSplash)
        let configAppOpen = AdsRemoteConfig.getBool(config.nameConfigAppOpenSplash)
        let configInter = AdsRemoteConfig.getBool(config.nameConfigInterSplash)
        let rateAoa = AdsRemoteConfig.getString(config.nameRateAoa)

        let onImpression: () -> Void = { [weak self] in
            guard let self else { return }
            AdsLog.d("time show ads splash - \(Int(Date().timeIntervalSince(self.splashStartTime)))s")
            self.logEventSplashToStep("splash_ad_show")
        }
        let onClick: () -> Void = {
            EventLog.logEvent("inter_splash_click_\(AdsPreferences.countOpenApp)")
        }

        logEventSplashToStep("splash_ad_start_loadandshow")
        let splashType = AdHelper.splashType
        AdsLog.d("splash type = \(splashType), preload = \(isUseAdPreloading)")

        switch splashType {
        case .open:
            let callbacks = AdCallbacks(
                onAdDisable: { [weak self] in self?.completeSplash() },
                onAdImpression: onImpression,
                onAdClicked: onClick,
                onAdFailedToLoad: { [weak self] error in
                    self?.logEventSplashToStep("splash_ad_failload", moreParams: ["error": error])
                    self?.completeSplash()
                },
                onAdFailedToShow: { [weak self] error in
                    self?.logEventSplashToStep("splash_ad_failshow", moreParams: ["error": error])
                    self?.completeSplash()
                },
                onAdDismiss: { [weak self] in self?.completeSplash() }
            )
            if isUseAdPreloading {
                AppOpenAdManager.shared.loadAndShowAppOpenSplashAdPreload(idAds: idAppOpen, config: configAppOpen, callbacks: callbacks)
            } else {
                AppOpenAdManager.shared.loadAndShowAppOpenSplash(idAds: idAppOpen, config: configAppOpen, callbacks: callbacks)
            }

        case .inter:
            let callbacks = AdCallbacks(
                onAdDisable: { [weak self] in self?.nextSplashAfterInter() },
                onAdImpression: onImpression,
                onAdClicked: onClick,
                onAdFailedToLoad: { [weak self] error in
                    self?.logEventSplashToStep("splash_ad_failload", moreParams: ["error": error])
                    self?.nextSplashAfterInter()
                },
                onAdFailedToShow: { [weak self] error in
                    self?.logEventSplashToStep("splash_ad_failshow", moreParams: ["error": error])
                    self?.nextSplashAfterInter()
                },
                onAdDismiss: { [weak self] in self?.nextSplashAfterInter() }
            )
            if isUseAdPreloading {
                InterAdManager.shared.loadAndShowInterSplashAdPreload(idAds: idInter, config: configInter, callbacks: callbacks)
            } else {
                InterAdManager.shared.loadAndShowInterSplash(idAds: idInter, config: configInter, callbacks: callbacks)
            }

        case .none:
            completeSplash()
        }

        let ump = getConsentResult().map { "\($0)" } ?? "null"
        let net = isNetworkActive()
        EventLog.logEvent("inter_splash_tracking", parameters: [
            "splash_detail": "\(ump)_\(net)_\(isShowAllAds)_\(rateAoa)",
            "ump": ump,
            "haveinternet": "\(net)",
            "showallad": "\(isShowAllAds)",
            "interremote_openremote_aoavalue": "\(configInter)_\(configAppOpen)_\(rateAoa)"
        ])
    }

    /// Sau inter splash: nếu native after inter đã load xong + remote bật -> show native full màn, đóng mới onNext.
    private func nextSplashAfterInter() {
        guard !splashCompleted else { return }
        if isUseNativeAfterInter,
           let config = splashConfig,
           let key = config.nameIdAdsNativeAfterInter,
           let remote = config.nameConfigNativeAfterInter,
           NativeAdPreloadManager.shared.isAdReady(key),
           AdsRemoteConfig.getBool(remote) {
            AdsLog.d("splash: show native after inter")
            splashCompleted = true
            splashTimeoutWork?.cancel()
            appLifecycleReactor?.isOnSplashScreen = false
            let callback = splashOnNext
            splashOnNext = nil
            startShowNativeAfterInter(adsKey: key, remoteKey: remote) { callback?() }
        } else {
            completeSplash()
        }
    }

    // MARK: - Native after inter

    /// Preload native cho màn native after inter (tự gọi trong splash nếu bật `isUseNativeAfterInter`).
    public func preloadNativeAfterInter(adsKey: String, remoteKey: String) {
        let id = AdsApi.shared.getFirstIDByName(adsKey)
        AdsLog.d("preload_native: load \(adsKey) id - \(id)")
        NativeAdPreloadManager.shared.preloadAd(
            adUnitId: id,
            config: AdsRemoteConfig.getBool(remoteKey),
            nameIdAds: adsKey,
            name: adsKey
        )
    }

    /// Present màn native full screen (dùng native đã preload theo `adsKey`), bấm đóng -> dismiss + onClose.
    public func startShowNativeAfterInter(
        adsKey: String,
        remoteKey: String,
        layout: NativeAdLayout? = nil,
        style: NativeAdStyle? = nil,
        onClose: @escaping () -> Void
    ) {
        let layout = layout ?? nativeAfterInterLayout
        let style = style ?? nativeAfterInterStyle
        onMain {
            guard let top = UIHelper.topViewController else {
                onClose()
                return
            }
            var hostRef: UIViewController?
            let screen = NativeAfterInterScreen(adsKey: adsKey, remoteKey: remoteKey, layout: layout, style: style) {
                hostRef?.dismiss(animated: false) { onClose() }
                hostRef = nil
            }
            let host = UIHostingController(rootView: screen)
            host.modalPresentationStyle = .fullScreen
            host.view.backgroundColor = .black
            hostRef = host
            top.present(host, animated: false)
        }
    }

    /// Show ads splash đã load muộn (sau timeout) — thường gọi ở nút tick màn Language.
    public func showAdsSplash(onNext: @escaping () -> Void) {
        let callbacks = AdCallbacks(
            onAdFailedToShow: { _ in onNext() },
            onAdDismiss: onNext
        )
        if InterAdManager.shared.hasSplashAd {
            InterAdManager.shared.showInterAdsSplash(callbacks: callbacks)
        } else if AppOpenAdManager.shared.hasSplashAd {
            AppOpenAdManager.shared.showAppOpenAdsSplash(callbacks: callbacks)
        } else {
            onNext()
        }
    }

    // MARK: - Inter
    //
    // Mọi hàm đều nhận `callbacks.onNext` (hoặc tham số `onNext`): chạy đúng 1 lần khi ads kết thúc
    // (disable / load lỗi / show lỗi / đóng ads) -> chỉ cần đặt chuyển màn ở onNext.

    public func loadAndShowInterAds(idAds: String, config: Bool, name: String, callbacks: AdCallbacks = AdCallbacks()) {
        let resolved = callbacks.withNext().callbacks
        InterAdManager.shared.loadAndShowInterAds(idAds: idAds, config: config, name: name, callbacks: resolved)
    }

    /// Inter có check interval (between / from start / inter all).
    public func loadAndShowInterInterval(idAds: String, config: Bool, isInterAll: Bool, name: String, callbacks: AdCallbacks = AdCallbacks()) {
        let resolved = callbacks.withNext().callbacks
        guard AdHelper.canShowNextInter(isInterAll: isInterAll) else {
            AdsLog.d("inter_ads: not canShowNextInter")
            resolved.onAdDisable?()
            return
        }
        let markInterAll = {
            if isInterAll { AdHelper.isFirstShowInterAll = true }
        }
        var wrapped = resolved
        wrapped.onAdDisable = { markInterAll(); resolved.onAdDisable?() }
        wrapped.onAdFailedToShow = { e in markInterAll(); resolved.onAdFailedToShow?(e) }
        wrapped.onAdFailedToLoad = { e in markInterAll(); resolved.onAdFailedToLoad?(e) }
        wrapped.onAdDismiss = { markInterAll(); resolved.onAdDismiss?() }
        InterAdManager.shared.loadAndShowInterAds(idAds: idAds, config: config, name: name, callbacks: wrapped)
    }

    /// Bắt đầu preload inter (giữ sẵn `interPreloadBuffer` ads, tự load bù).
    public func loadInterAdPreload(idAds: String, nameConfig: String, onAdLoaded: (() -> Void)? = nil, onAdFailedToLoad: ((String) -> Void)? = nil) {
        InterAdManager.shared.loadInterAdPreload(idAds: idAds, nameConfig: nameConfig, onAdLoaded: onAdLoaded, onAdFailedToLoad: onAdFailedToLoad)
    }

    /// Show inter đã preload (có check interval).
    public func showInterAdPreload(
        idAds: String,
        config: Bool,
        isInterAll: Bool,
        name: String,
        isShowLoading: Bool = true,
        callbacks: AdCallbacks = AdCallbacks(),
        onNext: (() -> Void)? = nil
    ) {
        let (resolved, next) = callbacks.withNext(onNext)
        guard AdHelper.canShowNextInter(isInterAll: isInterAll) else {
            AdsLog.d("Inter Ad Preload: not canShowNextInter")
            next()
            return
        }
        InterAdManager.shared.showInterAdPreload(idAds: idAds, config: config, name: name, isShowLoading: isShowLoading, callbacks: resolved, onNext: next)
    }

    /// Có ads preload -> show, chưa có -> Loading + đợi ads về (có check interval).
    public func loadAndShowInterAdPreload(
        idAds: String,
        config: Bool,
        isInterAll: Bool,
        name: String,
        callbacks: AdCallbacks = AdCallbacks(),
        onNext: (() -> Void)? = nil
    ) {
        let (resolved, next) = callbacks.withNext(onNext)
        guard AdHelper.canShowNextInter(isInterAll: isInterAll) else {
            next()
            return
        }
        InterAdManager.shared.loadAndShowInterAdPreload(idAds: idAds, config: config, name: name, callbacks: resolved, onNext: next)
    }

    // MARK: - App open

    public func loadAndShowAppOpenAds(idAds: String, config: Bool, name: String, callbacks: AdCallbacks = AdCallbacks()) {
        let resolved = callbacks.withNext().callbacks
        AppOpenAdManager.shared.loadAndShowAppOpenAds(idAds: idAds, config: config, name: name, callbacks: resolved)
    }

    // MARK: - Reward

    public func loadAndShowRewardAds(idAds: String, config: Bool, name: String, callbacks: AdCallbacks = AdCallbacks()) {
        let resolved = callbacks.withNext().callbacks
        RewardAdManager.shared.loadAndShowRewardAds(idAds: idAds, config: config, name: name, callbacks: resolved)
    }

    public func loadRewardAdConsecutive(idAds: String, config: Bool) {
        RewardAdManager.shared.loadRewardAdConsecutive(idAds: idAds, config: config)
    }

    public func showRewardConsecutive(idAds: String, config: Bool, count: Int, name: String, onFailed: (() -> Void)? = nil, onCompleted: @escaping () -> Void) {
        RewardAdManager.shared.showRewardConsecutive(idAds: idAds, config: config, count: count, name: name, onFailed: onFailed, onCompleted: onCompleted)
    }

    public func loadRewardAdPreload(idAds: String, config: Bool, onAdLoaded: (() -> Void)? = nil, onAdFailedToLoad: ((String) -> Void)? = nil) {
        RewardAdManager.shared.loadRewardAdPreload(idAds: idAds, config: config, onAdLoaded: onAdLoaded, onAdFailedToLoad: onAdFailedToLoad)
    }

    public func showRewardAdPreload(
        idAds: String,
        config: Bool,
        name: String,
        isShowLoading: Bool = true,
        callbacks: AdCallbacks = AdCallbacks(),
        onNext: (() -> Void)? = nil
    ) {
        let (resolved, next) = callbacks.withNext(onNext)
        RewardAdManager.shared.showRewardAdPreload(idAds: idAds, config: config, name: name, isShowLoading: isShowLoading, callbacks: resolved, onNext: next)
    }

    public func loadAndShowRewardAdPreload(
        idAds: String,
        config: Bool,
        name: String,
        callbacks: AdCallbacks = AdCallbacks(),
        onNext: (() -> Void)? = nil
    ) {
        let (resolved, next) = callbacks.withNext(onNext)
        RewardAdManager.shared.loadAndShowRewardAdPreload(idAds: idAds, config: config, name: name, callbacks: resolved, onNext: next)
    }
}
