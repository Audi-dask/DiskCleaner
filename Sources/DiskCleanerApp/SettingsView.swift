import AppKit
import SwiftUI

struct SettingsView: View {
    @State private var minMB: Int = UserSettings.minDisplaySizeMB

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    title: "设置",
                    subtitle: "调整列表阈值、磁盘权限说明与分发提示。",
                    systemImage: "gearshape.fill"
                )

                ChromeCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("大文件列表", systemImage: "slider.horizontal.3")
                            .font(.headline)
                        Stepper(value: $minMB, in: 1...102_400, step: 1) {
                            Text("列表最小展示体积：\(minMB) MB")
                                .font(.subheadline.weight(.medium))
                        }
                        .onChange(of: minMB) {
                            UserSettings.minDisplaySizeMB = minMB
                        }
                        Text("低于此大小的文件不会逐条列出；摘要中仍会显示数量与合计大小。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ChromeCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("完全磁盘访问", systemImage: "lock.open.display")
                            .font(.headline)
                        Text(
                            "若需扫描系统目录或其他用户目录，请在「系统设置 → 隐私与安全性 → 完全磁盘访问权限」中勾选本应用。"
                        )
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        Button {
                            openFullDiskPrivacy()
                        } label: {
                            Label("打开系统设置…", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(AccentPillButton())
                    }
                }

                ChromeCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("分发说明", systemImage: "shippingbox")
                            .font(.headline)
                        Text(
                            "未签名分发时，用户可能需使用 xattr 解除隔离；长期分发建议 Developer ID 签名与公证。Mac App Store 沙盒会限制全盘访问能力。"
                        )
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
    }

    private func openFullDiskPrivacy() {
        let s = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        if let u = URL(string: s) {
            NSWorkspace.shared.open(u)
        }
    }
}
