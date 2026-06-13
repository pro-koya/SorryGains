import SwiftUI

/// Displays one of 5 muscle character illustrations with theatrical stage transitions.
///
/// Each stage is a pre-rendered line-art illustration displayed as a template image,
/// colored by the apology level. Stage transitions use a stroke-reveal animation
/// that draws the new character into view.
///
/// - Stage 0: ゴリマッチョ (bulky muscular) — double bicep flex, happy
/// - Stage 1: 細マッチョ (lean muscular) — hands on hips, stern
/// - Stage 2: 普通 (average) — standing straight, neutral
/// - Stage 3: ぷよぷよ (pudgy) — hands behind head, angry
/// - Stage 4: ガリガリ (skinny) — slight hunch, sad
struct MuscleCharacterView: View {
    let stage: Int
    let animate: Bool
    let showCaption: Bool

    @State private var displayedStage: Int
    @State private var revealProgress: CGFloat = 1.0
    @State private var dismissScale: CGFloat = 1.0
    @State private var dismissOpacity: Double = 1.0
    @State private var entryScale: CGFloat = 1.0
    @State private var breathPhase = false
    @State private var isTransitioning = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(stage: Int = 0, animate: Bool = true, showCaption: Bool = true) {
        let clamped = min(max(stage, 0), 4)
        self.stage = clamped
        self.animate = animate
        self.showCaption = showCaption
        self._displayedStage = State(initialValue: clamped)
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            characterContent
                .accessibilityLabel(accessibilityText)

            if showCaption {
                Text(stageCaption)
                    .font(.SG.body)
                    .foregroundStyle(Color.SG.textSecondary)
            }
        }
        .onChange(of: stage) { _, newValue in
            let target = min(max(newValue, 0), 4)
            guard target != displayedStage else { return }
            if animate && !reduceMotion {
                performTransition(to: target)
            } else {
                displayedStage = target
            }
        }
        .onAppear {
            displayedStage = min(max(stage, 0), 4)
            guard animate, !reduceMotion else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                breathPhase = true
            }
        }
    }

    // MARK: - Character Rendering

    private var characterContent: some View {
        Image("character_stage_\(displayedStage)")
            .resizable()
            .renderingMode(.template)
            .interpolation(.high)
            .foregroundStyle(characterColor)
            .aspectRatio(contentMode: .fit)
            .scaleEffect(dismissScale * entryScale)
            .scaleEffect(y: breathPhase ? 1.008 : 1.0)
            .opacity(dismissOpacity)
            .mask { revealMask }
            .shadow(color: characterColor.opacity(0.25), radius: 12, y: 4)
            .animation(breathAnimation, value: breathPhase)
    }

    @ViewBuilder
    private var revealMask: some View {
        if revealProgress >= 0.999 {
            Rectangle()
        } else {
            CharacterRevealStroke()
                .trim(from: 0, to: revealProgress)
                .stroke(style: StrokeStyle(
                    lineWidth: 350,
                    lineCap: .round,
                    lineJoin: .round
                ))
        }
    }

    private var breathAnimation: Animation? {
        breathPhase
            ? .easeInOut(duration: 3.0).repeatForever(autoreverses: true)
            : .easeOut(duration: 0.15)
    }

    // MARK: - Stage Transition

    private func performTransition(to newStage: Int) {
        guard !isTransitioning else { return }
        isTransitioning = true
        let isWorsening = newStage > displayedStage

        // Pause breathing
        breathPhase = false

        // Phase 1: Dismiss current character (shrink + fade)
        withAnimation(.easeIn(duration: 0.2)) {
            dismissScale = isWorsening ? 0.55 : 0.7
            dismissOpacity = 0
        }

        // Phase 2: Switch to new character, reveal with drawing animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            displayedStage = newStage
            revealProgress = 0
            dismissScale = 1.0
            dismissOpacity = 1.0
            entryScale = 0.85

            // Stroke reveal: character "drawn" into view
            withAnimation(.easeInOut(duration: 0.55)) {
                revealProgress = 1.0
            }

            // Bounce landing
            withAnimation(.spring(duration: 0.5, bounce: 0.3).delay(0.2)) {
                entryScale = 1.0
            }
        }

        // Phase 3: Resume idle state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            isTransitioning = false
            let currentTarget = min(max(stage, 0), 4)
            if currentTarget != displayedStage {
                performTransition(to: currentTarget)
            } else {
                breathPhase = true
            }
        }
    }

    // MARK: - Appearance

    private var characterColor: Color {
        Color.SG.apologyColor(for: min(5, displayedStage + 1))
    }

    private var stageCaption: LocalizedStringKey {
        switch displayedStage {
        case 0: "character.stage.normal"
        case 1: "character.stage.shrinking"
        case 2: "character.stage.sad"
        case 3: "character.stage.exhausted"
        default: "character.stage.surrendered"
        }
    }

    private var accessibilityText: String {
        let descriptions = [
            String(localized: "character.body.gori"),
            String(localized: "character.body.lean"),
            String(localized: "character.body.normal"),
            String(localized: "character.body.flabby"),
            String(localized: "character.body.skinny"),
        ]
        let idx = min(displayedStage, descriptions.count - 1)
        return String(format: String(localized: "character.accessibility.format"), descriptions[idx])
    }
}

// MARK: - Reveal Stroke Path

/// A path that winds through the character view area in a body-tracing pattern.
/// Stroked with a very thick lineWidth (350pt) and animated via `.trim(from:to:)`,
/// it progressively reveals the character image underneath — creating a
/// "being drawn" effect as the line sweeps through head → arms → torso → legs.
private struct CharacterRevealStroke: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        var path = Path()

        // Head (top center)
        path.move(to: CGPoint(x: cx, y: rect.height * 0.02))
        path.addLine(to: CGPoint(x: cx, y: rect.height * 0.20))

        // Sweep left arm area
        path.addLine(to: CGPoint(x: rect.width * 0.04, y: rect.height * 0.26))

        // Back to center chest
        path.addLine(to: CGPoint(x: cx, y: rect.height * 0.28))

        // Sweep right arm area
        path.addLine(to: CGPoint(x: rect.width * 0.96, y: rect.height * 0.26))

        // Back to center, down through torso
        path.addLine(to: CGPoint(x: cx, y: rect.height * 0.36))
        path.addLine(to: CGPoint(x: cx, y: rect.height * 0.58))

        // Left leg
        path.addLine(to: CGPoint(x: rect.width * 0.28, y: rect.height * 0.98))

        // Back to hip area
        path.addLine(to: CGPoint(x: cx, y: rect.height * 0.62))

        // Right leg
        path.addLine(to: CGPoint(x: rect.width * 0.72, y: rect.height * 0.98))

        return path
    }
}
