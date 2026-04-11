import AppKit
import SwiftUI

struct SettingsView: View {
    @State private var minMB: Int = UserSettings.minDisplaySizeMB

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("全局设置")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("管理偏态阈值与系统底层权限")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                ChromeCard(useMaterial: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("扫描策略", systemImage: "slider.horizontal.3")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("大文件阈值")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text("\(minMB) MB")
                                    .font(.system(.body, design: .monospaced, weight: .bold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                            
                            Stepper("", value: $minMB, in: 1...102_400, step: 5)
                                .labelsHidden()
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        Text("低于此大小的文件不会逐条列出；摘要中仍会显示数量与合计数据。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ChromeCard(useMaterial: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("私密性与权限", systemImage: "lock.open.display")
                            .font(.headline)
                        
                        Text("完全磁盘访问 (Full Disk Access)")
                            .font(.subheadline.weight(.semibold))
                        
                        Text("若需扫描系统目录或其他用户目录，请务必在「系统设置 → 隐私与安全性」中授权。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Button {
                            openFullDiskPrivacy()
                        } label: {
                            HStack {
                                Image(systemName: "hand.raised.fill")
                                Text("授权完全磁盘访问…")
                            }
                        }
                        .buttonStyle(AccentPillButton())
                    }
                }

                ChromeCard(useMaterial: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("开发者声明", systemImage: "shippingbox")
                            .font(.headline)
                        Text("当前为开发版本分发。若检测到「受损」或「无法打开」，请在终端执行 `xattr -cr` 或在安全性设置中点选「仍要打开」。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { minMB = UserSettings.minDisplaySizeMB }
        .onChange(of: minMB) { old, new in
            UserSettings.minDisplaySizeMB = new
        }
    }

    private func openFullDiskPrivacy() {
        let s = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        if let u = URL(string: s) {
            NSWorkspace.shared.open(u)
        }
    }
}
