import Foundation
import SwiftUI

/// Port `preload_native_manager.dart`: preload native theo tên vị trí, hiển thị sau qua `PreloadNativeAds`.
///
/// Theo khuyến nghị của Google:
/// - Không gọi load lại khi request trước chưa xong.
/// - Native ads hết hạn sau 1 giờ -> ads quá 1 giờ coi như không có, `preloadAd` lại sẽ load mới.
/// - Chỉ giữ ads cần dùng (native tốn bộ nhớ) -> dùng xong gọi `disposeAd`.
public final class NativeAdPreloadManager: ObservableObject {
    public static let shared = NativeAdPreloadManager()

    public enum State {
        case loading
        case loaded(AmazicNativeAd)
        case failed
    }

    @Published public private(set) var states: [String: State] = [:]

    public func preloadAd(
        adUnitId: String,
        config: Bool,
        nameIdAds: String,
        name: String? = nil,
        onAdLoaded: (() -> Void)? = nil,
        onAdFailed: ((String) -> Void)? = nil
    ) {
        AdsLog.d("preload_native: start load \(nameIdAds)")
        guard NativeAdFetcher.canShowAds(config: config) else {
            AdsLog.d("preload_native: canShowAds = false => not preload \(nameIdAds)")
            return
        }
        switch states[nameIdAds] {
        case .loading:
            AdsLog.d("preload_native: \(nameIdAds) đang load -> bỏ qua")
            return
        case .loaded(let ad) where !ad.isExpired:
            AdsLog.d("preload_native: \(nameIdAds) đã có ads còn hạn")
            onAdLoaded?()
            return
        default:
            break
        }
        states[nameIdAds] = .loading

        NativeAdFetcher.load(
            adUnitId: adUnitId,
            name: name ?? nameIdAds,
            onLoaded: { [weak self] ad in
                AdsLog.d("preload_native: load xong \(nameIdAds)")
                self?.states[nameIdAds] = .loaded(ad)
                onAdLoaded?()
            },
            onFailed: { [weak self] message in
                AdsLog.d("preload_native: load false \(nameIdAds), error: \(message)")
                self?.states[nameIdAds] = .failed
                onAdFailed?(message)
            }
        )
    }

    /// Có ads đã load và còn hạn (< 1 giờ).
    public func isAdReady(_ nameIdAds: String) -> Bool {
        ad(for: nameIdAds) != nil
    }

    public func isLoading(_ nameIdAds: String) -> Bool {
        if case .loading = states[nameIdAds] { return true }
        return false
    }

    /// Ads còn hạn của vị trí (quá 1 giờ trả nil).
    public func ad(for nameIdAds: String) -> AmazicNativeAd? {
        if case .loaded(let ad) = states[nameIdAds], !ad.isExpired { return ad }
        return nil
    }

    /// Bỏ ads của vị trí khi không dùng nữa (giải phóng bộ nhớ).
    public func disposeAd(_ nameIdAds: String) {
        states.removeValue(forKey: nameIdAds)
    }

    public func disposeAll() {
        states.removeAll()
    }
}
