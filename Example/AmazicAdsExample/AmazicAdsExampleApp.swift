import AmazicAdsIos
import SwiftUI

@main
struct AmazicAdsExampleApp: App {
    init() {
        // Tự bật Firebase nếu có GoogleService-Info.plist trong target (kéo file vào thư mục AmazicAdsExample).
        // Không có file -> chạy bình thường, remote config dùng giá trị mặc định.
        Admob.shared.configure()

        // Adjust: điền app token thật để test (Debug = sandbox, Release = production).
        // Sau khi setUp, doanh thu mọi ads tự gửi lên Adjust (source "admob_sdk").
        // AdjustUtil.shared.setUp(appToken: "YOUR_ADJUST_APP_TOKEN", revenueEventToken: "")

        // Đổi true để test Ad Preloading của SDK (splash + resume dùng preloader).
        Admob.shared.isUseAdPreloading = false
        // Số ads giữ sẵn mỗi id (toàn app tối đa 6).
        Admob.shared.interPreloadBuffer = 2
        Admob.shared.rewardPreloadBuffer = 1
        Admob.shared.appOpenPreloadBuffer = 1
        // Native full màn sau inter splash.
        Admob.shared.isUseNativeAfterInter = true

        // Test form UMP như đang ở EEA (máy thật cần thêm test device id lấy từ log UMP).
        // ConsentManager.shared.debugUmp = true
        // ConsentManager.shared.testIdentifiers = ["TEST-DEVICE-HASHED-ID"]
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @State private var isSplashDone = false
    @State private var showWelcomeBack = false

    var body: some View {
        Group {
            if isSplashDone {
                NavigationView {
                    HomeView()
                }
                .navigationViewStyle(.stack)
            } else {
                SplashView(
                    onNext: { isSplashDone = true },
                    onWelcomeBack: { showWelcomeBack = true }
                )
            }
        }
        .fullScreenCover(isPresented: $showWelcomeBack) {
            WelcomeBackView { showWelcomeBack = false }
        }
    }
}
