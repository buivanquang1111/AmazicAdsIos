import AdjustSdk
import Foundation

/// Port `adjust_util.dart`, viết theo tài liệu Adjust iOS SDK v5:
/// - Tích hợp: https://dev.adjust.com/en/sdk/ios/
/// - Ad revenue: https://dev.adjust.com/en/sdk/ios/features/ad-revenue
/// - AdMob: https://dev.adjust.com/en/sdk/ios/integrations/admob
///
/// Gọi `AdjustUtil.shared.setUp(appToken:)` 1 lần lúc mở app -> doanh thu mọi ads
/// (inter / app open / reward / banner / native) tự gửi lên Adjust với source `admob_sdk`.
public final class AdjustUtil: AdsRevenueTracker {
    public static let shared = AdjustUtil()
    private init() {}

    public private(set) var isInitialized = false

    /// Event token Adjust gửi kèm revenue (giống `eventTrackingAdjust` bên Flutter). Rỗng = không gửi.
    public var revenueEventToken = ""

    /// Khởi tạo Adjust SDK.
    /// - Parameters:
    ///   - appToken: App token trên dashboard Adjust.
    ///   - isSandbox: true khi test (`ADJEnvironmentSandbox`), false khi phát hành (`ADJEnvironmentProduction`).
    ///     Mặc định: build Debug = sandbox, Release = production.
    ///   - revenueEventToken: event token gửi kèm revenue (tuỳ chọn).
    public func setUp(appToken: String, isSandbox: Bool? = nil, revenueEventToken: String = "") {
        guard !isInitialized else { return }

        #if DEBUG
        let sandbox = isSandbox ?? true
        #else
        let sandbox = isSandbox ?? false
        #endif

        let environment = sandbox ? ADJEnvironmentSandbox : ADJEnvironmentProduction
        guard let config = ADJConfig(appToken: appToken, environment: environment) else {
            AdsLog.d("Adjust: ADJConfig không hợp lệ (kiểm tra app token)")
            return
        }
        // Test: verbose để xem log / lấy thông tin thiết bị. Phát hành: tắt log.
        config.logLevel = sandbox ? ADJLogLevel.verbose : ADJLogLevel.suppress

        Adjust.initSdk(config)
        isInitialized = true
        self.revenueEventToken = revenueEventToken

        // Tự gắn làm nơi nhận doanh thu ads (nếu app chưa gắn tracker khác).
        if Admob.shared.revenueTracker == nil {
            Admob.shared.revenueTracker = self
        }
        AdsLog.d("Adjust: initSdk - environment = \(environment)")
    }

    // MARK: - AdsRevenueTracker

    /// Gửi doanh thu 1 lần hiển thị ads AdMob lên Adjust.
    /// `AdValue.value` của Google là giá trị theo đơn vị tiền tệ -> `info.revenue`.
    public func trackAdRevenue(_ info: AdRevenueInfo) {
        guard isInitialized else {
            AdsLog.d("Adjust: chưa setUp -> bỏ qua revenue")
            return
        }

        if let adRevenue = ADJAdRevenue(source: "admob_sdk") {
            adRevenue.setRevenue(info.revenue, currency: info.currency)
            adRevenue.setAdImpressionsCount(1)
            if let network = info.network {
                adRevenue.setAdRevenueNetwork(network)
            }
            adRevenue.setAdRevenueUnit(info.adUnitId)
            adRevenue.setAdRevenuePlacement(info.adFormat)
            // Giống bản Flutter
            adRevenue.addPartnerParameter("ad_unit_id", value: info.adUnitId)
            adRevenue.addPartnerParameter("ad_format", value: info.adFormat)
            Adjust.trackAdRevenue(adRevenue)
        }

        guard !revenueEventToken.isEmpty else { return }
        let event: ADJEvent? = ADJEvent(eventToken: revenueEventToken)
        if let event {
            event.setRevenue(info.revenue, currency: info.currency)
            Adjust.trackEvent(event)
        }
    }

    // MARK: - Event

    /// Gửi 1 event Adjust (tuỳ chọn có revenue).
    public func trackEvent(_ eventToken: String, revenue: Double? = nil, currency: String = "USD") {
        guard isInitialized else { return }
        let event: ADJEvent? = ADJEvent(eventToken: eventToken)
        guard let event else { return }
        if let revenue { event.setRevenue(revenue, currency: currency) }
        Adjust.trackEvent(event)
    }
}
