import Foundation

/// Port `call_api.dart`: lấy danh sách id ads từ server theo tên vị trí.
/// Bỏ timeout 4s của bản cũ — nếu API chưa về khi hết 12s splash thì Admob tự dùng json mặc định.
public final class AdsApi {
    public static let shared = AdsApi()

    /// name -> [ads_id]
    public private(set) var listAdsId: [String: [String]] = [:]
    public private(set) var isIdsReady = false

    private var onResponse: (() -> Void)?

    func callAds(linkServer: String, appId: String, packageName: String, onResponse: @escaping () -> Void) {
        self.onResponse = onResponse

        // Không có server -> dùng luôn json mặc định
        // (bản Flutter gọi server mặc định của 1 app Android, trả id không phải của app này).
        guard !linkServer.isEmpty, !appId.isEmpty else {
            useDefault(reason: "no_link_server")
            return
        }
        let urlString = "\(linkServer)/api/getidv2/\(appId)+\(packageName)"
        guard let url = URL(string: urlString) else {
            useDefault(reason: "invalid_url")
            return
        }

        let start = Date()
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            onMain {
                guard let self else { return }
                if let error {
                    self.useDefault(reason: error.localizedDescription)
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 200, let data, let body = String(data: data, encoding: .utf8) {
                    guard !self.isIdsReady else { return }
                    let seconds = Int(Date().timeIntervalSince(start))
                    AdsLog.d("splash_jsonid_ad_normal - second = \(seconds) - json_id: \(body)")
                    EventLog.logEvent("splash_jsonid_ad_normal")
                    self.applyJson(body)
                } else {
                    self.useDefault(reason: status == 404 ? "404" : "not get id")
                }
            }
        }.resume()
    }

    /// Dùng json id mặc định nếu chưa có id (API lỗi / hết thời gian splash).
    func useDefault(reason: String) {
        guard !isIdsReady else { return }
        AdsLog.d("splash_jsonid_ad_default - \(reason)")
        EventLog.logEvent("splash_jsonid_ad_default", parameters: ["error": reason])
        applyJson(Admob.shared.jsonIdAdsDefault)
    }

    private func applyJson(_ json: String) {
        guard !isIdsReady else { return }
        isIdsReady = true
        convertJsonIdToList(json)
        let callback = onResponse
        onResponse = nil
        callback?()
    }

    func convertJsonIdToList(_ json: String) {
        guard let data = json.data(using: .utf8),
              let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            AdsLog.d("call id: parse json error")
            return
        }
        for item in list {
            guard let name = item["name"] as? String else { continue }
            if listAdsId[name] == nil { listAdsId[name] = [] }
            if let adsId = item["ads_id"] as? String {
                listAdsId[name]?.append(adsId)
            }
        }
    }

    public func getListIDByName(_ name: String) -> [String] {
        listAdsId[name] ?? []
    }

    public func getFirstIDByName(_ name: String) -> String {
        getListIDByName(name).first ?? ""
    }
}
