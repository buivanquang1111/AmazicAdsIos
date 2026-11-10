// swift-tools-version: 5.9
import PackageDescription

/// Phụ thuộc: Google Mobile Ads + UMP + Adjust + Firebase (Analytics, Remote Config).
/// App dùng thư viện không cần add lại các package này.
let package = Package(
    name: "AmazicAdsIos",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "AmazicAdsIos", targets: ["AmazicAdsIos"])
    ],
    dependencies: [
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "12.0.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git", from: "3.0.0"),
        // Adjust iOS SDK v5 (tài liệu: https://dev.adjust.com/en/sdk/ios/)
        .package(url: "https://github.com/adjust/ios_sdk", from: "5.0.0"),
        // Firebase 12.x (12.0.0 ..< 13.0.0): hợp Xcode 16+, cùng đời với Google Mobile Ads 12.
        // Firebase 13 cần Xcode >= 26.2 -> nâng cùng lúc với GMA 13.
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.0.0")
    ],
    targets: [
        .target(
            name: "AmazicAdsIos",
            dependencies: [
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
                .product(name: "GoogleUserMessagingPlatform", package: "swift-package-manager-google-user-messaging-platform"),
                .product(name: "AdjustSdk", package: "ios_sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk")
            ],
            linkerSettings: [
                // Framework Adjust cần (tài liệu Adjust): IDFA, Apple Search Ads, SKAdNetwork, ATT.
                .linkedFramework("AdSupport"),
                .linkedFramework("AdServices"),
                .linkedFramework("StoreKit"),
                .linkedFramework("AppTrackingTransparency")
            ]
        )
    ]
)
