import SwiftUI

/// 漫画風の吹き出し形状
///
/// 角丸の矩形に上向きの三角しっぽが付く。
/// キャラクターの下に配置して「喋っている」印象を与える。
struct SpeechBubbleShape: Shape {
    /// しっぽの水平位置 (0.0 = 左端, 1.0 = 右端)
    let tailPosition: CGFloat
    /// しっぽの幅
    let tailWidth: CGFloat
    /// しっぽの高さ
    let tailHeight: CGFloat
    /// 角丸
    let cornerRadius: CGFloat

    init(
        tailPosition: CGFloat = 0.35,
        tailWidth: CGFloat = 24,
        tailHeight: CGFloat = 16,
        cornerRadius: CGFloat = 20
    ) {
        self.tailPosition = tailPosition
        self.tailWidth = tailWidth
        self.tailHeight = tailHeight
        self.cornerRadius = cornerRadius
    }

    func path(in rect: CGRect) -> Path {
        let bodyRect = CGRect(
            x: rect.minX,
            y: rect.minY + tailHeight,
            width: rect.width,
            height: rect.height - tailHeight
        )

        var path = Path()

        // 角丸矩形のボディ
        path.addRoundedRect(
            in: bodyRect,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        // 上向きの三角しっぽ
        let tailCenterX = bodyRect.minX + bodyRect.width * tailPosition
        let tailLeft = tailCenterX - tailWidth / 2
        let tailRight = tailCenterX + tailWidth / 2

        var tailPath = Path()
        tailPath.move(to: CGPoint(x: tailLeft, y: bodyRect.minY))
        tailPath.addLine(to: CGPoint(x: tailCenterX, y: rect.minY))
        tailPath.addLine(to: CGPoint(x: tailRight, y: bodyRect.minY))
        tailPath.closeSubpath()

        path.addPath(tailPath)

        return path
    }
}
