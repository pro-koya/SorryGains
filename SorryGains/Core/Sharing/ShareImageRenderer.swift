import SwiftUI

// MARK: - Share Image Renderer

/// Renders a `ShareableResultView` into a shareable `Image` at @3x scale.
/// The output is 1080x1080px (360pt x 360pt at scale 3.0).
@MainActor
struct ShareImageRenderer {

    /// Renders the share card and returns a SwiftUI `Image`, or `nil` on failure.
    static func render(result: ApologyResult, record: DrinkRecord) -> Image? {
        let view = ShareableResultView(result: result, record: record)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0

        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }

    /// Renders the share card and returns a `UIImage` for sharing via `UIActivityViewController`.
    static func renderUIImage(result: ApologyResult, record: DrinkRecord) -> UIImage? {
        let view = ShareableResultView(result: result, record: record)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0

        return renderer.uiImage
    }

    // MARK: - Damage Report Card

    /// Renders a damage report card for SNS sharing.
    static func renderDamageReport(
        date: Date,
        records: [DrinkRecord],
        impact: DailyImpactResult,
        characterStage: Int,
        sessionDuration: String? = nil
    ) -> Image? {
        let view = DamageReportCardView(
            date: date,
            records: records,
            impact: impact,
            characterStage: characterStage,
            sessionDuration: sessionDuration
        )
        .preferredColorScheme(.dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0

        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }

    /// Renders a damage report card as UIImage for activity sharing.
    static func renderDamageReportUIImage(
        date: Date,
        records: [DrinkRecord],
        impact: DailyImpactResult,
        characterStage: Int,
        sessionDuration: String? = nil
    ) -> UIImage? {
        let view = DamageReportCardView(
            date: date,
            records: records,
            impact: impact,
            characterStage: characterStage,
            sessionDuration: sessionDuration
        )
        .preferredColorScheme(.dark)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0

        return renderer.uiImage
    }
}
