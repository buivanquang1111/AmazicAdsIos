import AmazicAdsIos
import SwiftUI

struct NativeDemoView: View {
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    title("Native medium (refresh 30s)")
                    NativeAds(
                        idAds: SampleAdsConfig.id(SampleAdsConfig.nativeAll),
                        config: SampleAdsConfig.config(SampleAdsConfig.nativeAll),
                        height: 280,
                        layout: .medium,
                        refreshSec: 30,
                        name: "native_medium"
                    )

                    title("Native small")
                    NativeAds(
                        idAds: SampleAdsConfig.id(SampleAdsConfig.nativeAll),
                        config: SampleAdsConfig.config(SampleAdsConfig.nativeAll),
                        height: 110,
                        layout: .small,
                        name: "native_small"
                    )

                    title("Medium — style tuỳ chỉnh, CTA top")
                    NativeAds(
                        idAds: SampleAdsConfig.id(SampleAdsConfig.nativeAll),
                        config: SampleAdsConfig.config(SampleAdsConfig.nativeAll),
                        height: 320,
                        layout: .medium,
                        style: NativeAdStyle(
                            backgroundColor: UIColor(red: 0.96, green: 0.97, blue: 1.0, alpha: 1),
                            cornerRadius: 12,
                            borderColor: .systemGray4,
                            borderWidth: 1,
                            padding: 12,
                            headlineFont: .boldSystemFont(ofSize: 16),
                            headlineColor: .systemIndigo,
                            ctaPosition: .top,
                            ctaBackgroundColor: .systemGreen,
                            ctaCornerRadius: 22,
                            adBadgeText: "QC",
                            mediaCornerRadius: 8
                        ),
                        name: "native_medium_style"
                    )

                    title("Small — CTA bottom")
                    NativeAds(
                        idAds: SampleAdsConfig.id(SampleAdsConfig.nativeAll),
                        config: SampleAdsConfig.config(SampleAdsConfig.nativeAll),
                        height: 140,
                        layout: .small,
                        style: NativeAdStyle(
                            backgroundColor: .black,
                            headlineColor: .white,
                            bodyColor: .lightGray,
                            ctaPosition: .bottom,
                            ctaBackgroundColor: .systemOrange
                        ),
                        name: "native_small_bottom"
                    )

                    title("Small — CTA top")
                    NativeAds(
                        idAds: SampleAdsConfig.id(SampleAdsConfig.nativeAll),
                        config: SampleAdsConfig.config(SampleAdsConfig.nativeAll),
                        height: 140,
                        layout: .small,
                        style: NativeAdStyle(ctaPosition: .top),
                        name: "native_small_top"
                    )

                    title("Native preload (load từ màn splash)")
                    PreloadNativeAds(
                        nameIdAds: SampleAdsConfig.nativeLanguage,
                        config: SampleAdsConfig.config(SampleAdsConfig.nativeLanguage),
                        height: 280
                    ) {
                        Text("Chưa có native preload")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 60)
                    }

                    Color.clear.frame(height: 300)
                    Text("Nội dung phía trên Collapsible Native ↓")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            // Collapsible native: chiếm 130pt, bung to 268pt đè lên nội dung phía trên
            CollapsibleNativeAds(
                idAds: SampleAdsConfig.id(SampleAdsConfig.nativeCollapse),
                config: SampleAdsConfig.config(SampleAdsConfig.nativeCollapse),
                bigHeight: 268,
                smallHeight: 130,
                refreshSec: 30,
                name: SampleAdsConfig.nativeCollapse,
                isAlwaysShowCollapse: true
            )
        }
        .navigationTitle("Native")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.headline)
    }
}

struct CollapseBannerDemoView: View {
    @StateObject private var controller = CollapseBannerController()

    var body: some View {
        VStack(spacing: 16) {
            Text("Collapsible banner (bottom)")
                .font(.headline)
            HStack {
                Button("Close") { controller.closeCollapse() }
                    .buttonStyle(.bordered)
                Button("Reload") { controller.reloadCollapse() }
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
            CollapseBannerAds(
                idAds: SampleAdsConfig.id(SampleAdsConfig.collapseBanner),
                config: SampleAdsConfig.config(SampleAdsConfig.collapseBanner),
                name: SampleAdsConfig.collapseBanner,
                type: .collapsibleBottom,
                controller: controller
            )
        }
        .padding(.top)
        .navigationTitle("Collapsible banner")
        .navigationBarTitleDisplayMode(.inline)
    }
}
