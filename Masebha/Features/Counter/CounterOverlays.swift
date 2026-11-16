import SwiftUI

/// Power mode: a near-black screen to save battery (black pixels are off on OLED iPhones).
/// Taps go through it, so counting continues. Only the ✕ closes it.
struct PowerModeOverlay: View {
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.93)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityIdentifier("counter.powerOverlay")
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .padding(.top, 8)
            .accessibilityLabel(tr("common.close"))
            .accessibilityIdentifier("counter.powerClose")
        }
    }
}

/// First visit only: "Tap anywhere in the screen to count". The tap that closes it does not count.
struct CoachMarkOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 60, weight: .light))
                Text(tr("counter.coach"))
                    .appFont(21, .medium)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(36)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("counter.coachMark")
    }
}
