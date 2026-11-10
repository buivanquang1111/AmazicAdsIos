import SwiftUI
import UIKit

/// Màn "Loading Ads" (thay cho showLoadingDialog/closeLoadingDialog).
/// Được present dạng overFullScreen, ads full screen sẽ present đè lên nó.
public final class LoadingOverlay: ObservableObject {
    public static let shared = LoadingOverlay()

    /// Tương ứng `Admob.isShowDialogLoadingAds` — dùng để ẩn Collapsible Native khi đang loading.
    @Published public private(set) var isShowing = false

    private weak var loadingVC: UIViewController?
    /// Đang trong lúc present màn loading -> các việc present khác phải đợi xong.
    private var isTransitioning = false
    private var pendingBlocks: [() -> Void] = []

    public func show() {
        onMain { [self] in
            guard loadingVC == nil, let top = UIHelper.topViewController else { return }
            AdsLog.d("showLoadingDialog")
            let vc = UIHostingController(rootView: LoadingAdsView())
            vc.modalPresentationStyle = .overFullScreen
            vc.view.backgroundColor = .white
            loadingVC = vc
            isShowing = true
            isTransitioning = true
            top.present(vc, animated: false) { [weak self] in
                self?.isTransitioning = false
                self?.flushPending()
            }
        }
    }

    public func hide() {
        whenReady { [self] in
            isShowing = false
            guard let vc = loadingVC else { return }
            AdsLog.d("closeLoadingDialog")
            loadingVC = nil
            if vc.presentingViewController != nil {
                vc.dismiss(animated: false)
            }
        }
    }

    /// Chạy block khi màn loading đã present xong (tránh lỗi "presentation in progress").
    func whenReady(_ block: @escaping () -> Void) {
        onMain { [self] in
            if isTransitioning {
                pendingBlocks.append(block)
            } else {
                block()
            }
        }
    }

    private func flushPending() {
        let blocks = pendingBlocks
        pendingBlocks.removeAll()
        blocks.forEach { $0() }
    }
}

struct LoadingAdsView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    .scaleEffect(1.3)
                Text("Loading Ads")
                    .font(.system(size: 14))
                    .foregroundColor(.black)
            }
        }
    }
}
