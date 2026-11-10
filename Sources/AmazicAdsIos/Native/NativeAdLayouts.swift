import GoogleMobileAds
import SwiftUI
import UIKit

/// Layout hiển thị native ad.
///
/// Theo tài liệu "Native advanced" của Google: native ad hiển thị trong `GADNativeAdView`,
/// các asset (headline, media, icon, CTA...) là subview được nối qua outlet,
/// điền nội dung xong mới gán `nativeAdView.nativeAd` (sau cùng).
public enum NativeAdLayout {
    /// Template của thư viện: icon + tiêu đề + mô tả + nút (cao ~ 90-140).
    case small
    /// Template của thư viện: có MediaView (cao ~ 260-320).
    case medium
    /// Template của thư viện: full màn — dùng cho native after inter.
    case fullScreen
    /// Layout từ file XIB của app (cách Google khuyến nghị).
    /// XIB: custom class của view gốc = `GADNativeAdView`, media view = `GADMediaView`,
    /// nối các outlet headlineView / bodyView / iconView / callToActionView / mediaView /
    /// advertiserView / starRatingView / storeView / priceView.
    /// Thư viện tự load XIB, tự điền asset, ẩn asset không có, gán `nativeAd` sau cùng.
    /// (`NativeAdStyle` không áp dụng cho XIB — giao diện do XIB quyết định.)
    case nib(String, bundle: Bundle = .main)
    /// App tự dựng + tự điền `GoogleMobileAds.NativeAdView` (nhớ gán `nativeAd` sau cùng).
    case custom((NativeAd) -> GoogleMobileAds.NativeAdView)

    var key: String {
        switch self {
        case .small: return "small"
        case .medium: return "medium"
        case .fullScreen: return "fullScreen"
        case .nib(let name, let bundle): return "nib_\(bundle.bundleIdentifier ?? "")_\(name)"
        case .custom: return "custom"
        }
    }
}

// MARK: - Style

/// Vị trí nút CTA trong template.
public enum NativeAdCTAPosition: Equatable {
    /// Trên cùng — phía trên cả icon + tiêu đề.
    case top
    /// Dưới cùng.
    case bottom
    /// Bên phải hàng icon + tiêu đề.
    case trailing
}

/// Tuỳ chỉnh giao diện cho template `.small` / `.medium` / `.fullScreen`.
/// Không truyền (hoặc để nil) -> dùng giao diện mặc định.
public struct NativeAdStyle: Equatable {
    // Khung
    public var backgroundColor: UIColor
    public var cornerRadius: CGFloat
    public var borderColor: UIColor?
    public var borderWidth: CGFloat
    /// Khoảng cách nội dung tới viền. nil = mặc định theo layout (small/medium 8, full 16).
    public var padding: CGFloat?

    // Tiêu đề
    /// nil = mặc định theo layout (bold 14, full 17).
    public var headlineFont: UIFont?
    public var headlineColor: UIColor
    public var headlineLines: Int

    // Mô tả
    /// nil = mặc định theo layout (12, full 14).
    public var bodyFont: UIFont?
    public var bodyColor: UIColor
    public var bodyLines: Int

    // Nút CTA
    /// nil = mặc định: small `.trailing`, medium / full `.bottom`.
    public var ctaPosition: NativeAdCTAPosition?
    public var ctaBackgroundColor: UIColor
    public var ctaTextColor: UIColor
    public var ctaFont: UIFont
    public var ctaCornerRadius: CGFloat
    /// nil = mặc định theo layout (small 40, medium 44, full 52).
    public var ctaHeight: CGFloat?
    public var ctaBorderColor: UIColor?
    public var ctaBorderWidth: CGFloat

    // Icon
    /// nil = mặc định theo layout (small 48, medium 44, full 56).
    public var iconSize: CGFloat?
    public var iconCornerRadius: CGFloat

    // Nhãn "Ad" (bắt buộc theo policy, chỉ đổi được chữ / màu)
    public var adBadgeText: String
    public var adBadgeBackgroundColor: UIColor
    public var adBadgeTextColor: UIColor

    // Media (medium / full)
    /// nil = mặc định theo layout (medium 120, full 200).
    public var mediaMinHeight: CGFloat?
    public var mediaCornerRadius: CGFloat

