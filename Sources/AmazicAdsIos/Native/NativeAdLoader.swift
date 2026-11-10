import Foundation
import GoogleMobileAds
import UIKit

/// Native ad đã load + delegate giữ callback impression / click.
public final class AmazicNativeAd {
    public let nativeAd: NativeAd
    /// Thời điểm load xong (native ads hết hạn sau 1 giờ theo tài liệu Google).
    public let loadedAt = Date()
    public var isExpired: Bool { Date().timeIntervalSince(loadedAt) >= 3600 }
    fileprivate let handler: NativeAdRequest
    /// Callback thêm cho nơi hiển thị (vd: preload xong mới gắn vào view).
    public var onImpression: (() -> Void)?
    public var onClick: (() -> Void)?

    fileprivate init(nativeAd: NativeAd, handler: NativeAdRequest) {
        self.nativeAd = nativeAd
        self.handler = handler
    }
}

/// Load 1 native ad (AdLoader) với callback dạng closure.
final class NativeAdRequest: NSObject, NativeAdLoaderDelegate, NativeAdDelegate {
    private static var active: [ObjectIdentifier: NativeAdRequest] = [:]

    let adUnitId: String
    let name: String
    var onLoaded: ((AmazicNativeAd) -> Void)?
    var onFailed: ((String) -> Void)?
    var onImpression: (() -> Void)?
    var onClick: (() -> Void)?

    private var adLoader: AdLoader?
    private weak var box: AmazicNativeAd?

    init(adUnitId: String, name: String) {
        self.adUnitId = adUnitId
        self.name = name
    }

    func start() {
        onMain { [self] in
            let loader = AdLoader(
                adUnitID: adUnitId,
                rootViewController: UIHelper.topViewController,
                adTypes: [.native],
                options: nil
            )
            loader.delegate = self
            adLoader = loader
            NativeAdRequest.active[ObjectIdentifier(self)] = self
            loader.load(Request())
        }
    }

    private func finishLoading() {
        adLoader = nil
        NativeAdRequest.active.removeValue(forKey: ObjectIdentifier(self))
    }

    // MARK: NativeAdLoaderDelegate

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        onMain { [self] in
            nativeAd.delegate = self
            let adUnitId = self.adUnitId
            let format = self.name
            nativeAd.paidEventHandler = { [weak nativeAd] adValue in
                Revenue.track(adValue, responseInfo: nativeAd?.responseInfo, adUnitId: adUnitId, format: format)
            }
            let winner = nativeAd.responseInfo.loadedAdNetworkResponseInfo
            AdsLog.d("=== MEDIATION WINNER \(name) === network: \(winner?.adSourceName ?? "")")
            let box = AmazicNativeAd(nativeAd: nativeAd, handler: self)
            self.box = box
            finishLoading()
            onLoaded?(box)
        }
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        let message = error.localizedDescription
        onMain { [self] in
            finishLoading()
            onFailed?(message)
        }
    }

    // MARK: NativeAdDelegate

    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
        onMain {
            self.onImpression?()
            self.box?.onImpression?()
        }
    }

    func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
        onMain {
            self.onClick?()
            self.box?.onClick?()
        }
    }
}

/// Load native kèm log event chuẩn (`${name}_request`, `_view`, `_click`, `_fail`).
enum NativeAdFetcher {
    static func load(
        adUnitId: String,
        name: String,
        onLoaded: @escaping (AmazicNativeAd) -> Void,
        onFailed: @escaping (String) -> Void,
        onImpression: (() -> Void)? = nil,
        onClick: (() -> Void)? = nil
    ) {
        EventLog.logEvent("\(name)_request")
        let request = NativeAdRequest(adUnitId: adUnitId, name: name)
        request.onLoaded = onLoaded
        request.onFailed = { message in
            EventLog.logEvent("\(name)_fail", parameters: ["error": message])
            onFailed(message)
        }
        request.onImpression = {
            EventLog.logEvent("\(name)_view")
            onImpression?()
        }
        request.onClick = {
            EventLog.logEvent("\(name)_click")
            onClick?()
        }
        request.start()
    }

    static func canShowAds(config: Bool) -> Bool {
        Admob.shared.canRequestAds(config: config, logName: nil)
    }
}
