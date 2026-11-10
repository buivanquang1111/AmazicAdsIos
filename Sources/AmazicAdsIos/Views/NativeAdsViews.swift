import SwiftUI

// MARK: - NativeAds (load tại chỗ)

final class NativeAdsModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded(AmazicNativeAd)
        case hidden
    }

    @Published var state: State = .idle

    var idAds = ""
    var config = false
    var name = ""
    var onAdLoaded: (() -> Void)?
    var onAdFailedToLoad: (() -> Void)?
    var onAdImpression: (() -> Void)?
    var onAdClicked: (() -> Void)?

    private var refreshTimer: AdRefreshTimer?
    private var isRequesting = false

    func setRefresh(_ seconds: Int) {
        guard refreshTimer == nil else { return }
        refreshTimer = AdRefreshTimer(intervalSec: seconds) { [weak self] in self?.load() }
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
            return
        }
        isRequesting = true
        // Giữ ads cũ trong lúc refresh, chỉ hiện shimmer ở lần load đầu.
        if case .loaded = state {} else { state = .loading }

        NativeAdFetcher.load(
            adUnitId: idAds,
            name: name,
            onLoaded: { [weak self] ad in
                guard let self else { return }
                self.isRequesting = false
                self.state = .loaded(ad)
                self.onAdLoaded?()
            },
            onFailed: { [weak self] _ in
                guard let self else { return }
                self.isRequesting = false
                if case .loaded = self.state {} else { self.state = .hidden }
                self.refreshTimer?.start()
                self.onAdFailedToLoad?()
            },
            onImpression: { [weak self] in
                self?.refreshTimer?.start()
                self?.onAdImpression?()
            },
            onClick: { [weak self] in self?.onAdClicked?() }
        )
    }
}

/// Port `native_ads.dart`.
public struct NativeAds: View {
    private let idAds: String
    private let config: Bool
    private let height: CGFloat
    private let layout: NativeAdLayout
    private let style: NativeAdStyle
    private let refreshSec: Int
    private let name: String
    private let onAdLoaded: (() -> Void)?
    private let onAdFailedToLoad: (() -> Void)?
    private let onAdImpression: (() -> Void)?
    private let onAdClicked: (() -> Void)?

    @StateObject private var model = NativeAdsModel()

    public init(
        idAds: String,
        config: Bool,
        height: CGFloat,
        layout: NativeAdLayout = .medium,
        style: NativeAdStyle = .default,
        refreshSec: Int = 0,
        name: String,
        onAdLoaded: (() -> Void)? = nil,
        onAdFailedToLoad: (() -> Void)? = nil,
        onAdImpression: (() -> Void)? = nil,
        onAdClicked: (() -> Void)? = nil
    ) {
        self.idAds = idAds
        self.config = config
        self.height = height
        self.layout = layout
        self.style = style
        self.refreshSec = refreshSec
        self.name = name
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
                model.onAdLoaded = onAdLoaded
                model.onAdFailedToLoad = onAdFailedToLoad
                model.onAdImpression = onAdImpression
                model.onAdClicked = onAdClicked
                model.setRefresh(refreshSec)
                model.setVisible(true)
                model.loadIfNeeded()
            }
            .onDisappear { model.setVisible(false) }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle, .loading:
            ShimmerNativeAds(height: height)
        case .loaded(let ad):
            NativeAdContainer(ad: ad, layout: layout, style: style)
                .frame(maxWidth: .infinity)
                .frame(height: height)
        case .hidden:
            EmptyView()
        }
    }
}

// MARK: - CollapsibleNativeAds

/// Port `collapsible_native_ads.dart`: native to (bung lên trên) có nút thu nhỏ về native nhỏ.
/// View chiếm chỗ đúng `smallHeight` trong layout, phần to vẽ đè lên nội dung phía trên.
public struct CollapsibleNativeAds: View {
    private let idAds: String
    private let config: Bool
    private let bigLayout: NativeAdLayout
    private let smallLayout: NativeAdLayout
    private let style: NativeAdStyle
    private let bigHeight: CGFloat
    private let smallHeight: CGFloat
    private let refreshSec: Int
    private let name: String
    /// true: mỗi lần refresh lại bung to.
    private let isAlwaysShowCollapse: Bool
    private let onAdLoaded: (() -> Void)?
    private let onAdFailedToLoad: (() -> Void)?
    private let onAdImpression: (() -> Void)?
    private let onAdClicked: (() -> Void)?

    @StateObject private var model = NativeAdsModel()
    @ObservedObject private var loading = LoadingOverlay.shared
    @State private var isExpanded = true

