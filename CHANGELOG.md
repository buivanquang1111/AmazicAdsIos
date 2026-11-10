# Changelog

## 1.0.0
- Phát hành đầu tiên, port từ plugin Flutter `amazic_ads_flutter`.
- Splash: 1 timeout 12s bao toàn bộ (UMP + ID API + load ads), không chờ Remote Config.
- Inter / App Open / Reward: load & show, interval, Ad Preloading (SDK hoặc pool dự phòng), callback `onNext`.
- Banner, collapsible banner, Native (`small`/`medium`/`fullScreen`/`.nib`/`.custom`, `NativeAdStyle`, vị trí CTA), native after inter.
- UMP consent, App Open khi resume, Welcome Back.
- Tích hợp sẵn Adjust 5 (ad revenue) và Firebase 12.14 (Analytics, Remote Config).
- Check công nghệ lõi (CNL) qua `test_mode_enabled`.
