import AmazicAdsIos
import Foundation

/// Toàn bộ id ads dùng test id của Google (iOS).
/// Sample không có server id ads -> `linkServer` rỗng, thư viện dùng luôn `jsonIdAdsDefault`.
enum SampleAdsConfig {
    // Tên vị trí ads (giống bên Flutter / server)
    static let openSplash = "open_splash"
    static let interSplash = "inter_splash"
    static let openResume = "open_resume"
    static let interAll = "inter_all"
    static let rewardAll = "reward_all"
    static let bannerAll = "banner_all"
    static let collapseBanner = "collapse_banner"
    static let nativeAll = "native_all"
    static let nativeCollapse = "native_collapse"
    static let nativeLanguage = "native_language"
    static let nativeAfterInter = "native_after_inter"

    private static let testAppOpen = "ca-app-pub-3940256099942544/5575463023"
    private static let testInter = "ca-app-pub-3940256099942544/4411468910"
    private static let testReward = "ca-app-pub-3940256099942544/1712485313"
    private static let testBanner = "ca-app-pub-3940256099942544/2435281174"
    private static let testNative = "ca-app-pub-3940256099942544/3986624511"

    /// Cùng format json server trả về: [{ id, app_id, name, ads_id }]
    static var jsonIdAdsDefault: String {
        let items: [(String, String)] = [
            (openSplash, testAppOpen),
            (interSplash, testInter),
            (openResume, testAppOpen),
            (interAll, testInter),
            (rewardAll, testReward),
            (bannerAll, testBanner),
            (collapseBanner, testBanner),
            (nativeAll, testNative),
            (nativeCollapse, testNative),
            (nativeLanguage, testNative),
            (nativeAfterInter, testNative)
        ]
        let list = items.enumerated().map { index, item in
            ["id": index + 1, "app_id": "sample", "name": item.0, "ads_id": item.1] as [String: Any]
        }
        let data = (try? JSONSerialization.data(withJSONObject: list)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    /// Giá trị mặc định remote config (chưa cắm Firebase thì dùng luôn các giá trị này).
    static let remoteConfigKeys: [RemoteConfigKey] = [
        RemoteConfigKey(name: "show_ads", defaultValue: true),
        RemoteConfigKey(name: openSplash, defaultValue: true),
        RemoteConfigKey(name: interSplash, defaultValue: true),
        RemoteConfigKey(name: openResume, defaultValue: true),
        RemoteConfigKey(name: interAll, defaultValue: true),
        RemoteConfigKey(name: rewardAll, defaultValue: true),
        RemoteConfigKey(name: bannerAll, defaultValue: true),
        RemoteConfigKey(name: collapseBanner, defaultValue: true),
        RemoteConfigKey(name: nativeAll, defaultValue: true),
        RemoteConfigKey(name: nativeCollapse, defaultValue: true),
        RemoteConfigKey(name: nativeLanguage, defaultValue: true),
        RemoteConfigKey(name: nativeAfterInter, defaultValue: true),
        // 50% app open / 50% inter ở splash
        RemoteConfigKey(name: "rate_aoa_inter_splash", defaultValue: "50_50"),
        // Interval (giây)
        RemoteConfigKey(name: "interval_between_interstitial", defaultValue: 15),
        RemoteConfigKey(name: "interval_interstitial_from_start", defaultValue: 0),
        RemoteConfigKey(name: "interval_inter_all", defaultValue: 0)
    ]

    static var splashConfig: SplashConfig {
        SplashConfig(
            linkServer: "",
            appId: "",
            packageName: Bundle.main.bundleIdentifier ?? "",
            jsonIdAdsDefault: jsonIdAdsDefault,
            nameIdAdsResume: openResume,
            nameResumeConfig: openResume,
            nameIdAdsAppOpenSplash: openSplash,
            nameIdAdsInterSplash: interSplash,
            nameIdAdsNativeAfterInter: nativeAfterInter,
            nameConfigAppOpenSplash: openSplash,
            nameConfigInterSplash: interSplash,
            nameConfigNativeAfterInter: nativeAfterInter,
            nameRateAoa: "rate_aoa_inter_splash",
            nameIntervalBetweenInter: "interval_between_interstitial",
            nameIntervalFromStart: "interval_interstitial_from_start",
            nameIntervalInterAll: "interval_inter_all",
            isShowWelcomeScreenAfterAppOpenAds: true,
            remoteConfigKeys: remoteConfigKeys
        )
    }

    static func id(_ name: String) -> String {
        AdsApi.shared.getFirstIDByName(name)
    }

    static func config(_ name: String) -> Bool {
        AdsRemoteConfig.getBool(name)
    }
}
