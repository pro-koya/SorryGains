import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var authService
    @Environment(TrainingDataService.self) private var trainingDataService
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Query private var profiles: [UserProfile]

    @AppStorage("prefersReducedMotion") private var prefersReducedMotion = false

    private var profile: UserProfile {
        profiles.first ?? UserProfile()
    }

    @State private var bodyWeight: Double = 65
    @State private var trainingPerWeek: Int = 3
    @State private var showDisclaimer = false
    @State private var showDeleteAccountConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                liftlyLinkSection
                bundleSubscriptionSection
                profileSection
                displaySection
                languageSection
                aboutSection
                relatedAppSection

                if !subscriptionManager.isBundleActive {
                    Section {
                        AdBannerSlot(placement: .settingsBottom)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle(String(localized: "settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                bodyWeight = profile.bodyWeightKG
                trainingPerWeek = profile.trainingPerWeek
            }
            .sheet(isPresented: $showDisclaimer) {
                DisclaimerSheet()
            }
            .confirmationDialog(
                String(localized: "settings.delete_account_confirm_title"),
                isPresented: $showDeleteAccountConfirmation,
                titleVisibility: .visible
            ) {
                Button(String(localized: "settings.delete_account"), role: .destructive) {
                    Task { await authService.deleteAccount() }
                }
                Button(String(localized: "common.cancel"), role: .cancel) {}
            } message: {
                Text("settings.delete_account_confirm_message")
            }
        }
    }

    // MARK: - Liftly Link

    private var liftlyLinkSection: some View {
        Section(
            header: Text("settings.liftly_link"),
            footer: Text("settings.liftly_link_footer")
        ) {
            if authService.isSignedIn {
                // 連携済み: アカウント情報
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(Color.SG.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.liftly_linked")
                            .font(.SG.headline)
                        if let email = authService.currentUserEmail {
                            Text(email)
                                .font(.SG.caption)
                                .foregroundStyle(Color.SG.textSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.SG.apologyMild)
                }

                // 今日のトレーニング情報
                if let snapshot = trainingDataService.todaySnapshot, snapshot.hasTraining {
                    HStack {
                        Image(systemName: "dumbbell.fill")
                            .foregroundStyle(Color.SG.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.today_training")
                            Text(snapshot.bodyPartsDisplayText)
                                .font(.SG.caption)
                                .foregroundStyle(Color.SG.textSecondary)
                        }
                        Spacer()
                        if let intensity = snapshot.intensityLevel {
                            Text(intensity.displayName)
                                .font(.SG.caption)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xxs)
                                .background(Color.SG.accent.opacity(0.18))
                                .foregroundStyle(Color.SG.accent)
                                .clipShape(Capsule())
                        }
                    }
                }

                // ログアウト
                Button(role: .destructive) {
                    Task { await authService.signOut() }
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.minus")
                        Text("settings.sign_out")
                    }
                }
                .disabled(authService.isDeletingAccount)

                Button(role: .destructive) {
                    showDeleteAccountConfirmation = true
                } label: {
                    HStack {
                        if authService.isDeletingAccount {
                            ProgressView()
                        } else {
                            Image(systemName: "trash")
                        }
                        Text("settings.delete_account")
                    }
                }
                .disabled(authService.isDeletingAccount)
            } else {
                // 未連携
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("settings.liftly_link_description")
                        .font(.SG.caption)
                        .foregroundStyle(Color.SG.textSecondary)

                    authButton(
                        title: "settings.sign_in_apple",
                        systemImage: "apple.logo",
                        provider: .apple,
                        action: { await authService.signInWithApple() }
                    )

                    authButton(
                        title: "settings.sign_in_google",
                        systemImage: "g.circle.fill",
                        provider: .google,
                        action: { await authService.signInWithGoogle() }
                    )
                }
            }

            if let error = authService.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.SG.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func authButton(
        title: LocalizedStringKey,
        systemImage: String,
        provider: AuthProviderKind,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: Spacing.sm) {
                if authService.activeSignInProvider == provider {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                        .frame(width: 22)
                }
                Text(title)
                    .font(.SG.body)
                    .fontWeight(.semibold)
                Spacer()
            }
            .foregroundStyle(Color.SG.textPrimary)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(Color.SG.surface.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                    .stroke(Color.SG.textSecondary.opacity(0.28), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
        .disabled(authService.isLoading)
        .opacity(authService.isLoading && authService.activeSignInProvider != provider ? 0.55 : 1)
    }

    // MARK: - Bundle Subscription

    private var bundleSubscriptionSection: some View {
        Section(
            header: Text("bundle.section.title"),
            footer: Text(
                subscriptionManager.isBundleActive
                    ? "bundle.section.footer.active"
                    : "bundle.section.footer.inactive"
            )
        ) {
            if subscriptionManager.isBundleActive {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.SG.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("bundle.status.active")
                            .font(.SG.headline)
                        Text("bundle.status.active.description")
                            .font(.SG.caption)
                            .foregroundStyle(Color.SG.textSecondary)
                    }
                    Spacer()
                }
                .accessibilityIdentifier("bundleStatusActive")
            } else {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("bundle.description")
                        .font(.SG.caption)
                        .foregroundStyle(Color.SG.textSecondary)

                    VStack(spacing: Spacing.xs) {
                        bundlePlanRow(
                            title: "bundle.plan.monthly",
                            price: subscriptionManager.bundleMonthlyDisplayPrice.isEmpty
                                ? "¥250/月"
                                : subscriptionManager.bundleMonthlyDisplayPrice,
                            productId: "com.muscle360.bundle.pro.monthly"
                        )
                        .accessibilityIdentifier("bundlePlanMonthlyRow")
                        bundlePlanRow(
                            title: "bundle.plan.yearly",
                            price: subscriptionManager.bundleYearlyDisplayPrice.isEmpty
                                ? "¥2,500/年"
                                : subscriptionManager.bundleYearlyDisplayPrice,
                            badge: "17% OFF",
                            productId: "com.muscle360.bundle.pro.yearly"
                        )
                        .accessibilityIdentifier("bundlePlanYearlyRow")
                    }

                    // 購入エラー表示
                    if let errorMessage = subscriptionManager.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.SG.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    // 復元ボタン
                    Button {
                        Task { await subscriptionManager.restore() }
                    } label: {
                        Text("bundle.plan.restore")
                            .font(.SG.caption)
                            .foregroundStyle(Color.SG.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(subscriptionManager.isPurchasing)
                    .accessibilityIdentifier("bundleRestoreButton")
                }
            }
        }
    }

    @State private var isBundlePurchasing: Bool = false

    private func bundlePlanRow(
        title: LocalizedStringKey,
        price: String,
        badge: String? = nil,
        productId: String
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.SG.body)
                        .foregroundStyle(Color.SG.textPrimary)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }
                Text(price)
                    .font(.SG.caption)
                    .foregroundStyle(Color.SG.textSecondary)
            }
            Spacer()
            if subscriptionManager.isLoading || subscriptionManager.isPurchasing || isBundlePurchasing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button(String(localized: "bundle.plan.subscribe")) {
                    Task {
                        isBundlePurchasing = true
                        defer { isBundlePurchasing = false }
                        if productId == "com.muscle360.bundle.pro.monthly" {
                            await subscriptionManager.purchaseBundleMonthly()
                        } else {
                            await subscriptionManager.purchaseBundleYearly()
                        }
                    }
                }
                .font(.SG.caption.bold())
                .foregroundStyle(Color.SG.accent)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section(String(localized: "settings.profile")) {
            HStack {
                Text("settings.weight")
                Spacer()
                Picker("", selection: $bodyWeight) {
                    ForEach(stride(from: 40.0, through: 150.0, by: 10.0).map { $0 }, id: \.self) { weight in
                        Text("\(Int(weight))kg").tag(weight)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: bodyWeight) { _, newValue in
                    updateProfile { $0.bodyWeightKG = newValue }
                }
            }

            HStack {
                Text("settings.training_frequency")
                Spacer()
                Picker("", selection: $trainingPerWeek) {
                    ForEach(0...7, id: \.self) { count in
                        Text("settings.times_per_week.\(count)").tag(count)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: trainingPerWeek) { _, newValue in
                    updateProfile { $0.trainingPerWeek = newValue }
                }
            }
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        Section(String(localized: "settings.display")) {
            Toggle(
                String(localized: "settings.reduce_motion"),
                isOn: $prefersReducedMotion
            )

            if let accessibilityURL = URL(string: UIApplication.openSettingsURLString) {
                Button {
                    UIApplication.shared.open(accessibilityURL)
                } label: {
                    HStack {
                        Text("settings.system_accessibility")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.SG.footnote)
                            .foregroundStyle(Color.SG.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        Section(
            header: Text("settings.language"),
            footer: Text("settings.language_footer")
        ) {
            HStack {
                Text("settings.current_language")
                Spacer()
                Text(Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "ja") ?? "")
                    .foregroundStyle(Color.SG.textSecondary)
            }
        }
    }

    // MARK: - Related App

    private var relatedAppSection: some View {
        Section(String(localized: "settings.related_app")) {
            Link(destination: URL(string: "https://apps.apple.com/app/id6757798075")!) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(Color.SG.accent)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.download_liftly")
                            .font(.SG.body)
                            .foregroundStyle(Color.SG.textPrimary)
                        Text("settings.download_liftly_description")
                            .font(.SG.caption)
                            .foregroundStyle(Color.SG.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .font(.SG.footnote)
                        .foregroundStyle(Color.SG.textSecondary)
                }
            }

            Link(destination: URL(string: "https://apps.apple.com/app/id6766134975")!) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "figure.cross.training")
                        .foregroundStyle(Color.SG.accent)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("settings.download_forge")
                            .font(.SG.body)
                            .foregroundStyle(Color.SG.textPrimary)
                        Text("settings.download_forge_description")
                            .font(.SG.caption)
                            .foregroundStyle(Color.SG.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .font(.SG.footnote)
                        .foregroundStyle(Color.SG.textSecondary)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section(String(localized: "settings.about")) {
            Button(String(localized: "settings.disclaimer")) {
                showDisclaimer = true
            }

            HStack {
                Text("settings.version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    .foregroundStyle(Color.SG.textSecondary)
            }
        }
    }

    private func updateProfile(_ update: (UserProfile) -> Void) {
        if let existing = profiles.first {
            update(existing)
        } else {
            let newProfile = UserProfile()
            update(newProfile)
            modelContext.insert(newProfile)
        }
        try? modelContext.save()
    }
}

// MARK: - Disclaimer Sheet

struct DisclaimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("disclaimer.body")
                        .font(.SG.body)
                        .foregroundStyle(Color.SG.textPrimary)
                }
                .padding(Spacing.md)
            }
            .navigationTitle(String(localized: "disclaimer.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
