#if DEBUG
import Foundation

/// SorryGains の UI テスト専用モード。
///
/// **目的**: Onboarding / 認証ゲートをバイパスして、UI テストが MainTabView 直結で
/// 動作するようにする。Forge の `ScreenshotMode` と同等の思想で実装。
///
/// **有効化**: launch arguments に `-uiTestMode 1` を渡す。
///
/// **本番への影響**: `#if DEBUG` で全体をガードしているため Release ビルドには含まれない。
/// 万一 DEBUG ビルドで launch argument が渡されない場合は無効として扱われる。
enum UITestMode {
    /// CLI から渡された launch argument を確認して、UI テストモードが有効かを判定する。
    static var isActive: Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-uiTestMode"), idx + 1 < args.count else {
            return false
        }
        return args[idx + 1] == "1"
    }
}
#endif
