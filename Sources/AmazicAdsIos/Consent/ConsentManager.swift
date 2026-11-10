import Foundation
import UserMessagingPlatform
import UIKit

/// Port `consent_manager.dart` (UMP).
public final class ConsentManager {
    public static let shared = ConsentManager()

    public private(set) var canRequestAds = false

    /// Bật để test form UMP như đang ở EEA.
    public var debugUmp = false
    public var testIdentifiers: [String] = []

    /// Xin consent UMP thủ công (khi app không dùng `Admob.initSplash`).
    /// Xong (có / không có consent) gọi completion với `canRequestAds`.
    public func requestConsent(completion: @escaping (Bool) -> Void) {
        handleRequestUmp { [weak self] in
            completion(self?.canRequestAds ?? false)
        }
    }

    /// Mở lại form tuỳ chọn quyền riêng tư (nút "Privacy settings" trong app).
    public func presentPrivacyOptionsForm(completion: ((Error?) -> Void)? = nil) {
        onMain {
            ConsentForm.presentPrivacyOptionsForm(from: UIHelper.topViewController) { error in
                completion?(error)
            }
        }
    }

    func handleRequestUmp(onPostExecute: @escaping () -> Void) {
        AdsLog.d("ump: start request")
        if canRequestAds {
            onPostExecute()
            return
        }

        let finish: (Bool) -> Void = { [weak self] value in
            onMain {
                self?.canRequestAds = value
                AdsLog.d("ump: canRequestAds = \(value)")
                if value { Admob.shared.initAdmob() }
                onPostExecute()
            }
        }

        if let consentResult = ConsentPurpose.hasConsentPurposeOne() {
            finish(consentResult)
            return
        }

        let parameters = RequestParameters()
        if debugUmp {
            let debugSettings = DebugSettings()
            debugSettings.geography = .EEA
            debugSettings.testDeviceIdentifiers = testIdentifiers
            parameters.debugSettings = debugSettings
        }

        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
            if error != nil {
                AdsLog.d("ump: requestConsentInfoUpdate error")
                finish(true)
                return
            }
            guard ConsentInformation.shared.formStatus == .available else {
                finish(true)
                return
            }
            ConsentForm.load { form, loadError in
                if let result = ConsentPurpose.hasConsentPurposeOne() {
                    finish(result)
                    return
                }
                guard loadError == nil, let form else {
                    finish(ConsentPurpose.hasConsentPurposeOne() ?? true)
                    return
                }
                onMain {
                    form.present(from: UIHelper.topViewController) { _ in
                        finish(ConsentPurpose.hasConsentPurposeOne() ?? true)
                    }
                }
            }
        }
    }
}
