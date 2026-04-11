import SwiftUI

private enum MainSection: String, CaseIterable, Identifiable, Hashable {
    case largeFiles
    case devCaches
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .largeFiles: return "空间分析"
        case .devCaches: return "开发缓存"
        case .settings: return "设置"
        }
    }

    var symbol: String {
        switch self {
        case .largeFiles: return "internaldrive"
        case .devCaches: return "hammer.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var sidebarSubtitle: String {
        switch self {
        case .largeFiles: return "扫描与列表"
        case .devCaches: return "清单与清理"
        case .settings: return "阈值与权限"
        }
    }
}

struct ContentView: View {
    @StateObject private var largeFileModel = LargeFileScanViewModel()
    @StateObject private var devCachesModel = DevCachesViewModel()
    @State private var selection: MainSection = .largeFiles
    @State private var showDisclaimer = !UserSettings.hasAgreedDisclaimer
    @State private var showDonationPopover = false

    var body: some View {
        ZStack {
            NavigationSplitView {
                VStack(spacing: 0) {
                    // 品牌区域
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Disk Cleaner")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Text("Professional")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppTheme.luxuryGold, AppTheme.luxuryGoldLight, AppTheme.luxuryGold],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                    List(selection: $selection) {
                        Section {
                            ForEach(MainSection.allCases) { section in
                                SidebarItem(section: section, isSelected: selection == section)
                                    .tag(section)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }
                .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
                .frame(minWidth: 220, idealWidth: 240)
            } detail: {
                ZStack {
                    MainBackground()
                    
                    Group {
                        switch selection {
                        case .largeFiles:
                            LargeFileScanView(model: largeFileModel)
                        case .devCaches:
                            DevCachesView(model: devCachesModel)
                        case .settings:
                            SettingsView()
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom).combined(with: .scale(scale: 0.98))),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 10) {
                        // 赞赏按钮
                        Button {
                            showDonationPopover.toggle()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "cup.and.saucer.fill")
                                Text("赞赏一下")
                            }
                            .font(.system(size: 11, weight: .heavy))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                LinearGradient(
                                    colors: [Color.orange, Color.yellow],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .foregroundStyle(.black)
                            .shadow(color: Color.orange.opacity(0.3), radius: 4)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showDonationPopover, arrowEdge: .bottom) {
                            VStack(spacing: 16) {
                                Text("☕️ 赞赏开发者")
                                    .font(.system(.headline, design: .rounded))
                                
                                Text("如果您觉得这款软件对您有所帮助，\n可以请开发团队喝杯咖啡，支持我们后续的开发与维护！")
                                    .font(.system(size: 11))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                
                                if let nsImage = NSImage(named: "DonationQR") ?? 
                                   (Bundle.module.path(forResource: "DonationQR", ofType: "jpg").flatMap { NSImage(contentsOfFile: $0) }) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 220, height: 220)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.white.opacity(0.1), lineWidth: 0.5)
                                        )
                                } else {
                                    VStack {
                                        Image(systemName: "qrcode")
                                            .font(.system(size: 80))
                                        Text("未找到赞赏码资源")
                                            .font(.caption2)
                                    }
                                    .frame(width: 220, height: 220)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                
                                Text("感谢您的慷慨支持！")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .padding(20)
                            .frame(width: 280)
                        }

                        // 反馈按钮
                        Button {
                            if let url = URL(string: "https://dbak.top/weichat_20260411-kyfh.png") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                Text("反馈加群")
                            }
                            .font(.system(size: 11, weight: .heavy))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.9, blue: 0.5), Color(red: 0.0, green: 0.7, blue: 0.9)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .foregroundStyle(.black)
                            .shadow(color: Color.green.opacity(0.3), radius: 4)
                        }
                        .buttonStyle(.plain)
                        .help("遇到问题？欢迎加入讨论群反馈")
                    }
                }
            }
            .disabled(showDisclaimer)

            if showDisclaimer {
                ZStack {
                    // 全屏模糊背景
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 28) {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(
                                    LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom)
                                )
                            Text("免责声明与风险告知")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                        }
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                DisclaimerSection(title: "1. 技术讨论与非商业化", content: "本软件仅限个人技术交流与磁盘空间分析之用，并非商业化产品，开发者不提供任何形式的商业保障或技术支持。")
                                DisclaimerSection(title: "2. 操作建议与风险", content: "本软件核心功能为展示磁盘占用。由于磁盘清理属于高风险操作，在您执行物理删除前，请务必保持极度谨慎。")
                                DisclaimerSection(title: "3. 借力 AI 确认", content: "强烈建议您使用软件内置的“复制路径”功能，将存疑的路径交由 AI（如 ChatGPT/Claude）进行识别确认，确保该文件非系统或业务必选。")
                                DisclaimerSection(title: "4. 责任范围", content: "因主观失误、不当操作导致的任何数据丢失、系统损坏或软硬件故障，开发者及本软件概不承担责任。请自愿承担风险。")
                            }
                            .padding(.vertical, 8)
                        }
                        .frame(maxHeight: 320)
                        
                        Button {
                            UserSettings.hasAgreedDisclaimer = true
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showDisclaimer = false
                            }
                        } label: {
                            Text("我已阅读并知晓相关风险")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(32)
                    .frame(width: 520)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(.windowBackgroundColor).opacity(0.8))
                            .background(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.2), radius: 40)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(.white.opacity(0.1), lineWidth: 0.5)
                    )
                }
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
    }
}

private struct DisclaimerSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
            Text(content)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }
}

private struct SidebarItem: View {
    let section: MainSection
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: section.symbol)
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? AppTheme.accent : .secondary)
                .symbolEffect(.bounce, value: isSelected)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                Text(section.sidebarSubtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}
