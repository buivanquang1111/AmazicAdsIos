import Foundation
import GoogleMobileAds

// MARK: - Protocol cắm từ ngoài vào (Firebase / Adjust...)

/// Ghi event (vd: Firebase Analytics). Không gán -> chỉ in log console.
public protocol AdsEventLogger: AnyObject {
    func logEvent(_ name: String, parameters: [String: Any]?)
}

/// Nguồn remote config (vd: Firebase Remote Config).
/// Trả `nil` khi không có giá trị trên server -> thư viện dùng giá trị mặc định của `RemoteConfigKey`.
public protocol AdsRemoteConfigProvider: AnyObject {
    func setDefaults(_ defaults: [String: NSObject])
    /// Fetch + activate, xong gọi completion (kể cả lỗi).
    func fetch(completion: @escaping () -> Void)
    func bool(_ key: String) -> Bool?
    func string(_ key: String) -> String?
    func number(_ key: String) -> NSNumber?
}

/// Thông tin doanh thu 1 lần hiển thị ads (từ paidEventHandler).
public struct AdRevenueInfo {
    /// Tên network thắng (adSourceName).
    public let network: String?
    /// Giá trị micros (giống `valueMicros` bên Flutter).
    public let valueMicros: Double
    /// Giá trị thật = valueMicros / 1_000_000.
    public var revenue: Double { valueMicros / 1_000_000 }
    public let currency: String
    public let adUnitId: String
    /// Tên vị trí / format (vd: inter_home, banner_all).
    public let adFormat: String
}

/// Track doanh thu ads (vd: Adjust). Không gán -> chỉ in log console.
public protocol AdsRevenueTracker: AnyObject {
    func trackAdRevenue(_ info: AdRevenueInfo)
}

// MARK: - Event

public enum EventLog {
    /// Giống bản Flutter: tên tối đa 40 ký tự. Thêm: thay ký tự không hợp lệ bằng "_"
    /// (Firebase chỉ nhận chữ, số, "_" và phải bắt đầu bằng chữ).
    public static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        var safe = String(name.map { ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "_" ? $0 : "_" })
        if let first = safe.first, !(first.isASCII && first.isLetter) { safe = "e_" + safe }
        safe = String(safe.prefix(40))

        if let logger = Admob.shared.eventLogger {
            logger.logEvent(safe, parameters: parameters)
        } else {
            AdsLog.d("[event] \(safe) \(parameters ?? [:])")
        }
    }
}

// MARK: - Revenue

enum Revenue {
    static func track(_ adValue: AdValue, responseInfo: ResponseInfo?, adUnitId: String, format: String) {
        let info = AdRevenueInfo(
            network: responseInfo?.loadedAdNetworkResponseInfo?.adSourceName,
            valueMicros: adValue.value.doubleValue * 1_000_000,
            currency: adValue.currencyCode,
            adUnitId: adUnitId.isEmpty ? "TEST_UNIT_ID" : adUnitId,
            adFormat: format.isEmpty ? "TEST_FORMAT" : format
        )
        AdsLog.d("revenue: network = \(info.network ?? "") - revenue = \(info.revenue) \(info.currency) - unit = \(info.adUnitId) - format = \(info.adFormat)")
        Admob.shared.revenueTracker?.trackAdRevenue(info)
    }
}

// MARK: - Remote config

/// Khai báo key remote config + giá trị mặc định (giống `RemoteConfigKey` bên Flutter).
public struct RemoteConfigKey {
    public let name: String
    public let defaultValue: NSObject

    public init(name: String, defaultValue: Bool) {
        self.name = name
        self.defaultValue = NSNumber(value: defaultValue)
    }

    public init(name: String, defaultValue: Int) {
        self.name = name
        self.defaultValue = NSNumber(value: defaultValue)
    }

    public init(name: String, defaultValue: Double) {
        self.name = name
        self.defaultValue = NSNumber(value: defaultValue)
    }

    public init(name: String, defaultValue: String) {
        self.name = name
        self.defaultValue = defaultValue as NSString
    }
}

/// Port `remote_config.dart`. Có provider -> lấy giá trị server, không có -> giá trị mặc định.
public enum AdsRemoteConfig {
    private static var keyMap: [String: RemoteConfigKey] = [:]
    private static var provider: AdsRemoteConfigProvider? { Admob.shared.remoteConfigProvider }

    /// Đăng ký giá trị mặc định (tự gọi khi init splash, có thể gọi sớm hơn).
    public static func setDefaults(_ keys: [RemoteConfigKey]) {
        for key in keys { keyMap[key.name] = key }
        var defaults: [String: NSObject] = [:]
        for key in keyMap.values { defaults[key.name] = key.defaultValue }
        provider?.setDefaults(defaults)
    }

    /// Set default + fetch từ provider (không có provider thì xong ngay).
    public static func initialize(keys: [RemoteConfigKey], completion: @escaping () -> Void) {
        setDefaults(keys)
        guard let provider else {
            AdsLog.d("RemoteConfig: không có provider -> dùng giá trị mặc định")
            onMain { completion() }
            return
        }
        provider.fetch {
            onMain { completion() }
        }
    }

    // MARK: Giá trị mặc định

    private static func localBool(_ key: String) -> Bool {
        switch keyMap[key]?.defaultValue {
        case let number as NSNumber: return number.boolValue
        case let string as NSString: return ["true", "1", "yes"].contains((string as String).lowercased())
        default: return false
        }
    }

    private static func localString(_ key: String) -> String {
        switch keyMap[key]?.defaultValue {
        case let string as NSString: return string as String
        case let number as NSNumber: return number.stringValue
        default: return ""
        }
    }

    private static func localNumber(_ key: String) -> NSNumber {
        switch keyMap[key]?.defaultValue {
        case let number as NSNumber: return number
        case let string as NSString: return NSNumber(value: string.doubleValue)
        default: return 0
        }
    }

    // MARK: Getter

    /// Bool của vị trí ads, AND với key `show_ads`
    /// (không khai báo `show_ads` ở đâu cả thì coi như true).
    public static func getBool(_ key: String) -> Bool {
        let showAds: Bool
        if let remote = provider?.bool("show_ads") {
            showAds = remote
        } else if keyMap["show_ads"] != nil {
            showAds = localBool("show_ads")
        } else {
            showAds = true
        }
        return getBoolDefault(key) && showAds
    }

    public static func getBoolDefault(_ key: String) -> Bool {
        provider?.bool(key) ?? localBool(key)
    }

    public static func getString(_ key: String) -> String {
        provider?.string(key) ?? localString(key)
    }

    public static func getInt(_ key: String) -> Int {
        (provider?.number(key) ?? localNumber(key)).intValue
    }

    public static func getDouble(_ key: String) -> Double {
        (provider?.number(key) ?? localNumber(key)).doubleValue
    }

    public static func containsKey(_ key: String) -> Bool {
        keyMap[key] != nil
    }
}
