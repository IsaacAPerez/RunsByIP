import SwiftUI

// MARK: - Design System Colors

extension Color {
    // Backgrounds
    static let appBackground = Color(hex: "000000")
    static let appSurface = Color(hex: "0F0F0F")
    static let appSurfaceElevated = Color(hex: "161616")

    // Accent
    static let appAccent = Color(hex: "FFFFFF")
    static let appAccentOrange = Color(hex: "FFFFFF")

    // Text
    static let appTextPrimary = Color.white
    static let appTextSecondary = Color(hex: "666666")
    static let appTextTertiary = Color(hex: "333333")

    // Border
    static let appBorder = Color(hex: "1A1A1A")

    // Semantic
    static let appSuccess = Color(hex: "34C759")
    static let appError = Color(hex: "FF3B30")
    static let appWarning = Color(hex: "FF9500")
}

// MARK: - Design System Typography

extension Font {
    static let appTitle = Font.system(size: 28, weight: .bold)
    static let appSubtitle = Font.system(size: 20, weight: .semibold)
    static let appBody = Font.system(size: 16, weight: .regular)
    static let appCaption = Font.system(size: 13, weight: .regular)
    static let appMono = Font.system(.caption, design: .monospaced)
}

// MARK: - Design System Spacing

enum AppSpacing {
    static let space4: CGFloat = 4
    static let space8: CGFloat = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32
}

// MARK: - Design System Components

enum AppStyle {
    static let cornerRadius: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 14
    static let badgeCornerRadius: CGFloat = 12
}

// MARK: - Condensed Nav Title

struct CondensedNavTitle: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold).width(.condensed))
                        .foregroundColor(.white)
                }
            }
    }
}

extension View {
    func condensedNavTitle(_ title: String) -> some View {
        modifier(CondensedNavTitle(title: title))
    }
}

// MARK: - Card Modifier

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.space16)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: AppStyle.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppStyle.cardCornerRadius, style: .continuous)
                    .stroke(Color.appBorder, lineWidth: 1)
            )
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardModifier())
    }
}

// MARK: - Button Styles

struct AppPrimaryButtonStyle: ButtonStyle {
    var isDisabled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isDisabled ? Color.appSurfaceElevated : Color.appAccentOrange)
            .foregroundColor(isDisabled ? .white : .appBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.buttonCornerRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.appSurfaceElevated)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppStyle.buttonCornerRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