    public init(
        idAds: String,
        config: Bool,
        bigLayout: NativeAdLayout = .medium,
        smallLayout: NativeAdLayout = .small,
        style: NativeAdStyle = .default,
        bigHeight: CGFloat = 268,
        smallHeight: CGFloat = 130,
        refreshSec: Int = 0,
        name: String,
        isAlwaysShowCollapse: Bool = false,
        onAdLoaded: (() -> Void)? = nil,
        onAdFailedToLoad: (() -> Void)? = nil,
        onAdImpression: (() -> Void)? = nil,
        onAdClicked: (() -> Void)? = nil
    ) {
        self.idAds = idAds
        self.config = config
        self.bigLayout = bigLayout
        self.smallLayout = smallLayout
        self.style = style
        self.bigHeight = bigHeight
        self.smallHeight = smallHeight
        self.refreshSec = refreshSec
        self.name = name
        self.isAlwaysShowCollapse = isAlwaysShowCollapse
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
                model.onAdLoaded = {
                    if isAlwaysShowCollapse { isExpanded = true }
                    onAdLoaded?()
                }
                model.onAdFailedToLoad = onAdFailedToLoad
                model.onAdImpression = onAdImpression
                model.onAdClicked = onAdClicked
                model.setRefresh(refreshSec)
                model.setVisible(true)
                model.loadIfNeeded()
            }
            .onDisappear { model.setVisible(false) }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle, .loading:
            ShimmerNativeAds(height: smallHeight)
        case .hidden:
            EmptyView()
        case .loaded(let ad):
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: smallHeight)
                .overlay(alignment: .bottom) {
                    if !loading.isShowing {
                        ZStack(alignment: .topTrailing) {
                            NativeAdContainer(ad: ad, layout: isExpanded ? bigLayout : smallLayout, style: style)
                                .frame(maxWidth: .infinity)
                                .frame(height: isExpanded ? bigHeight : smallHeight)
                                .shadow(color: .black.opacity(isExpanded ? 0.12 : 0), radius: 1)

                            if isExpanded {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.4)) { isExpanded = false }
                                } label: {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(Color.white).shadow(color: .black.opacity(0.26), radius: 5))
                                }
                                .padding(.top, 8)
                                .padding(.trailing, 14)
                            }
                        }
                    }
                }
                .zIndex(1)
        }
    }
}

// MARK: - PreloadNativeAds

/// Hiển thị native đã preload bằng `NativeAdPreloadManager` (giống `NativeAdManager().showAd`).
public struct PreloadNativeAds<Placeholder: View>: View {
    private let nameIdAds: String
    private let config: Bool
    private let height: CGFloat
    private let layout: NativeAdLayout
    private let style: NativeAdStyle
    private let placeholder: Placeholder

    @ObservedObject private var manager = NativeAdPreloadManager.shared

    public init(
        nameIdAds: String,
        config: Bool,
        height: CGFloat,
        layout: NativeAdLayout = .medium,
        style: NativeAdStyle = .default,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.nameIdAds = nameIdAds
        self.config = config
        self.height = height
        self.layout = layout
        self.style = style
        self.placeholder = placeholder()
    }

    public var body: some View {
        if !NativeAdFetcher.canShowAds(config: config) {
            EmptyView()
        } else {
            switch manager.states[nameIdAds] {
            case .loading:
                ShimmerNativeAds(height: height)
            case .loaded(let ad) where !ad.isExpired:
                NativeAdContainer(ad: ad, layout: layout, style: style)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
            default:
                // Lỗi / chưa preload / ads quá 1 giờ
                placeholder
            }
        }
    }
}

extension PreloadNativeAds where Placeholder == EmptyView {
    public init(nameIdAds: String, config: Bool, height: CGFloat, layout: NativeAdLayout = .medium, style: NativeAdStyle = .default) {
        self.init(nameIdAds: nameIdAds, config: config, height: height, layout: layout, style: style) { EmptyView() }
    }
}

// MARK: - Native after inter

/// Port `native_after_inter_screen.dart`: native full màn + nút đóng.
public struct NativeAfterInterScreen: View {
    private let adsKey: String
    private let remoteKey: String
    private let layout: NativeAdLayout
    private let style: NativeAdStyle
    private let onClose: () -> Void

    public init(adsKey: String, remoteKey: String, layout: NativeAdLayout = .fullScreen, style: NativeAdStyle = .default, onClose: @escaping () -> Void) {
        self.adsKey = adsKey
        self.remoteKey = remoteKey
        self.layout = layout
        self.style = style
        self.onClose = onClose
    }

    public var body: some View {
        // GeometryReader lấy đúng vùng an toàn (dưới status bar, trên home indicator)
        // -> nút đóng luôn nằm dưới status bar, bấm được.
        GeometryReader { geo in
            PreloadNativeAds(
                nameIdAds: adsKey,
                config: AdsRemoteConfig.getBool(remoteKey),
                height: geo.size.height,
                layout: layout,
                style: style
            )
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .topTrailing) {
                Button {
                    AdsLog.d("Native After Inter - click close")
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                        .frame(width: 44, height: 44) // vùng bấm tối thiểu 44pt theo Apple
                        .contentShape(Rectangle())
                }
                .padding(.top, 4)
                .padding(.trailing, 8)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}
