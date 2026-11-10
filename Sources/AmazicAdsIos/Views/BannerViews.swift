import GoogleMobileAds
import SwiftUI
import UIKit

public enum CollapseBannerType {
    case collapsibleTop
    case collapsibleBottom

    var extraValue: String {
        switch self {
        case .collapsibleTop: return "top"
        case .collapsibleBottom: return "bottom"
        }
    }
}

// MARK: - Model

final class BannerAdsModel: NSObject, ObservableObject, BannerViewDelegate {
    enum State {
        case idle
        case loading
        case loaded
        case hidden
    }

    @Published var state: State = .idle
    @Published private(set) var bannerView: BannerView?
    @Published private(set) var adHeight: CGFloat = 60

    var idAds = ""
    var config = false
    var name = ""
    var collapseType: CollapseBannerType?
    var onAdLoaded: (() -> Void)?
    var onAdFailedToLoad: (() -> Void)?
    var onAdImpression: (() -> Void)?
    var onAdClicked: (() -> Void)?
    var onAdDisable: (() -> Void)?

    /// Collapsible: false khi đang không ở màn có banner (vd: đang show welcome back) -> không load/refresh.
    var isScreenShowCollapse = true

    private var refreshTimer: AdRefreshTimer?
    private var isRequesting = false

    func setRefresh(_ seconds: Int) {
        guard refreshTimer == nil else { return }
        refreshTimer = AdRefreshTimer(intervalSec: seconds) { [weak self] in
            guard let self, self.isScreenShowCollapse else { return }
            self.load()
        }
    }

    func setVisible(_ visible: Bool) {
        refreshTimer?.setVisible(visible)
    }

    func loadIfNeeded() {
        if case .idle = state { load() }
    }

    func load() {
        guard !isRequesting else { return }
        guard NativeAdFetcher.canShowAds(config: config) else {
            EventLog.logEvent("\(name)_not_request", parameters: [
                "config": "\(config)",
                "ump": "\(ConsentManager.shared.canRequestAds)",
                "isShowAllAds": "\(Admob.shared.isShowAllAds)",
                "isNetwork": "\(Admob.shared.isNetworkActive())"
            ])
            state = .hidden
            onAdDisable?()
            return
        }

        let adSize = currentOrientationAnchoredAdaptiveBanner(width: UIHelper.screenWidth)
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = idAds
        banner.rootViewController = UIHelper.topViewController
        banner.delegate = self
        let format = name
        let unitId = idAds
        banner.paidEventHandler = { [weak banner] adValue in
            Revenue.track(adValue, responseInfo: banner?.responseInfo, adUnitId: unitId, format: format)
        }

        let request = Request()
        if let collapseType {
            let extras = Extras()
            extras.additionalParameters = ["collapsible": collapseType.extraValue]
            request.register(extras)
        }

        isRequesting = true
        if bannerView == nil { state = .loading }
        adHeight = adSize.size.height
        EventLog.logEvent("\(name)_request")
        pendingBanner = banner
        banner.load(request)
    }

    /// Banner mới đang load (chỉ thay banner cũ khi load xong để không bị nháy).
    private var pendingBanner: BannerView?

    /// Đóng collapsible (bỏ banner hiện tại).
    func close() {
        refreshTimer?.stop()
        bannerView = nil
        pendingBanner = nil
        isRequesting = false
        state = .hidden
    }

    // MARK: BannerViewDelegate

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        onMain { [self] in
            guard bannerView === pendingBanner else { return }
            isRequesting = false
            pendingBanner = nil
            if collapseType != nil && !isScreenShowCollapse {
                AdsLog.d("collapse_banner: NOT show, isScreenShowCollapse = false")
                return
            }
            self.bannerView = bannerView
            state = .loaded
            onAdLoaded?()
        }
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        let message = error.localizedDescription
        onMain { [self] in
            guard bannerView === pendingBanner else { return }
            isRequesting = false
            pendingBanner = nil
            EventLog.logEvent("\(name)_fail", parameters: ["error": message])
            if self.bannerView == nil { state = .hidden }
            refreshTimer?.start()
            onAdFailedToLoad?()
        }
    }

    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        onMain { [self] in
            refreshTimer?.start()
            EventLog.logEvent("\(name)_view")
            onAdImpression?()
        }
    }

    func bannerViewDidRecordClick(_ bannerView: BannerView) {
        onMain { [self] in
            EventLog.logEvent("\(name)_click")
            onAdClicked?()
        }
    }
}

struct BannerContainer: UIViewRepresentable {
    let bannerView: BannerView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        attach(bannerView, to: container)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if bannerView.superview !== uiView {
            attach(bannerView, to: uiView)
        }
    }

    private func attach(_ banner: BannerView, to container: UIView) {
        container.subviews.forEach { $0.removeFromSuperview() }
        banner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}

// MARK: - BannerAds

/// Port `banner_ads.dart`: adaptive banner + shimmer + refresh.
public struct BannerAds: View {
    private let idAds: String
    private let config: Bool
    private let name: String
    private let refreshSec: Int
    private let onAdLoaded: (() -> Void)?
    private let onAdFailedToLoad: (() -> Void)?
    private let onAdImpression: (() -> Void)?
    private let onAdClicked: (() -> Void)?
    private let onAdDisable: (() -> Void)?

