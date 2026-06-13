import SwiftUI

/// 筋トレ仙人キャラクターの表示ビュー
///
/// SVGアセットをテンプレートレンダリングで表示し、
/// 呼吸アニメーションで存在感を演出する。
struct SageCharacterView: View {
    let tintColor: Color

    @State private var breathPhase = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image("sage_character")
            .resizable()
            .renderingMode(.template)
            .interpolation(.high)
            .foregroundStyle(tintColor)
            .aspectRatio(contentMode: .fit)
            .scaleEffect(y: breathPhase ? 1.006 : 1.0)
            .shadow(color: tintColor.opacity(0.2), radius: 12, y: 4)
            .animation(breathAnimation, value: breathPhase)
            .onAppear {
                guard !reduceMotion else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    breathPhase = true
                }
            }
            .accessibilityLabel("筋トレ仙人")
    }

    private var breathAnimation: Animation? {
        breathPhase
            ? .easeInOut(duration: 3.5).repeatForever(autoreverses: true)
            : .easeOut(duration: 0.15)
    }
}
