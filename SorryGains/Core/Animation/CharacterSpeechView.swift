import SwiftUI

/// Displays manga-style flowing speech text for the muscle character.
///
/// Text scrolls from right to left like a manga panel, cycling through
/// stage-appropriate dialogue lines. A pool of 12 lines per stage is
/// rotated daily — each day shows a different set of 5.
struct CharacterSpeechView: View {
    let stage: Int

    @State private var lineIndex = 0

    private let timer = Timer.publish(
        every: 5,
        on: .main,
        in: .common
    ).autoconnect()

    private var clampedStage: Int {
        min(max(stage, 0), Self.dialogueKeys.count - 1)
    }

    /// Selects 5 lines from the pool based on the current date.
    private var dailyLines: [String] {
        let pool = Self.dialogueKeys[clampedStage]
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
        let start = day % pool.count
        return (0..<Self.displayCount).map {
            String(localized: String.LocalizationValue(pool[(start + $0) % pool.count]))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            SpeechMarqueeText(
                text: dailyLines[lineIndex % dailyLines.count],
                stage: stage,
                containerWidth: geometry.size.width
            )
            .id("\(stage)-\(lineIndex)")
        }
        .frame(height: 40)
        .clipped()
        .mask(edgeFadeMask)
        .onReceive(timer) { _ in
            lineIndex = (lineIndex + 1) % dailyLines.count
        }
        .onChange(of: stage) { _, _ in
            lineIndex = 0
        }
    }

    /// Gradient mask that fades text in/out at the edges instead of hard-clipping.
    private var edgeFadeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .white],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 40)

            Rectangle()

            LinearGradient(
                colors: [.white, .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 40)
        }
    }
}

// MARK: - Constants

extension CharacterSpeechView {
    fileprivate static let displayCount = 5
}

// MARK: - Marquee Text

/// A single line of manga-styled text that animates from right to left.
private struct SpeechMarqueeText: View {
    let text: String
    let stage: Int
    let containerWidth: CGFloat

    @State private var offset: CGFloat
    @State private var textWidth: CGFloat = 250

    init(text: String, stage: Int, containerWidth: CGFloat) {
        self.text = text
        self.stage = stage
        self.containerWidth = containerWidth
        _offset = State(initialValue: containerWidth)
    }

    private var stageColor: Color {
        Color.SG.apologyColor(for: min(5, stage + 1))
    }

    private var animationDuration: Double {
        max(3.5, Double(containerWidth + textWidth) / 110)
    }

    var body: some View {
        mangaStyledText
            .fixedSize()
            .background(measureTextWidth)
            .offset(x: offset)
            .onAppear {
                offset = containerWidth
                withAnimation(.linear(duration: animationDuration).delay(0.15)) {
                    offset = -(textWidth + 20)
                }
            }
    }

    private var mangaStyledText: some View {
        Text(text)
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .mangaOutline()
            .shadow(color: stageColor.opacity(0.5), radius: 10, y: 0)
            .rotationEffect(.degrees(-3))
    }

    private var measureTextWidth: some View {
        GeometryReader { geo in
            Color.clear.onAppear { textWidth = geo.size.width }
        }
    }
}

// MARK: - Manga Outline Modifier

private extension View {
    /// Adds a black outline effect reminiscent of manga speech text.
    func mangaOutline() -> some View {
        self
            .shadow(color: .black, radius: 0, x: 1.5, y: 1.5)
            .shadow(color: .black, radius: 0, x: -1.5, y: -1.5)
            .shadow(color: .black, radius: 0, x: 1.5, y: -1.5)
            .shadow(color: .black, radius: 0, x: -1.5, y: 1.5)
            .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 2.5)
    }
}

// MARK: - Dialogue Pool

extension CharacterSpeechView {
    /// 12 keys per stage. Each day, 5 are selected based on the date.
    /// Resolved via `String(localized:)` at access time.
    static let dialogueKeys: [[String]] = (0..<5).map { stage in
        (0..<12).map { line in "characterSpeech.stage\(stage).line\(line)" }
    }
}
