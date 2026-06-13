import Foundation
import OSLog

// MARK: - SorryGainsLogger
//
// os_log ラッパー。カテゴリ別のログ出力をサポートする。
// Forge の ForgeLogger と同パターン。

struct SorryGainsLogger {
    private let logger: Logger

    init(category: String) {
        self.logger = Logger(subsystem: "com.sorrygains.SorryGains", category: category)
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    func debug(_ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }
}
