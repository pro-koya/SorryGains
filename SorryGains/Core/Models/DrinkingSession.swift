import Foundation
import SwiftData

/// Represents an active or completed drinking session ("飲み会モード").
///
/// Tracks start/end times and associates with drink records made during the session.
/// Session duration and drink count drive the end-of-session damage report.
@Model
final class DrinkingSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    // MARK: - Computed

    var isActive: Bool {
        endedAt == nil
    }

    var duration: TimeInterval {
        let end = endedAt ?? .now
        return end.timeIntervalSince(startedAt)
    }

    var durationText: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return String(format: String(localized: "duration.hoursMinutes"), hours, minutes)
        }
        return String(format: String(localized: "duration.minutes"), minutes)
    }

    var durationTimerText: String {
        let total = Int(duration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
