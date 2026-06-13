import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        #if DEBUG
        if UITestMode.isActive {
            MainTabView()
        } else if hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingContainerView(onComplete: {
                hasCompletedOnboarding = true
            })
        }
        #else
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingContainerView(onComplete: {
                hasCompletedOnboarding = true
            })
        }
        #endif
    }
}
