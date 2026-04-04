import AppKit
import SwiftUI

/// 界面主题（参考同类清理工具的信息层次，非 1:1 复刻任何产品）。
enum AppTheme {
    /// 主强调色：偏紫的靛蓝
    static let accent = Color(red: 0.38, green: 0.41, blue: 0.92)
    static let accentSecondary = Color(red: 0.55, green: 0.48, blue: 0.98)

    static let success = Color(red: 0.2, green: 0.72, blue: 0.45)
    /// 大文件页「低于阈值合计」指标块用色（黄）
    static let belowThreshold = Color(red: 0.88, green: 0.72, blue: 0.12)
    static let warning = Color(red: 0.98, green: 0.62, blue: 0.2)
    static let danger = Color(red: 0.95, green: 0.32, blue: 0.35)

    static let cardCorner: CGFloat = 14
    static let cardShadowRadius: CGFloat = 12
}

struct ChromeCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.cardCorner, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.07), radius: AppTheme.cardShadowRadius, x: 0, y: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardCorner, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.85), AppTheme.accentSecondary.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 10, y: 4)
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        }
    }
}

struct MainBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                AppTheme.accent.opacity(0.04),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Modern Button Styles

struct AccentPillButton: ButtonStyle {
    @State private var isHovering = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 12 : 18)
            .padding(.vertical, compact ? 5 : 8)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: AppTheme.accent.opacity(isHovering ? 0.45 : 0.2), radius: isHovering ? 8 : 4, y: 2)
            }
            .scaleEffect(configuration.isPressed ? 0.95 : (isHovering ? 1.02 : 1.0))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.2), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

struct GhostPillButton: ButtonStyle {
    @State private var isHovering = false
    var tint: Color = AppTheme.accent
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .caption.weight(.medium) : .subheadline.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 4 : 7)
            .background {
                Capsule(style: .continuous)
                    .fill(tint.opacity(isHovering ? 0.12 : 0.06))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(isHovering ? 0.35 : 0.18), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.2), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

struct IconPillButton: ButtonStyle {
    @State private var isHovering = false
    var tint: Color = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundStyle(isHovering ? tint : .secondary)
            .padding(5)
            .background {
                Circle()
                    .fill(tint.opacity(isHovering ? 0.12 : 0.0))
            }
            .scaleEffect(configuration.isPressed ? 0.88 : (isHovering ? 1.08 : 1.0))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.2), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

struct MiniTagButton: ButtonStyle {
    @State private var isHovering = false
    var tint: Color = AppTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isHovering ? .white : tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule(style: .continuous)
                    .fill(isHovering ? tint : tint.opacity(0.1))
            }
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.2), value: isHovering)
            .onHover { isHovering = $0 }
    }
}
