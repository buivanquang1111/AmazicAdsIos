import FirebaseAnalytics
import FirebaseCore
import FirebaseRemoteConfig
import Foundation

/// Port `event_log.dart` + `remote_config.dart` bên Flutter, viết theo tài liệu Firebase iOS:
/// - Thêm Firebase: https://firebase.google.com/docs/ios/setup
/// - Analytics: https://firebase.google.com/docs/analytics/get-started?platform=ios
/// - Remote Config: https://firebase.google.com/docs/remote-config/get-started?platform=ios
///
/// `Admob.shared.configure()` tự gọi `FirebaseUtil.shared.setUp()`:
/// - App có `GoogleService-Info.plist` -> bật Firebase, event + remote config đi qua Firebase.
/// - Không có file -> bỏ qua, thư viện dùng giá trị mặc định của `RemoteConfigKey` (không crash).
public final class FirebaseUtil: AdsEventLogger, AdsRemoteConfigProvider {
    public static let shared = FirebaseUtil()
    private init() {}

    public private(set) var isInitialized = false

    /// Giống Flutter: fetchTimeout 30s, minimumFetchInterval 15s.
    /// Lưu ý: Firebase giới hạn số lần fetch, bản phát hành nên để >= 1h nếu không cần cập nhật nhanh.
    public var fetchTimeout: TimeInterval = 30
    public var minimumFetchInterval: TimeInterval = 15

    private var remoteConfig: RemoteConfig?

    /// Khởi tạo Firebase (nếu app chưa tự gọi `FirebaseApp.configure()`) và gắn vào thư viện.
    public func setUp() {
        guard !isInitialized else { return }

        if FirebaseApp.app() == nil {
            // FirebaseApp.configure() sẽ crash nếu thiếu file -> kiểm tra trước.
            guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
                AdsLog.d("Firebase: không có GoogleService-Info.plist -> bỏ qua, dùng remote config mặc định")
                return
            }
            FirebaseApp.configure()
        }

        let config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.fetchTimeout = fetchTimeout
        settings.minimumFetchInterval = minimumFetchInterval
        config.configSettings = settings
        remoteConfig = config
        isInitialized = true

        // Tự gắn nếu app chưa gắn provider khác.
        if Admob.shared.eventLogger == nil { Admob.shared.eventLogger = self }
        if Admob.shared.remoteConfigProvider == nil { Admob.shared.remoteConfigProvider = self }

        AdsLog.d("Firebase: setUp OK - project = \(FirebaseApp.app()?.options.projectID ?? "")")
    }

    // MARK: - AdsEventLogger (Analytics)

    public func logEvent(_ name: String, parameters: [String: Any]?) {
        let params = parameters.map(Self.sanitize)
        Analytics.logEvent(name, parameters: params)
        AdsLog.d("[event] \(name) \(params ?? [:])")
    }

    /// Firebase chỉ nhận value là String / NSNumber; tên param tối đa 40 ký tự, value String tối đa 100 ký tự.
    private static func sanitize(_ parameters: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in parameters {
            let safeKey = String(key.prefix(40))
            switch value {
            case let number as NSNumber: result[safeKey] = number
            case let string as String: result[safeKey] = String(string.prefix(100))
            default: result[safeKey] = String(String(describing: value).prefix(100))
            }
        }
        return result
    }

    // MARK: - AdsRemoteConfigProvider

    public func setDefaults(_ defaults: [String: NSObject]) {
        remoteConfig?.setDefaults(defaults)
    }

    public func fetch(completion: @escaping () -> Void) {
        guard let remoteConfig else {
            completion()
            return
        }
        remoteConfig.fetchAndActivate { status, error in
            if let error {
                AdsLog.d("Firebase RemoteConfig: fetch lỗi - \(error.localizedDescription)")
            } else {
                let keys = remoteConfig.allKeys(from: .remote)
                AdsLog.d("Firebase RemoteConfig: fetch xong - status = \(status.rawValue) - \(keys.count) key từ server")
                for key in keys {
                    AdsLog.d("  \(key) = \(remoteConfig.configValue(forKey: key).stringValue)")
                }
            }
            completion()
        }
    }

    /// Chỉ trả giá trị khi có trên server, còn lại nil -> thư viện dùng default của `RemoteConfigKey`.
    private func remoteValue(_ key: String) -> RemoteConfigValue? {
        guard let value = remoteConfig?.configValue(forKey: key), value.source == .remote else { return nil }
        return value
    }

    public func bool(_ key: String) -> Bool? {
        remoteValue(key)?.boolValue
    }

    public func string(_ key: String) -> String? {
        remoteValue(key)?.stringValue
    }

    public func number(_ key: String) -> NSNumber? {
        remoteValue(key)?.numberValue
    }
}
