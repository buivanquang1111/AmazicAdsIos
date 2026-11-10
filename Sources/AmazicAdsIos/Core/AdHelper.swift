import Foundation

public enum AdsSplashType {
    case inter
    case open
    case none
}

/// Port từ `ad_helper.dart`: interval inter + chọn loại ads splash theo rate_aoa.
public enum AdHelper {
    /// ms
    private static var intervalBetweenInter: Int64 = 0
    private static var lastTimeDismissInter: Int64 = -1
    private static var intervalInterFromStart: Int64 = 0
    private static var intervalInterAll: Int64 = 0
    private static var timeStartApp: Int64 = -1

    private static var configAppOpen = true
    private static var configInter = true
    private static var rateAoa = "0_100"

    /// Sau lần show đầu tiên của inter_all mới bắt đầu tính interval_inter_all.
    public static var isFirstShowInterAll = false

    static func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// Các interval truyền vào đơn vị **mili giây**.
    public static func initialize(
        intervalBetweenInter: Int64,
        intervalFromStart: Int64,
        intervalInterAll: Int64,
        configAppOpen: Bool,
        configInter: Bool,
        rateAoa: String
    ) {
        lastTimeDismissInter = -1
        timeStartApp = nowMs()
        self.intervalBetweenInter = intervalBetweenInter
        self.intervalInterFromStart = intervalFromStart
        self.intervalInterAll = intervalInterAll
        self.configAppOpen = configAppOpen
        self.configInter = configInter
        self.rateAoa = rateAoa
        isFirstShowInterAll = false
    }

    public static func setConfigAppOpen(_ value: Bool) { configAppOpen = value }
    public static func setConfigInter(_ value: Bool) { configInter = value }
    public static func setRateAoa(_ value: String) { rateAoa = value }
    public static func setIntervalBetweenInter(ms: Int64) { intervalBetweenInter = ms }
    public static func setIntervalFromStart(ms: Int64) { intervalInterFromStart = ms }
    public static func setIntervalInterAll(ms: Int64) { intervalInterAll = ms }

    public static func setLastTimeDismissInter() {
        lastTimeDismissInter = nowMs()
    }

    public static func canShowNextInter(isInterAll: Bool) -> Bool {
        if timeStartApp == -1 { return false }
        let now = nowMs()

        if now - timeStartApp < intervalInterFromStart { return false }
        if lastTimeDismissInter == -1 { return true }

        let elapsed = now - lastTimeDismissInter
        AdsLog.d("inter_ads: check - isFirstShowInterAll = \(isFirstShowInterAll), isInterAll = \(isInterAll), elapsed = \(elapsed)")

        if isInterAll && intervalInterAll > 0 && isFirstShowInterAll {
            return elapsed >= intervalInterAll
        }
        return elapsed >= intervalBetweenInter
    }

    public static var splashType: AdsSplashType {
        if configInter && configAppOpen {
            guard isValidFormat(rateAoa) else { return .none }
            return getRandomOpenAd(rateAoa) ? .open : .inter
        }
        if configAppOpen { return .open }
        if configInter { return .inter }
        return .none
    }

    static func isValidFormat(_ rateAoa: String) -> Bool {
        let split = rateAoa.split(separator: "_")
        var openRate = 0
        var interRate = 100
        if split.count == 2 {
            openRate = Int(split[0]) ?? 0
            interRate = Int(split[1]) ?? 100
        }
        return openRate + interRate == 100 && openRate >= 0 && interRate >= 0
    }

    static func getRandomOpenAd(_ rateAoa: String) -> Bool {
        let split = rateAoa.split(separator: "_")
        let openRate = split.count == 2 ? (Int(split[0]) ?? 0) : 0
        return Int.random(in: 1...100) <= openRate
    }
}
