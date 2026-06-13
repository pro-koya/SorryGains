import SwiftUI

struct OnboardingContainerView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingWelcomePage(onNext: { currentPage = 1 })
                .tag(0)

            OnboardingDisclaimerPage(onNext: { currentPage = 2 })
                .tag(1)

            OnboardingProfilePage(onComplete: onComplete)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

// MARK: - Page 1: Welcome

struct OnboardingWelcomePage: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 80))
                .foregroundStyle(Color.SG.accent)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: Spacing.sm) {
                Text("onboarding.welcome.title")
                    .font(.SG.largeTitle)
                    .multilineTextAlignment(.center)

                Text("onboarding.welcome.subtitle")
                    .font(.SG.body)
                    .foregroundStyle(Color.SG.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            SGButton("onboarding.next") {
                onNext()
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(Spacing.md)
    }
}

// MARK: - Page 2: Disclaimer

struct OnboardingDisclaimerPage: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            Image(systemName: "info.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.SG.accent)

            VStack(spacing: Spacing.sm) {
                Text("onboarding.disclaimer.title")
                    .font(.SG.title)
                    .multilineTextAlignment(.center)

                Text("onboarding.disclaimer.body")
                    .font(.SG.body)
                    .foregroundStyle(Color.SG.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.md)

            Spacer()

            SGButton("onboarding.agree") {
                onNext()
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(Spacing.md)
    }
}

// MARK: - Page 3: Profile

struct OnboardingProfilePage: View {
    @Environment(\.modelContext) private var modelContext
    let onComplete: () -> Void

    @State private var bodyWeight: Double = 65
    @State private var trainingPerWeek: Int = 3

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("onboarding.profile.title")
                    .font(.SG.title)
                    .multilineTextAlignment(.center)

                Text("onboarding.profile.subtitle")
                    .font(.SG.body)
                    .foregroundStyle(Color.SG.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.xs) {
                    Text("onboarding.profile.weight")
                        .font(.SG.headline)
                    Picker("", selection: $bodyWeight) {
                        ForEach(stride(from: 40.0, through: 150.0, by: 10.0).map { $0 }, id: \.self) { w in
                            Text("\(Int(w))kg").tag(w)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }

                VStack(spacing: Spacing.xs) {
                    Text("onboarding.profile.training")
                        .font(.SG.headline)
                    Picker("", selection: $trainingPerWeek) {
                        ForEach(0...7, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.horizontal, Spacing.md)

            Spacer()

            VStack(spacing: Spacing.sm) {
                SGButton("onboarding.start") {
                    saveProfile()
                    onComplete()
                }

                Button(String(localized: "onboarding.skip")) {
                    onComplete()
                }
                .font(.SG.body)
                .foregroundStyle(Color.SG.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(Spacing.md)
    }

    private func saveProfile() {
        let profile = UserProfile(
            bodyWeightKG: bodyWeight,
            trainingPerWeek: trainingPerWeek
        )
        modelContext.insert(profile)
        try? modelContext.save()
    }
}
