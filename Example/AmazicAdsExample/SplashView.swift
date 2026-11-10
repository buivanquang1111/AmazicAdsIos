import AmazicAdsIos
import SwiftUI

struct SplashView: View {
    let onNext: () -> Void
    let onWelcomeBack: () -> Void

    @State private var seconds = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "megaphone.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            Text("AmazicAdsIos Sample")
                .font(.title2.bold())
            ProgressView()
            Text("Splash: \(seconds)s / timeout \(Int(Admob.shared.splashTimeout))s")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text(Admob.shared.isUseAdPreloading ? "Mode: Ad Preloading (SDK)" : "Mode: load & show thường")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .onReceive(timer) { _ in seconds += 1 }
        .onAppear {
            Admob.shared.initSplash(
                SampleAdsConfig.splashConfig,
                onGotoScreenWelcomeBack: onWelcomeBack,
                onStartLoadBanner: {
                    // Preload native cho màn sau (giống preload native language bên Flutter)
                    NativeAdPreloadManager.shared.preloadAd(
                        adUnitId: SampleAdsConfig.id(SampleAdsConfig.nativeLanguage),
                        config: SampleAdsConfig.config(SampleAdsConfig.nativeLanguage),
                        nameIdAds: SampleAdsConfig.nativeLanguage
                    )
                },
                onNext: onNext
            )
        }
    }
}

struct WelcomeBackView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Welcome Back 👋")
                .font(.largeTitle.bold())
            Text("Màn này hiện sau App Open resume\n(isShowWelcomeScreenAfterAppOpenAds = true)")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Tiếp tục") { onClose() }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
        .background(Color.white.ignoresSafeArea())
    }
}
