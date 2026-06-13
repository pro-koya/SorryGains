import Foundation

enum AdPlacement {
    case historyBottom
    case settingsBottom
    case sageInline
}

enum AdMobConfig {
    static let appID = "ca-app-pub-4570439660764279~1523718276"

    static let testBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let testRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"

    static let productionBannerAdUnitID = "ca-app-pub-4570439660764279/6162320951"
    static let productionRewardedAdUnitID = "ca-app-pub-4570439660764279/1715289963"

    static var useTestAds: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static var bannerAdUnitID: String {
        useTestAds ? testBannerAdUnitID : productionBannerAdUnitID
    }

    static var rewardedAdUnitID: String {
        useTestAds ? testRewardedAdUnitID : productionRewardedAdUnitID
    }

    /// バンドル加入者には広告を表示しない。
    /// - Parameters:
    ///   - placement: 広告の配置場所
    ///   - isBundleActive: Muscle360 Pro バンドル加入中かどうか
    static func shouldShowBanner(
        for placement: AdPlacement,
        isBundleActive: Bool = false
    ) -> Bool {
        // バンドル加入中は全ての広告を非表示
        if isBundleActive { return false }
        switch placement {
        case .historyBottom, .settingsBottom, .sageInline:
            return true
        }
    }
}