    public init(
        backgroundColor: UIColor = .white,
        cornerRadius: CGFloat = 0,
        borderColor: UIColor? = nil,
        borderWidth: CGFloat = 0,
        padding: CGFloat? = nil,
        headlineFont: UIFont? = nil,
        headlineColor: UIColor = .black,
        headlineLines: Int = 1,
        bodyFont: UIFont? = nil,
        bodyColor: UIColor = .darkGray,
        bodyLines: Int = 2,
        ctaPosition: NativeAdCTAPosition? = nil,
        ctaBackgroundColor: UIColor = UIColor(red: 0.10, green: 0.45, blue: 0.91, alpha: 1),
        ctaTextColor: UIColor = .white,
        ctaFont: UIFont = .boldSystemFont(ofSize: 15),
        ctaCornerRadius: CGFloat = 8,
        ctaHeight: CGFloat? = nil,
        ctaBorderColor: UIColor? = nil,
        ctaBorderWidth: CGFloat = 0,
        iconSize: CGFloat? = nil,
        iconCornerRadius: CGFloat = 8,
        adBadgeText: String = "Ad",
        adBadgeBackgroundColor: UIColor = UIColor(red: 0.98, green: 0.73, blue: 0.0, alpha: 1),
        adBadgeTextColor: UIColor = .white,
        mediaMinHeight: CGFloat? = nil,
        mediaCornerRadius: CGFloat = 0
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.padding = padding
        self.headlineFont = headlineFont
        self.headlineColor = headlineColor
        self.headlineLines = headlineLines
        self.bodyFont = bodyFont
        self.bodyColor = bodyColor
        self.bodyLines = bodyLines
        self.ctaPosition = ctaPosition
        self.ctaBackgroundColor = ctaBackgroundColor
        self.ctaTextColor = ctaTextColor
        self.ctaFont = ctaFont
        self.ctaCornerRadius = ctaCornerRadius
        self.ctaHeight = ctaHeight
        self.ctaBorderColor = ctaBorderColor
        self.ctaBorderWidth = ctaBorderWidth
        self.iconSize = iconSize
        self.iconCornerRadius = iconCornerRadius
        self.adBadgeText = adBadgeText
        self.adBadgeBackgroundColor = adBadgeBackgroundColor
        self.adBadgeTextColor = adBadgeTextColor
        self.mediaMinHeight = mediaMinHeight
        self.mediaCornerRadius = mediaCornerRadius
    }

    /// Giao diện mặc định.
    public static let `default` = NativeAdStyle()
}

// MARK: - Tạo view + điền asset

enum NativeAdRenderer {
    static func makeView(_ layout: NativeAdLayout, style: NativeAdStyle, ad: NativeAd) -> GoogleMobileAds.NativeAdView {
        switch layout {
        case .small, .medium, .fullScreen:
            let view = NativeAdTemplate.build(layout, style: style)
            populate(view, with: ad)
            return view
        case .nib(let name, let bundle):
            guard let view = bundle.loadNibNamed(name, owner: nil, options: nil)?.first as? GoogleMobileAds.NativeAdView else {
                AdsLog.d("native: không load được XIB '\(name)' (view gốc phải có class GADNativeAdView) -> dùng medium")
                let fallback = NativeAdTemplate.build(.medium, style: style)
                populate(fallback, with: ad)
                return fallback
            }
            populate(view, with: ad)
            return view
        case .custom(let builder):
            return builder(ad)
        }
    }

