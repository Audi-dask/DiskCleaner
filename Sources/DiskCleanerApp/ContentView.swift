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
    /// 使用非可选 + 显式 `tag`，避免 macOS 上 `List(items, selection:)` 与侧栏选中不同步。
    @State private var selection: MainSection = .largeFiles

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(MainSection.allCases) { section in
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: section.symbol)
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 28, alignment: .center)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.title)
                                .font(.body.weight(.semibold))
                            Text(section.sidebarSubtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .tag(section)
                }
            }
            .navigationTitle("Disk Cleaner")
            .listStyle(.sidebar)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
