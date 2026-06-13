import GoogleMobileAds
import SwiftUI

@MainActor
final class RewardedAdController: NSObject, ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var isLoading = false
    @Published private(set) var isPresenting = false
    @Published private(set) var lastErrorMessage: String?

    private var rewardedAd: RewardedAd?

    func loadAd() async {
        guard !isLoading, rewardedAd == nil else { return }

        isLoading = true
        lastErrorMessage = nil

        do {
            let ad = try await RewardedAd.load(
                with: AdMobConfig.rewardedAdUnitID,
                request: Request()
            )
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
            isReady = true
        } catch {
            lastErrorMessage = error.localizedDescription
            isReady = false
            rewardedAd = nil
            #if DEBUG
            print("Rewarded ad failed to load: \(error.localizedDescription)")
            #endif
        }

        isLoading = false
    }

    func showAd(onRewardEarned: @escaping () -> Void) {
        guard let rewardedAd else {
            lastErrorMessage = String(localized: "ad.notReady")
            Task { await loadAd() }
            return
        }

        isPresenting = true
        rewardedAd.present(from: nil) { [weak self] in
            let reward = rewardedAd.adReward
            #if DEBUG
            print("Rewarded ad reward earned: \(reward.amount) \(reward.type)")
            #endif
            self?.isPresenting = false
            onRewardEarned()
        }
    }
}

extension RewardedAdController: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        rewardedAd = nil
        isReady = false
        isPresenting = false
        Task { await loadAd() }
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        lastErrorMessage = error.localizedDescription
        rewardedAd = nil
        isReady = false
        isPresenting = false
        Task { await loadAd() }

        #if DEBUG
        print("Rewarded ad failed to present: \(error.localizedDescription)")
        #endif
    }
}