    /// Điền asset đúng như tài liệu Google: headline + mediaContent luôn có,
    /// asset khác có thể nil -> ẩn view; CTA tắt tương tác; gán `nativeAd` sau cùng.
    static func populate(_ adView: GoogleMobileAds.NativeAdView, with nativeAd: NativeAd) {
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        adView.mediaView?.mediaContent = nativeAd.mediaContent

        (adView.bodyView as? UILabel)?.text = nativeAd.body
        adView.bodyView?.isHidden = nativeAd.body == nil

        setText(nativeAd.callToAction, on: adView.callToActionView)
        adView.callToActionView?.isHidden = nativeAd.callToAction == nil

        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        adView.iconView?.isHidden = nativeAd.icon == nil

        if let rating = nativeAd.starRating {
            setText(String(format: "%.1f ★", rating.doubleValue), on: adView.starRatingView)
        }
        adView.starRatingView?.isHidden = nativeAd.starRating == nil

        setText(nativeAd.store, on: adView.storeView)
        adView.storeView?.isHidden = nativeAd.store == nil

        setText(nativeAd.price, on: adView.priceView)
        adView.priceView?.isHidden = nativeAd.price == nil

        setText(nativeAd.advertiser, on: adView.advertiserView)
        adView.advertiserView?.isHidden = nativeAd.advertiser == nil

        // SDK tự xử lý chạm vào CTA.
        adView.callToActionView?.isUserInteractionEnabled = false

        // Gán sau cùng để ads click được.
        adView.nativeAd = nativeAd
    }

    private static func setText(_ text: String?, on view: UIView?) {
        if let label = view as? UILabel {
            label.text = text
        } else if let button = view as? UIButton {
            button.setTitle(text, for: .normal)
        }
    }
}

// MARK: - Template dựng sẵn (bằng code, cùng cấu trúc như XIB)

enum NativeAdTemplate {
    private enum Kind { case small, medium, full }

    static func build(_ layout: NativeAdLayout, style: NativeAdStyle) -> GoogleMobileAds.NativeAdView {
        let kind: Kind
        switch layout {
        case .small: kind = .small
        case .fullScreen: kind = .full
        default: kind = .medium
        }

        let adView = GoogleMobileAds.NativeAdView()
        adView.backgroundColor = style.backgroundColor
        adView.layer.cornerRadius = style.cornerRadius
        adView.clipsToBounds = style.cornerRadius > 0
        if let borderColor = style.borderColor, style.borderWidth > 0 {
            adView.layer.borderColor = borderColor.cgColor
            adView.layer.borderWidth = style.borderWidth
        }

        // Nhãn "Ad" (ad attribution — bắt buộc theo policy)
        let badge = PaddedLabel()
        badge.text = style.adBadgeText
        badge.font = .boldSystemFont(ofSize: 10)
        badge.textColor = style.adBadgeTextColor
        badge.backgroundColor = style.adBadgeBackgroundColor
        badge.textAlignment = .center
        badge.layer.cornerRadius = 3
        badge.clipsToBounds = true
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)
        badge.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let icon = UIImageView()
        icon.contentMode = .scaleAspectFit
        icon.layer.cornerRadius = style.iconCornerRadius
        icon.clipsToBounds = true
        let iconSize = style.iconSize ?? (kind == .full ? 56 : (kind == .small ? 48 : 44))
        icon.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: iconSize).isActive = true

        let headline = UILabel()
        headline.font = style.headlineFont ?? .boldSystemFont(ofSize: kind == .full ? 17 : 14)
        headline.textColor = style.headlineColor
        headline.numberOfLines = style.headlineLines

        let body = UILabel()
        body.font = style.bodyFont ?? .systemFont(ofSize: kind == .full ? 14 : 12)
        body.textColor = style.bodyColor
        body.numberOfLines = style.bodyLines

        // Google khuyến nghị dùng UILabel thay UIButton cho asset.
        let cta = UILabel()
        cta.backgroundColor = style.ctaBackgroundColor
        cta.textColor = style.ctaTextColor
        cta.font = style.ctaFont
        cta.textAlignment = .center
        cta.layer.cornerRadius = style.ctaCornerRadius
        cta.clipsToBounds = true
        if let borderColor = style.ctaBorderColor, style.ctaBorderWidth > 0 {
            cta.layer.borderColor = borderColor.cgColor
            cta.layer.borderWidth = style.ctaBorderWidth
        }
        let ctaHeight = style.ctaHeight ?? (kind == .full ? 52 : (kind == .small ? 40 : 44))
        cta.heightAnchor.constraint(equalToConstant: ctaHeight).isActive = true

        let headlineRow = UIStackView(arrangedSubviews: [badge, headline])
        headlineRow.axis = .horizontal
        headlineRow.spacing = 6
        headlineRow.alignment = .center

        let textColumn = UIStackView(arrangedSubviews: [headlineRow, body])
        textColumn.axis = .vertical
        textColumn.spacing = 4

        let infoRow = UIStackView(arrangedSubviews: [icon, textColumn])
        infoRow.axis = .horizontal
        infoRow.spacing = 10
        infoRow.alignment = .center

        // Vị trí CTA: mặc định small = trailing, medium / full = bottom.
        let position = style.ctaPosition ?? (kind == .small ? .trailing : .bottom)
        if position == .trailing {
            cta.widthAnchor.constraint(equalToConstant: 90).isActive = true
            infoRow.addArrangedSubview(cta)
        }

        var media: MediaView?
        if kind != .small {
            let mediaView = MediaView()
            mediaView.contentMode = .scaleAspectFit
            mediaView.layer.cornerRadius = style.mediaCornerRadius
            mediaView.clipsToBounds = style.mediaCornerRadius > 0
            mediaView.setContentHuggingPriority(.defaultLow, for: .vertical)
            let minHeight = style.mediaMinHeight ?? (kind == .full ? 200 : 120)
            mediaView.heightAnchor.constraint(greaterThanOrEqualToConstant: minHeight).isActive = true
            adView.mediaView = mediaView
            media = mediaView
        }

        // Thứ tự các phần theo layout + vị trí CTA.
        var rows: [UIView]
        switch kind {
        case .small:
            rows = [infoRow]
        case .medium:
            rows = [infoRow] + (media.map { [$0] } ?? [])
        case .full:
            // Full: mặc định media trên, info dưới. CTA top -> CTA, info, media.
            rows = position == .top ? [infoRow] + (media.map { [$0] } ?? []) : (media.map { [$0] } ?? []) + [infoRow]
        }
        switch position {
        case .top: rows.insert(cta, at: 0)
        case .bottom: rows.append(cta)
        case .trailing: break
        }

        let root = UIStackView(arrangedSubviews: rows)
        root.axis = .vertical
        root.spacing = kind == .full ? 16 : 8
        root.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(root)

        let padding = style.padding ?? (kind == .full ? 16 : 8)
        // Full chừa 56pt phía trên cho nút ✕ / AdChoices.
        let topPadding = kind == .full ? max(padding, 56) : padding
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: padding),
            root.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -padding),
            root.topAnchor.constraint(equalTo: adView.safeAreaLayoutGuide.topAnchor, constant: topPadding),
            root.bottomAnchor.constraint(equalTo: adView.safeAreaLayoutGuide.bottomAnchor, constant: -padding)
        ])

        // Nối asset view (tương đương nối outlet trong XIB)
        adView.headlineView = headline
        adView.bodyView = body
        adView.callToActionView = cta
        adView.iconView = icon
        return adView
    }
}

