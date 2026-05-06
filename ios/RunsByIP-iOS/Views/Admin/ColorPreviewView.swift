import SwiftUI

struct ColorPreviewView: View {
    private let options: [(label: String, hex: String, description: String)] = [
        ("CURRENT", "FF8C42", "Soft orange"),
        ("A", "FF5722", "Deep orange — aggressive, Nike-ish"),
        ("B", "FF6B00", "Pure orange — bold, Gatorade energy"),
        ("C", "E8451E", "Burnt red-orange — athletic, intense"),
        ("D", "F5420A", "Flame — high contrast, scoreboard"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                ForEach(options, id: \.hex) { option in
                    let color = Color(hex: option.hex)

                    VStack(spacing: 16) {
                        HStack {
                            Text(option.label)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .tracking(1.4)
                                .foregroundColor(color)

                            Spacer()

                            Text("#\(option.hex)")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.appTextSecondary)
                        }

                        Text(option.description)
                            .font(.system(size: 13))
                            .foregroundColor(.appTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Title preview
                        Text("Next run, Isaac.")
                            .font(.system(size: 30, weight: .black).width(.condensed))
                            .foregroundColor(.appTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Button preview
                        HStack(spacing: 12) {
                            Text("RSVP — PRICE")
                                .font(.system(size: 15, weight: .black))
                                .tracking(1.0)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(color)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: AppStyle.buttonCornerRadius, style: .continuous))
                        }

                        // Accent elements
                        HStack(spacing: 16) {
                            // Icon
                            Image(systemName: "basketball.fill")
                                .font(.title2)
                                .foregroundColor(color)

                            // Badge
                            Text("LIVE NOW")
                                .font(.system(size: 11, weight: .black).width(.condensed))
                                .tracking(1.0)
                                .foregroundColor(color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(color.opacity(0.15), in: Capsule())

                            Spacer()

                            // Send icon
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(color)
                        }
                    }
                    .padding(20)
                    .background(Color.appSurface)
                    .cornerRadius(AppStyle.cardCornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppStyle.cardCornerRadius)
                            .stroke(Color.appBorder, lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 24)
        }
        .background(Color.appBackground)
        .condensedNavTitle("Color Preview")
            }
}