    @StateObject private var model = BannerAdsModel()

    public init(
        idAds: String,
        config: Bool,
        name: String,
        refreshSec: Int = 0,
        onAdLoaded: (() -> Void)? = nil,
        onAdFailedToLoad: (() -> Void)? = nil,
        onAdImpression: (() -> Void)? = nil,
        onAdClicked: (() -> Void)? = nil,
        onAdDisable: (() -> Void)? = nil
    ) {
        self.idAds = idAds
        self.config = config
        self.name = name
        self.refreshSec = refreshSec
        self.onAdLoaded = onAdLoaded
        self.onAdFailedToLoad = onAdFailedToLoad
        self.onAdImpression = onAdImpression
        self.onAdClicked = onAdClicked
        self.onAdDisable = onAdDisable
    }

    public var body: some View {
        content
            .onAppear {
                model.idAds = idAds
                model.config = config
                model.name = name
                model.onAdLoaded = onAdLoaded
                model.onAdFailedToLoad = onAdFailedToLoad
                model.onAdImpression = onAdImpression
                model.onAdClicked = onAdClicked
                model.onAdDisable = onAdDisable
                model.setRefresh(refreshSec)
                model.setVisible(true)
                model.loadIfNeeded()
            }
            .onDisappear { model.setVisible(false) }
    }

    @ViewBuilder private var content: some View {
        if let banner = model.bannerView {
            BannerContainer(bannerView: banner)
                .frame(maxWidth: .infinity)
                .frame(height: model.adHeight)
                .overlay(alignment: .top) { Rectangle().fill(Color.black).frame(height: 1) }
        } else {
            switch model.state {
            case .idle, .loading:
                ShimmerBannerAds(height: model.adHeight)
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - CollapseBannerAds

/// Điều khiển collapsible banner từ bên ngoài (đóng / load lại, vd khi show welcome back).
public final class CollapseBannerController: ObservableObject {
    fileprivate weak var model: BannerAdsModel?

    public init() {}

    public func setIsOnScreenShowCollapse(_ value: Bool) {
        model?.isScreenShowCollapse = value
    }

    public func closeCollapse() {
        model?.close()
    }

    public func reloadCollapse() {
        model?.close()
        model?.load()
    }
}

/// Port `collapse_banner_ads.dart`: banner collapsible (extras "collapsible": top/bottom).
public struct CollapseBannerAds: View {
    private let idAds: String
    private let config: Bool
    private let name: String
    private let type: CollapseBannerType
    private let refreshSec: Int
    private let controller: CollapseBannerController?
    /// true: tự gắn close/reload vào AppLifecycleReactor để đóng banner khi show welcome back.
    private let bindToResume: Bool
    private let onAdLoaded: (() -> Void)?
    private let onAdFailedToLoad: (() -> Void)?
    private let onAdImpression: (() -> Void)?
    private let onAdClicked: (() -> Void)?

    @StateObject private var model = BannerAdsModel()

    public init(
        idAds: String,
        config: Bool,
        name: String,
        type: CollapseBannerType = .collapsibleBottom,
        refreshSec: Int = 0,
        controller: CollapseBannerController? = nil,
        bindToResume: Bool = true,
        onAdLoaded: (() -> Void)? = nil,
        onAdFailedToLoad: (() -> Void)? = nil,
        onAdImpression: (() -> Void)? = nil,
        onAdClicked: (() -> Void)? = nil
    ) {
        self.idAds = idAds
        self.config = config
        self.name = name
        self.type = type
        self.refreshSec = refreshSec
        self.controller = controller
        self.bindToResume = bindToResume
        self.onAdLoaded = onAdLoaded
        self.onAdFailedToLoad = onAdFailedToLoad
        self.onAdImpression = onAdImpression
        self.onAdClicked = onAdClicked
    }

    public var body: some View {
        content
            .onAppear {
                model.idAds = idAds
                model.config = config
                model.name = name
                model.collapseType = type
                model.onAdLoaded = onAdLoaded
                model.onAdFailedToLoad = onAdFailedToLoad
                model.onAdImpression = onAdImpression
                model.onAdClicked = onAdClicked
                model.isScreenShowCollapse = true
                controller?.model = model
                if bindToResume, let reactor = Admob.shared.appLifecycleReactor {
                    let current = model
                    reactor.onCloseCollapseBanner = { [weak current] in current?.close() }
                    reactor.onReloadCollapseBanner = { [weak current] in current?.load() }
                }
                model.setRefresh(refreshSec)
                model.setVisible(true)
                model.loadIfNeeded()
            }
            .onDisappear {
                model.isScreenShowCollapse = false
                model.setVisible(false)
            }
    }

    @ViewBuilder private var content: some View {
        if let banner = model.bannerView {
            BannerContainer(bannerView: banner)
                .frame(maxWidth: .infinity)
                .frame(height: model.adHeight)
        } else {
            switch model.state {
            case .idle, .loading:
                ShimmerBannerAds(height: model.adHeight)
            default:
                EmptyView()
            }
        }
    }
}
