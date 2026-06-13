import GoogleMobileAds
import SwiftUI

struct AdBannerSlot: View {
    let placement: AdPlacement
    var horizontalInset: CGFloat = 0

    @Environment(SubscriptionManager.self) private var subscriptionManager

    var body: some View {
        if AdMobConfig.shouldShowBanner(
            for: placement,
            isBundleActive: subscriptionManager.isBundleActive
        ) {
            GeometryReader { geometry in
                let availableWidth = max(320, geometry.size.width - horizontalInset)
                let adSize = largeAnchoredAdaptiveBanner(width: availableWidth)

                HStack {
                    Spacer(minLength: 0)
                    BannerViewContainer(
                        adSize: adSize,
                        adUnitID: AdMobConfig.bannerAdUnitID
                    )
                    .frame(
                        width: adSize.size.width,
                        height: adSize.size.height
                    )
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: adSize.size.height)
            }
            .frame(height: 72)
            .accessibilityIdentifier("adBannerSlot_\(placement)")
            .accessibilityHidden(true)
        }
    }
}

private struct BannerViewContainer: UIViewRepresentable {
    let adSize: AdSize
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    func makeCoordinator() -> BannerCoordinator {
        BannerCoordinator()
    }
}

private final class BannerCoordinator: NSObject, BannerViewDelegate {
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        #if DEBUG
        print("AdMob banner failed to load: \(error.localizedDescription)")
        #endif
    }
}