/// Label có padding ngang (nhãn "Ad" / chữ dài như "QC").
final class PaddedLabel: UILabel {
    var horizontalInset: CGFloat = 4

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: horizontalInset, dy: 0))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + horizontalInset * 2, height: size.height)
    }
}

// MARK: - SwiftUI (tương đương NativeAdViewContainer trong tài liệu Google)

/// Hiển thị 1 native ad đã load trong SwiftUI.
struct NativeAdContainer: UIViewRepresentable {
    let ad: AmazicNativeAd
    let layout: NativeAdLayout
    var style: NativeAdStyle = .default

    final class Coordinator {
        weak var currentAd: NativeAd?
        var currentLayoutKey = ""
        var currentStyle: NativeAdStyle?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.clipsToBounds = true
        attach(to: container, context: context)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.currentAd !== ad.nativeAd
            || coordinator.currentLayoutKey != layout.key
            || coordinator.currentStyle != style {
            attach(to: uiView, context: context)
        }
    }

    private func attach(to container: UIView, context: Context) {
        container.subviews.forEach { $0.removeFromSuperview() }
        let adView = NativeAdRenderer.makeView(layout, style: style, ad: ad.nativeAd)
        adView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(adView)
        NSLayoutConstraint.activate([
            adView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            adView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            adView.topAnchor.constraint(equalTo: container.topAnchor),
            adView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        context.coordinator.currentAd = ad.nativeAd
        context.coordinator.currentLayoutKey = layout.key
        context.coordinator.currentStyle = style
    }
}
