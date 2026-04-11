import AppKit
import SwiftUI

/// 界面主题（参考同类清理工具的信息层次，非 1:1 复刻任何产品）。
enum AppTheme {
    /// 主强调色：深邃靛蓝 (Indigo)
    static let accent = Color(.sRGB, red: 0.35, green: 0.45, blue: 0.95, opacity: 1.0)
    static let accentSecondary = Color(.sRGB, red: 0.52, green: 0.39, blue: 0.98, opacity: 1.0)

    static let success = Color(.sRGB, red: 0.16, green: 0.75, blue: 0.47, opacity: 1.0)
    static let belowThreshold = Color(.sRGB, red: 0.92, green: 0.72, blue: 0.15, opacity: 1.0)
    static let warning = Color(.sRGB, red: 1.0, green: 0.64, blue: 0.1, opacity: 1.0)
    static let danger = Color(.sRGB, red: 0.98, green: 0.32, blue: 0.36, opacity: 1.0)

    /// 奢华金 (Luxury Gold) - 用于 Professional 标识
    static let luxuryGold = Color(.sRGB, red: 0.83, green: 0.69, blue: 0.22, opacity: 1.0)
    static let luxuryGoldLight = Color(.sRGB, red: 0.98, green: 0.88, blue: 0.6, opacity: 1.0)

    static let cardCorner: CGFloat = 16
    static let cardShadowRadius: CGFloat = 14
    static let cardShadowOpacity: Double = 0.08
}

// MARK: - Native Helpers

/// macOS 原生毛玻璃背景适配器
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct ChromeCard<Content: View>: View {
    var useMaterial = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    if useMaterial {
                        VisualEffectView(material: .sheet, blendingMode: .withinWindow)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCorner, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: AppTheme.cardCorner, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    }
                }
                .shadow(color: .black.opacity(AppTheme.cardShadowOpacity), radius: AppTheme.cardShadowRadius, x: 0, y: 6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cardCorner, style: .continuous)
                    .strokeBorder(Color.primary.opacity(useMaterial ? 0.1 : 0.07), lineWidth: 0.5)
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
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .kerning(0.5)
            }
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.12), tint.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 0.5)
        }
    }
}

struct MainBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            
            // 顶部微弱的光晕
            Circle()
                .fill(AppTheme.accent.opacity(0.06))
                .blur(radius: 120)
                .frame(width: 400, height: 400)
                .offset(x: -200, y: -300)

            LinearGradient(
                colors: [
                    Color.clear,
                    AppTheme.accent.opacity(0.03),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
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
