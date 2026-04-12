import SwiftUI

struct FontPreviewView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Option 1: Current (rounded)
                fontCard(
                    label: "CURRENT \u{2014} SF ROUNDED",
                    title: Font.system(size: 36, weight: .black, design: .rounded),
                    subtitle: Font.system(size: 18, weight: .medium, design: .rounded)
                )

                // Option 2: SF Pro Default (just drop rounded)
                fontCard(
                    label: "OPTION A \u{2014} SF PRO DEFAULT",
                    title: Font.system(size: 36, weight: .black, design: .default),
                    subtitle: Font.system(size: 18, weight: .medium, design: .default)
                )

                // Option 3: SF Pro Condensed
                fontCard(
                    label: "OPTION B \u{2014} SF CONDENSED",
                    title: Font.system(size: 38, weight: .black, design: .default).width(.condensed),
                    subtitle: Font.system(size: 18, weight: .semibold, design: .default).width(.condensed)
                )

                // Option 4: Bebas Neue
                fontCard(
                    label: "OPTION C \u{2014} BEBAS NEUE",
                    title: Font.custom("BebasNeue-Regular", size: 42),
                    subtitle: Font.system(size: 18, weight: .medium)
                )

                // Option 5: Oswald
                fontCard(
                    label: "OPTION D \u{2014} OSWALD BOLD",
                    title: Font.custom("Oswald-Bold", size: 36),
                    subtitle: Font.system(size: 18, weight: .medium)
                )
            }
            .padding(.vertical, 24)
        }
        .background(Color.appBackground)
        .condensedNavTitle("Font Preview")
            }

    private func fontCard(label: String, title: Font, subtitle: Font) -> some View {
        VStack(spacing: 16) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundColor(.appAccentOrange)

            VStack(spacing: 8) {
                Text("RunsByIP")
                    .font(title)
                    .foregroundColor(.appTextPrimary)

                Text("Weekly pickup basketball in LA")
                    .font(subtitle)
                    .foregroundColor(.appTextSecondary)
            }

            HStack(spacing: 16) {
                Text("You're in.")
                    .font(title)
                    .foregroundColor(.appTextPrimary)
            }

            Text("HOW IT WORKS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.6)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
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
