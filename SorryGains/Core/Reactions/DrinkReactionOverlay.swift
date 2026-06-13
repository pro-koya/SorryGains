import SwiftUI

/// Full-screen overlay that shows a character reaction after recording a drink.
///
/// Appears with a pop-in animation, auto-dismisses after 3 seconds,
/// or dismisses on tap. The character stage and reaction intensity
/// drive the visual presentation.
struct DrinkReactionOverlay: View {
    let reaction: DrinkReaction
    let characterStage: Int
    let drinkNumber: Int
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var bubbleScale: CGFloat = 0
    @State private var characterOffset: CGFloat = 60

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(isVisible ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismissWithAnimation() }

            VStack(spacing: Spacing.md) {
                Spacer(minLength: Spacing.md)

                // Character
                MuscleCharacterView(
                    stage: characterStage,
                    animate: true,
                    showCaption: false
                )
                .frame(height: 160)
                .offset(y: characterOffset)

                // Speech bubble
                VStack(spacing: Spacing.sm) {
                    // Drink count badge
                    Text("\(drinkNumber)杯目")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(intensityColor.opacity(0.8))
                        .clipShape(Capsule())

                    // Reaction emoji
                    Text(reaction.emoji)
                        .font(.system(size: 36))

                    // Dialogue text
                    Text(reaction.dialogue)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.SG.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.9)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.lg)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                        .fill(Color.SG.surface)
                        .shadow(color: intensityColor.opacity(0.3), radius: 20, y: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                        .stroke(intensityColor.opacity(0.4), lineWidth: 2)
                )
                .scaleEffect(bubbleScale)
                .padding(.horizontal, Spacing.md)

                // Tap hint
                Text("タップで閉じる")
                    .font(.SG.caption)
                    .foregroundStyle(Color.SG.textSecondary.opacity(0.6))
                    .opacity(isVisible ? 1 : 0)

                Spacer(minLength: Spacing.md)
            }
        }
        .onAppear { enterAnimation() }
        .task {
            try? await Task.sleep(for: .seconds(3.5))
            dismissWithAnimation()
        }
    }

    // MARK: - Animations

    private func enterAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            isVisible = true
            characterOffset = 0
        }
        withAnimation(.spring(duration: 0.5, bounce: 0.4).delay(0.15)) {
            bubbleScale = 1.0
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.easeIn(duration: 0.2)) {
            isVisible = false
            bubbleScale = 0
            characterOffset = 60
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }

    // MARK: - Appearance

    private var intensityColor: Color {
        Color.SG.apologyColor(for: reaction.intensity.rawValue)
    }
}
