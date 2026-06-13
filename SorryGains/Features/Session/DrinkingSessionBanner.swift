import SwiftUI

/// Compact banner shown at the top of HomeView during an active drinking session.
///
/// Displays a live timer, drink count, and a stop button.
/// Pulses gently to indicate the session is active.
struct DrinkingSessionBanner: View {
    let session: DrinkingSession
    let drinkCount: Int
    let onStop: () -> Void

    @State private var timerTick = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Pulsing record indicator
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(timerTick % 2 == 0 ? 1.0 : 0.4)
                .animation(.easeInOut(duration: 0.5), value: timerTick)

            // Timer
            Text(session.durationTimerText)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.SG.textPrimary)
                .contentTransition(.numericText())

            // Divider
            Text("|")
                .foregroundStyle(Color.SG.textSecondary.opacity(0.4))

            // Drink count
            HStack(spacing: Spacing.xxs) {
                Image(systemName: "mug.fill")
                    .font(.caption)
                Text("\(drinkCount)杯")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color.SG.accent)

            Spacer()

            // Stop button
            Button(action: onStop) {
                Text("終了")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                .fill(Color.SG.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .onReceive(timer) { _ in
            timerTick += 1
        }
    }
}
