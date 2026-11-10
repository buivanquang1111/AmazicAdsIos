import AmazicAdsIos
import SwiftUI
import GoogleMobileAds
import SQLite3
import FLEX

struct HomeView: View {
    @State private var logs: [String] = []
    @State private var preloadMode = Admob.shared.isUseAdPreloading

    private var interId: String { SampleAdsConfig.id(SampleAdsConfig.interAll) }
    private var rewardId: String { SampleAdsConfig.id(SampleAdsConfig.rewardAll) }
    private var openId: String { SampleAdsConfig.id(SampleAdsConfig.openResume) }

    var body: some View {
        List {
            Section("Inter — load thường") {
                Button("Load & show Inter") {
                    Admob.shared.loadAndShowInterAds(
                        idAds: interId,
                        config: SampleAdsConfig.config(SampleAdsConfig.interAll),
                        name: SampleAdsConfig.interAll,
                        callbacks: callbacks("inter")
                    )
                }
                Button("Inter chỉ dùng onNext (cách viết gọn)") {
                    Admob.shared.loadAndShowInterAds(
                        idAds: interId,
                        config: SampleAdsConfig.config(SampleAdsConfig.interAll),
                        name: SampleAdsConfig.interAll,
                        callbacks: AdCallbacks(onNext: { log("inter gọn: onNext ➡️ chuyển màn") })
                    )
                }
                Button("Load & show Inter (interval 15s)") {
                    Admob.shared.loadAndShowInterInterval(
                        idAds: interId,
                        config: SampleAdsConfig.config(SampleAdsConfig.interAll),
                        isInterAll: false,
                        name: SampleAdsConfig.interAll,
                        callbacks: callbacks("inter interval")
                    )
                }
            }

            Section("Inter — Ad Preloading (SDK)") {
                Button("1. Bắt đầu preload Inter") {
                    Admob.shared.loadInterAdPreload(
                        idAds: interId,
                        nameConfig: SampleAdsConfig.interAll,
                        onAdLoaded: { log("inter preload: available") },
                        onAdFailedToLoad: { log("inter preload: fail \($0)") }
                    )
                }
                Button("2. Show Inter preload") {
                    Admob.shared.showInterAdPreload(
                        idAds: interId,
                        config: SampleAdsConfig.config(SampleAdsConfig.interAll),
                        isInterAll: false,
                        name: "inter_preload",
                        callbacks: callbacks("inter preload")
                    ) { log("inter preload: onNext") }
                }
                Button("Load & show Inter preload") {
                    Admob.shared.loadAndShowInterAdPreload(
                        idAds: interId,
                        config: SampleAdsConfig.config(SampleAdsConfig.interAll),
                        isInterAll: false,
                        name: "inter_preload",
                        callbacks: callbacks("inter preload")
                    ) { log("inter preload: onNext") }
                }
                Text("Có sẵn: \(InterAdManager.shared.isAdAvailable(idAds: interId) ? "có" : "chưa") (bấm nút khác để cập nhật)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Reward") {
                Button("Load & show Reward") {
                    Admob.shared.loadAndShowRewardAds(
                        idAds: rewardId,
                        config: SampleAdsConfig.config(SampleAdsConfig.rewardAll),
                        name: SampleAdsConfig.rewardAll,
                        callbacks: callbacks("reward")
                    )
                }
                Button("Xem liên tiếp 2 Reward") {
                    Admob.shared.loadRewardAdConsecutive(idAds: rewardId, config: true)
                    Admob.shared.showRewardConsecutive(
                        idAds: rewardId,
                        config: SampleAdsConfig.config(SampleAdsConfig.rewardAll),
                        count: 2,
                        name: "reward_x2",
                        onFailed: { log("reward x2: failed") }
                    ) { log("reward x2: completed ✅") }
                }
                Button("Load & show Reward preload") {
                    Admob.shared.loadAndShowRewardAdPreload(
                        idAds: rewardId,
                        config: SampleAdsConfig.config(SampleAdsConfig.rewardAll),
                        name: "reward_preload",
                        callbacks: callbacks("reward preload")
                    ) { log("reward preload: onNext") }
                }
            }

            Section("App Open") {
                Button("Load & show App Open") {
                    Admob.shared.loadAndShowAppOpenAds(
                        idAds: openId,
                        config: SampleAdsConfig.config(SampleAdsConfig.openResume),
                        name: "open_manual",
                        callbacks: callbacks("app open")
                    )
                }
                Button("Load & show App Open preload") {
                    AppOpenAdManager.shared.loadAndShowAppOpenAdPreload(
                        idAds: openId,
                        config: SampleAdsConfig.config(SampleAdsConfig.openResume),
                        name: "open_preload",
                        callbacks: callbacks("app open preload")
                    ) { log("app open preload: onNext") }
                }
                Button("Show ads splash còn giữ (sau timeout)") {
                    Admob.shared.showAdsSplash { log("showAdsSplash: onNext") }
                }
                Toggle("Resume dùng preload", isOn: $preloadMode)
                    .onChange(of: preloadMode) { Admob.shared.isUseAdPreloading = $0 }
                Text("Resume: đưa app ra background rồi mở lại → App Open → Welcome Back.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Banner / Native") {
                NavigationLink("Native ads (medium, small, preload, collapsible)", destination: NativeDemoView())
                NavigationLink("Collapsible banner", destination: CollapseBannerDemoView())
                Button("Native after inter (full màn, dùng native preload)") {
                    Admob.shared.startShowNativeAfterInter(
                        adsKey: SampleAdsConfig.nativeLanguage,
                        remoteKey: SampleAdsConfig.nativeLanguage
                    ) { log("native after inter: close") }
                }
                Text("Banner adaptive ở dưới đáy màn này (refresh 30s).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Debug AdMob storage") {
                Button("Dump AdMob storage") {
                    dumpAdMobStorage()
                    log("đã dump, xem console Xcode")
                }
                Button("Mở Ad Inspector") {
                    guard let vc = UIApplication.shared.connectedScenes
                        .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else { return }
                    MobileAds.shared.presentAdInspector(from: vc) { error in
                        log("Ad Inspector đóng: \(error?.localizedDescription ?? "ok")")
                    }
                }
                Button("Mở FLEX xem DB AdMob") {
                    copyAdMobDBsForFLEX()
                    FLEXManager.shared.showExplorer()
                }
                Button("Diff storage") { diffAdMobStorage() }
            }
            
            Section("Privacy") {
                Button("Mở form quyền riêng tư (UMP)") {
                    ConsentManager.shared.presentPrivacyOptionsForm { error in
                        log("privacy form: \(error?.localizedDescription ?? "đóng")")
                    }
                }
            }

            Section("Trạng thái") {
                Text("Consent canRequestAds: \(ConsentManager.shared.canRequestAds ? "true" : "false")")
                Text("Timeout splash: \(Admob.shared.isNextTimeout ? "có" : "không")")
                Text("Ads full screen đang hiện: \(Admob.shared.isFullScreenAdShowing ? "có" : "không")")
            }

            Section("Log") {
                if logs.isEmpty {
                    Text("Chưa có log").foregroundColor(.secondary)
                }
                ForEach(Array(logs.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.system(size: 12, design: .monospaced))
                }
            }
        }
        .navigationTitle("AmazicAdsIos")
        .safeAreaInset(edge: .bottom) {
            BannerAds(
                idAds: SampleAdsConfig.id(SampleAdsConfig.bannerAll),
                config: SampleAdsConfig.config(SampleAdsConfig.bannerAll),
                name: SampleAdsConfig.bannerAll,
                refreshSec: 30
            )
        }
    }

    private func log(_ text: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logs.insert("[\(time)] \(text)", at: 0)
        if logs.count > 50 { logs.removeLast() }
    }

    private func callbacks(_ tag: String) -> AdCallbacks {
        AdCallbacks(
            onAdDisable: { log("\(tag): disable") },
            onAdLoaded: { log("\(tag): loaded") },
            onAdImpression: { log("\(tag): impression") },
            onAdClicked: { log("\(tag): clicked") },
            onAdFailedToLoad: { log("\(tag): fail load \($0)") },
            onAdFailedToShow: { log("\(tag): fail show \($0)") },
            onAdDismiss: { log("\(tag): dismiss") },
            onUserEarnedReward: { log("\(tag): earned reward 🎁") },
            // Luôn chạy đúng 1 lần khi ads kết thúc (disable / lỗi / đóng) -> đặt chuyển màn ở đây.
            onNext: { log("\(tag): onNext ➡️ chuyển màn") }
        )
    }
    func dumpAdMobStorage() {
        print("===== DUMP ADMOB STORAGE =====")
        let fm = FileManager.default
        let lib = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]

        // 1. UserDefaults riêng của AdMob (giống SharedPreferences "admob" Android)
        let gadsURL = lib.appendingPathComponent("Preferences/__gads__.plist")
        if let dict = NSDictionary(contentsOf: gadsURL) as? [String: Any] {
            for (k, v) in dict.sorted(by: { $0.key < $1.key }) { print("GADS [\(k)] = \(v)") }
        } else {
            print("GADS: chưa đọc được __gads__.plist")
        }

        // 2. File trong thư mục của SDK
        for folder in ["Application Support/GoogleMobileAds", "Application Support/gad"] {
            let dir = lib.appendingPathComponent(folder)
            let urls = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey])?
                .compactMap { $0 as? URL } ?? []
            for url in urls where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
                let data = (try? Data(contentsOf: url)) ?? Data()
                print("FILE \(folder)/\(url.lastPathComponent) (\(data.count) bytes)")
                if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) {
                    print(plist)
                } else if let text = String(data: data.prefix(3000), encoding: .utf8) {
                    print(text)
                } else {
                    dumpSQLite(url)
                }
            }
        }
        print("===== END =====")
    }
    func dumpSQLite(_ url: URL) {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            print("  không mở được (không phải SQLite?)"); return
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        var tables: [String] = []
        if sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table'", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW { tables.append(String(cString: sqlite3_column_text(stmt, 0))) }
        }
        sqlite3_finalize(stmt)
        for t in tables {
            print("  TABLE \(t)")
            guard sqlite3_prepare_v2(db, "SELECT * FROM \"\(t)\" LIMIT 30", -1, &stmt, nil) == SQLITE_OK else { continue }
            let n = sqlite3_column_count(stmt)
            print("    cols: \((0..<n).map { String(cString: sqlite3_column_name(stmt, $0)) })")
            while sqlite3_step(stmt) == SQLITE_ROW {
                let row: [String] = (0..<n).map { i in
                    switch sqlite3_column_type(stmt, i) {
                    case SQLITE_NULL: return "null"
                    case SQLITE_BLOB:
                        let len = Int(sqlite3_column_bytes(stmt, i))
                        guard let p = sqlite3_column_blob(stmt, i) else { return "blob(0)" }
                        let data = Data(bytes: p, count: len)
                        if let s = String(data: data.prefix(400), encoding: .utf8) { return "blob:\(s)" }
                        return "blob(\(len)B)"
                    default:
                        return String(String(cString: sqlite3_column_text(stmt, i)).prefix(400))
                    }
                }
                print("    \(row)")
            }
            sqlite3_finalize(stmt)
        }
    }
    /// Copy DB của AdMob sang Documents với đuôi .sqlite để FLEX mở được (không đụng file gốc).
    func copyAdMobDBsForFLEX() {
        let fm = FileManager.default
        let lib = fm.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let files = [
            "Application Support/GoogleMobileAds/storage": "admob_storage.sqlite",
            "Application Support/GoogleMobileAds/Settings": "admob_settings.sqlite",
            "Application Support/GoogleMobileAds/AdapterSettings": "admob_adapter_settings.sqlite",
            "Application Support/gad/gad_db": "gad_db.sqlite"
        ]
        for (src, dst) in files {
            // Copy cả file -wal / -shm (SQLite có thể còn dữ liệu chưa ghi vào file chính).
            for suffix in ["", "-wal", "-shm"] {
                let from = lib.appendingPathComponent(src + suffix)
                let to = docs.appendingPathComponent(dst + suffix)
                try? fm.removeItem(at: to)
                if fm.fileExists(atPath: from.path) {
                    do { try fm.copyItem(at: from, to: to) }
                    catch { print("copy lỗi \(src + suffix): \(error)") }
                }
            }
        }
        print("Đã copy DB sang Documents: \(docs.path)")
    }
    private static var lastStorage: [String: String] = [:]

    func diffAdMobStorage() {
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let path = lib.appendingPathComponent("Application Support/GoogleMobileAds/storage").path
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { print("DIFF: không mở được DB"); return }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        var now: [String: String] = [:]
        if sqlite3_prepare_v2(db, "SELECT name, value FROM storage", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let k = String(cString: sqlite3_column_text(stmt, 0))
                let v = sqlite3_column_text(stmt, 1).map { String(cString: $0) } ?? "null"
                now[k] = String(v.prefix(200))
            }
        }
        sqlite3_finalize(stmt)
        let old = Self.lastStorage
        if old.isEmpty {
            print("DIFF: lưu mốc \(now.count) key (lần đầu)")
        } else {
            print("===== DIFF storage =====")
            for k in Set(old.keys).union(now.keys).sorted() where old[k] != now[k] {
                print("\(k): \(old[k] ?? "<không có>")  ->  \(now[k] ?? "<đã xoá>")")
            }
            print("===== END DIFF =====")
        }
        Self.lastStorage = now
    }
    
}
