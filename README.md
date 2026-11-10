# AmazicAdsIos

Thư viện ads cho app **SwiftUI native** (iOS 15+).
Lớp chính: `Admob.shared`.

Thư viện phụ thuộc sẵn **Google Mobile Ads 12 + UMP + Adjust 5 + Firebase 12.14 (Analytics, Remote Config)**
-> app dùng thư viện không cần add lại các package này.

Mặc định thư viện tự dùng `FirebaseUtil` (event, remote config) và `AdjustUtil` (doanh thu).
Muốn thay bằng cách khác thì gán protocol của mình:

| Protocol | Mặc định | Không có thì |
|---|---|---|
| `AdsEventLogger` | `FirebaseUtil` (Analytics) | in log console |
| `AdsRemoteConfigProvider` | `FirebaseUtil` (Remote Config) | dùng giá trị mặc định `RemoteConfigKey` |
| `AdsRevenueTracker` | `AdjustUtil` (sau khi setUp) | in log console |

## Tiến độ

- [x] **Giai đoạn 1** — Khung thư viện (GMA + UMP), provider, loading, inter load & show thường, sample 1 màn
- [x] **Giai đoạn 2** — UMP, Inter / App Open / Reward đầy đủ, Ad Preloading của SDK, interval, splash 12s, resume
- [x] **Giai đoạn 3** — Banner, Collapsible banner, Native, Collapsible native, Preload native, Native after inter
- [ ] Giai đoạn 4 — Adapter Firebase / Adjust, hoàn thiện README, tag 1.0.0

## Splash

```swift
Admob.shared.initSplash(
    SplashConfig(...),                       // xem Example/SampleAdsConfig.swift
    onGotoScreenWelcomeBack: { /* mở màn Welcome Back */ },
    onStartLoadBanner: { /* load banner / native màn sau */ },
    onNext: { /* sang màn tiếp */ }
)
```

- Chạy song song: Remote Config + UMP + API id ads → random App Open / Inter theo `rate_aoa`.
- **Timeout duy nhất** `Admob.shared.splashTimeout` (12s) tính từ lúc gọi `initSplash` tới khi ads splash bắt đầu hiện.
  Hết giờ → `onNext()`. Thời gian user xem form UMP không bị tính.
- Ads splash về muộn được giữ lại → `Admob.shared.showAdsSplash { }` để show sau.
- Không có server id ads (`linkServer` rỗng) hoặc API lỗi / chậm → dùng `jsonIdAdsDefault`.

## Ad Preloading (SDK)

`Admob.shared.isUseAdPreloading = true` → inter / app open / reward dùng Ad Preloading (beta) của Google Mobile Ads SDK
(`InterstitialAdPreloader`, `AppOpenAdPreloader`, `RewardedAdPreloader`, cần GMA >= 12.6.0):

- Preload ID = ad unit id. SDK tự load bù, tự retry, tự làm mới ads hết hạn.
- Số ads giữ sẵn: `interPreloadBuffer` (2), `rewardPreloadBuffer` (1), `appOpenPreloadBuffer` (1), `splashPreloadBuffer` (1).
  **Toàn app tối đa 6 ads preload.**
- Hàm: `loadInterAdPreload` (bắt đầu preload), `showInterAdPreload`, `loadAndShowInterAdPreload`
  (có ads → show, chưa có → Loading + đợi ads về). Reward / App Open tương tự. `destroy(idAds:)` = dừng preload.
- Splash preload chỉ dùng 1 lần, sau khi show tự dừng preload id splash để không chiếm chỗ.

## UMP

Tự chạy trong `initSplash`. App không dùng splash của thư viện: `ConsentManager.shared.requestConsent { canRequest in }`.
Nút "Privacy settings": `ConsentManager.shared.presentPrivacyOptionsForm()`.

## Banner / Native (SwiftUI)

```swift
BannerAds(idAds: id, config: AdsRemoteConfig.getBool("banner_all"), name: "banner_all", refreshSec: 30)

CollapseBannerAds(idAds: id, config: true, name: "collapse_home", type: .collapsibleBottom)

NativeAds(idAds: id, config: true, height: 280, layout: .medium, refreshSec: 30, name: "native_home")

CollapsibleNativeAds(idAds: id, config: true, bigHeight: 268, smallHeight: 130, name: "native_collapse")

// Preload ở màn trước, show ở màn sau
NativeAdPreloadManager.shared.preloadAd(adUnitId: id, config: true, nameIdAds: "native_language")
PreloadNativeAds(nameIdAds: "native_language", config: true, height: 280)
```

- Banner / native đều check giống ads full screen: config + consent UMP + `isShowAllAds` + mạng.
- Refresh tự dừng khi app vào background hoặc view bị ẩn.
- Layout native (`NativeAdLayout`), theo tài liệu "Native advanced" của Google:
  - `.small`, `.medium`, `.fullScreen`: template dựng sẵn.
  - `.nib("TenXib")`: layout từ **XIB** của app (cách Google khuyến nghị). View gốc class `GADNativeAdView`,
    media view class `GADMediaView`, nối outlet `headlineView`, `bodyView`, `iconView`, `callToActionView`, `mediaView`,
    `advertiserView`, `starRatingView`, `storeView`, `priceView`. Thư viện tự load XIB, điền asset, ẩn asset không có,
    tắt tương tác CTA và gán `nativeAd` sau cùng.
  - `.custom { nativeAd in ... }`: app tự dựng + tự điền `GoogleMobileAds.NativeAdView`.
