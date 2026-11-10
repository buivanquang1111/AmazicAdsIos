import SwiftUI

/// Hiệu ứng shimmer đơn giản.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [Color.white.opacity(0), Color.white.opacity(0.6), Color.white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width * 1.6)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}

private struct ShimmerBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var radius: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.gray.opacity(0.25))
            .frame(width: width, height: height)
    }
}

/// Port `shimmer_banner_ads.dart`.
public struct ShimmerBannerAds: View {
    var height: CGFloat

    public init(height: CGFloat = 60) {
        self.height = height
    }

    public var body: some View {
        HStack(spacing: 10) {
            ShimmerBlock(width: 40, height: 40, radius: 6)
            VStack(alignment: .leading, spacing: 6) {
                ShimmerBlock(height: 12)
                ShimmerBlock(width: 120, height: 10)
            }
            ShimmerBlock(width: 70, height: 32, radius: 6)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Color.white)
        .shimmering()
    }
}

/// Port `shimmer_native_ads.dart`.
public struct ShimmerNativeAds: View {
    var height: CGFloat

    public init(height: CGFloat) {
        self.height = height
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ShimmerBlock(width: 44, height: 44, radius: 8)
                VStack(alignment: .leading, spacing: 6) {
                    ShimmerBlock(height: 12)
                    ShimmerBlock(width: 160, height: 10)
                }
            }
            if height > 160 {
                ShimmerBlock(height: max(height - 130, 40), radius: 6)
            }
            ShimmerBlock(height: 40, radius: 8)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Color.white)
        .shimmering()
    }
}
