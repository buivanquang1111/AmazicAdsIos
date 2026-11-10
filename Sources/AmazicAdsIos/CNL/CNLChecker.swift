import Foundation
import SQLite3

/// Check "công nghệ lõi" (CNL) — port `startingCheckCNL` bản Android.
///
/// Android đọc SharedPreferences "admob" (`inspector_info`, `app_settings_json`).
/// iOS không có các key đó; Google Mobile Ads iOS lưu trạng thái trong SQLite
/// `Library/Application Support/GoogleMobileAds/storage`, bảng `storage(name, value)`:
/// - `test_mode_enabled`: "1" = máy đang ở chế độ ads test (tương đương `isTestMode`)
/// - `admob_application_id`: app id (tương đương `app_id` trong `app_settings_json`)
///
/// LƯU Ý: đây là dữ liệu nội bộ, Google không công bố -> có thể đổi theo version SDK.
/// Đọc lỗi / không có DB thì coi như user bình thường, không bao giờ crash.
public final class CNLChecker {
    public static let shared = CNLChecker()
    private init() {}

    /// Kết quả lần check gần nhất (tương đương `TechManager.detectedTech`).
    public private(set) var isDetectedTech = false

    /// Gọi mỗi lần check xong với kết quả detect (true = máy test / CNL).
    public var onDetectedTech: ((Bool) -> Void)?

    private let lastValueKey = "cnl_track_last_test_mode"

    /// Check CNL + log event `inspector_info` (chỉ log khi giá trị thay đổi so với lần trước).
    /// Thư viện tự gọi lúc `initSplash`; có thể gọi tay thêm nếu cần.
    public func startingCheckCNL() {
        // reset
        setDetected(false)

        let storage = Self.readAdMobStorage(keys: ["test_mode_enabled", "admob_application_id", "common_settings"])
        let testMode = storage["test_mode_enabled"]            // nil = không có DB / key
        let appId = storage["admob_application_id"] ?? Self.appIdFromCommonSettings(storage["common_settings"]) ?? ""
        let isTestMode = testMode == "1"

        AdsLog.d("check_CNL: test_mode_enabled = \(testMode ?? "null"), appId = \(appId)")

        // So với lần trước, chỉ log khi giá trị thay đổi
        let currentValue = testMode ?? "__NULL__"
        let defaults = UserDefaults.standard
        let lastValue = defaults.string(forKey: lastValueKey) ?? "__NOT_SET__"
        guard currentValue != lastValue else {
            AdsLog.d("check_CNL: test_mode_enabled không đổi, bỏ qua log event")
            if isTestMode { setDetected(true) }
            return
        }
        defaults.set(currentValue, forKey: lastValueKey)

        // state: "null" (không có dữ liệu) / "false" / "true" — giống kiểu giá trị isTestMode bên Android
        let state: String
        switch testMode {
        case nil: state = "null"
        case "1": state = "true"
        default: state = "false"
        }

        EventLog.logEvent("inspector_info", parameters: [
            "state": state,
            "app_id": appId
        ])
        AdsLog.d("check_CNL: log inspector_info state = \(state), appId = \(appId)")

        if isTestMode { setDetected(true) }
    }

    private func setDetected(_ value: Bool) {
        isDetectedTech = value
        onMain { [weak self] in self?.onDetectedTech?(value) }
    }

    // MARK: - Đọc SQLite của SDK (chỉ đọc)

    static func readAdMobStorage(keys: [String]) -> [String: String] {
        guard let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else { return [:] }
        let path = lib.appendingPathComponent("Application Support/GoogleMobileAds/storage").path
        guard FileManager.default.fileExists(atPath: path) else { return [:] }

        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return [:]
        }
        defer { sqlite3_close(db) }

        let placeholders = keys.map { _ in "?" }.joined(separator: ",")
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT name, value FROM storage WHERE name IN (\(placeholders))", -1, &stmt, nil) == SQLITE_OK else {
            return [:]
        }
        defer { sqlite3_finalize(stmt) }

        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, key) in keys.enumerated() {
            sqlite3_bind_text(stmt, Int32(index + 1), key, -1, transient)
        }

        var result: [String: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let nameC = sqlite3_column_text(stmt, 0) else { continue }
            let value = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? ""
            result[String(cString: nameC)] = value
        }
        return result
    }

    private static func appIdFromCommonSettings(_ json: String?) -> String? {
        guard let data = json?.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object["app_id"] as? String
    }
}