- Tuỳ chỉnh giao diện template `.small` / `.medium` / `.fullScreen` bằng `style:` (không truyền = mặc định):
  ```swift
  NativeAds(idAds: id, config: true, height: 320, layout: .medium,
            style: NativeAdStyle(backgroundColor: .white, cornerRadius: 12,
                                 headlineFont: .boldSystemFont(ofSize: 16), headlineColor: .black,
                                 ctaPosition: .top, ctaBackgroundColor: .systemGreen, ctaCornerRadius: 22),
            name: "native_home")
  ```
  - Khung: `backgroundColor`, `cornerRadius`, `borderColor`, `borderWidth`, `padding`
  - Chữ: `headlineFont/Color/Lines`, `bodyFont/Color/Lines`
  - CTA: `ctaPosition` (`.top` trên cùng / `.bottom` / `.trailing` cạnh tiêu đề; mặc định small `.trailing`,
    medium + full `.bottom`), `ctaBackgroundColor`, `ctaTextColor`, `ctaFont`, `ctaCornerRadius`, `ctaHeight`, `ctaBorderColor/Width`
  - Icon: `iconSize`, `iconCornerRadius` · Nhãn: `adBadgeText/BackgroundColor/TextColor` · Media: `mediaMinHeight`, `mediaCornerRadius`
  - Small dùng CTA `.top` / `.bottom` thì cao hơn (~140) → truyền `height` phù hợp.
  - Native after inter của splash: `Admob.shared.nativeAfterInterLayout` / `nativeAfterInterStyle`.
- Native preload hết hạn sau 1 giờ (theo Google) → coi như không có ads, gọi `preloadAd` lại để load mới.
- Native after inter: `Admob.shared.isUseNativeAfterInter = true` + khai báo `nameIdAdsNativeAfterInter` /
  `nameConfigNativeAfterInter` trong `SplashConfig` → sau inter splash show native full màn, đóng mới `onNext`.

## Adjust

Đã tích hợp sẵn Adjust iOS SDK v5 (theo https://dev.adjust.com/en/sdk/ios/). Gọi 1 lần lúc mở app:

```swift
AdjustUtil.shared.setUp(appToken: "YOUR_APP_TOKEN", revenueEventToken: "abc123")
```

- Debug → `ADJEnvironmentSandbox` + log verbose; Release → `ADJEnvironmentProduction` + tắt log
  (hoặc truyền `isSandbox:` để tự chọn).
- Sau khi setUp, doanh thu mọi ads tự gửi lên Adjust: `ADJAdRevenue(source: "admob_sdk")` + revenue, currency,
  network, ad unit, placement (tên vị trí) + partner params `ad_unit_id`, `ad_format` (giống bản Flutter).
- `revenueEventToken` (tuỳ chọn): gửi thêm 1 event có revenue mỗi lần có doanh thu (giống `eventTrackingAdjust`).
- Gửi event khác: `AdjustUtil.shared.trackEvent("token")`.
- Trên dashboard Adjust phải bật ad revenue, và AdMob phải bật impression-level ad revenue (ILAR).

## Firebase

Đã tích hợp sẵn Firebase **12.14.x** (bản cuối chạy được trên Xcode 16.0; Firebase 12.15+ cần Xcode >= 16.3) (`FirebaseAnalytics`, `FirebaseRemoteConfig`).

1. Kéo `GoogleService-Info.plist` (tải từ Firebase console) vào target app.
2. `Admob.shared.configure()` tự gọi `FirebaseApp.configure()` nếu app chưa gọi.
   Nếu app tự gọi `FirebaseApp.configure()` thì gọi **trước** `Admob.shared.configure()`.
   Không dùng Firebase: `Admob.shared.configure(useFirebase: false)`.
3. Không có `GoogleService-Info.plist` -> không crash, remote config dùng giá trị mặc định.

- Event: mọi `EventLog.logEvent` gửi qua `Analytics.logEvent` (tên đã chuẩn hoá: tối đa 40 ký tự, chữ/số/_).
- Remote Config: giống Flutter `fetchTimeout = 30s`, `minimumFetchInterval = 15s`
  (đổi qua `FirebaseUtil.shared.fetchTimeout / minimumFetchInterval` trước `configure()`).
  Splash **không chờ** fetch: lần đầu dùng default, giá trị server được dùng ngay khi fetch xong.
- Xem event realtime: Xcode > Edit Scheme > Run > Arguments > thêm `-FIRDebugEnabled`, rồi mở Firebase console > DebugView.
- App đang dùng Firebase 13 sẽ xung đột version: chờ thư viện nâng lên 13 (cùng GMA 13, cần Xcode >= 26.2).

## App sample

Mở `Example/AmazicAdsExample.xcodeproj` (Xcode 16+) → chọn simulator → **Cmd + R**.
Sample link tới thư viện bằng local package `..` — sửa code thư viện là sample nhận ngay.

> Không mở `Package.swift` của thư viện ở cửa sổ Xcode khác cùng lúc với sample,
> nếu không sample sẽ không load được local package.

## Cấu hình bắt buộc của app dùng thư viện

1. `Info.plist`: `GADApplicationIdentifier`, `SKAdNetworkItems`.
2. Build Settings → **Other Linker Flags** thêm `-ObjC`.
