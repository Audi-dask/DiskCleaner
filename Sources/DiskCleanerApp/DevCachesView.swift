import SwiftUI

struct DevCachesView: View {
    @ObservedObject var model: DevCachesViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    title: "开发工具缓存",
                    subtitle: "清单区分可清理、谨慎与禁止：可清理项可访达与废纸篓；谨慎项仅访达；系统敏感项按钮置灰不提供操作。",
                    systemImage: "hammer.fill"
                )

                ChromeCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("体积测算")
                                .font(.headline)
                            Text("根据本机路径是否存在，递归统计各条规则占用。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.isMeasuring {
                            ProgressView()
                                .scaleEffect(0.9)
                        }
                        Button {
                            model.refreshSizes()
                        } label: {
                            Label("重新测算", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(AccentPillButton())
                        .disabled(model.isMeasuring || model.rulesDocument == nil)
                    }
                }

                if let err = model.loadError {
                    ChromeCard {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppTheme.danger)
                            Text(err)
                        }
                    }
                }

                if let success = model.lastTrashSuccessPath {
                    ChromeCard {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.success)
                            Text("已移入废纸篓：\(success)")
                                .font(.subheadline)
                        }
                    }
                }
                if let terr = model.trashError {
                    ChromeCard {
                        HStack(spacing: 10) {
                            Image(systemName: "trash.slash")
                                .foregroundStyle(AppTheme.danger)
                            Text(terr)
                                .font(.subheadline)
                        }
                    }
                }

                ChromeCard {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("使用提示")
                                .font(.subheadline.weight(.semibold))
                            Text("可清理：访达与废纸篓可用（路径须存在）。谨慎：仅访达，不提供废纸篓。禁止：访达与废纸篓均禁用（如钥匙串、Application Support 根目录等系统数据）。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ChromeCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("规则列表", systemImage: "list.number")
                            .font(.headline)
                        Table(model.scans) {
                            TableColumn("分类") { row in
                                Text(row.rule.category.displayName)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(color(for: row.rule.category))
                            }
                            .width(88)
                            TableColumn("标题") { row in
                                Text(row.rule.title)
                            }
                            .width(min: 120, ideal: 160)
                            TableColumn("大小") { row in
                                if row.exists {
                                    Text(ByteFormat.string(fromBytes: row.totalBytes))
                                        .monospacedDigit()
                                } else {
                                    Text("—")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .width(min: 90, ideal: 100)
                            TableColumn("路径") { row in
                                Text(row.resolvedURL?.path ?? row.rule.path)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            TableColumn("操作") { row in
                                HStack(spacing: 6) {
                                    Button {
                                        model.reveal(row)
                                    } label: {
                                        Image(systemName: "arrow.right.circle.fill")
                                    }
                                    .buttonStyle(IconPillButton(tint: AppTheme.accent))
                                    .disabled(finderDisabled(for: row))
                                    .opacity(row.rule.category == .doNotDelete ? 0.4 : 1)
                                    .help("在访达中显示")
                                    trashSlot(for: row)
                                }
                            }
                            .width(200)
                        }
                        .frame(minHeight: 520)
                    }
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { model.loadRules() }
        .alert("移入废纸篓？", isPresented: Binding(
            get: { model.trashTarget != nil },
            set: { if !$0 { model.cancelTrash() } }
        )) {
            Button("取消", role: .cancel) { model.cancelTrash() }
            Button("移入废纸篓", role: .destructive) { model.confirmTrash() }
        } message: {
            if let t = model.trashTarget {
                Text("\(t.rule.title)\n\(t.resolvedURL?.path ?? "")\n\n删除后可能需重新下载或重新编译。")
            }
        }
    }

    private func color(for c: DevCacheCategory) -> Color {
        switch c {
        case .safeToDelete: return AppTheme.success
        case .useWithCaution: return AppTheme.warning
        case .doNotDelete: return AppTheme.danger
        }
    }

    /// 禁止类（钥匙串等）：不提供访达入口，避免误操作系统目录。
    private func finderDisabled(for row: DevCacheRuleScan) -> Bool {
        row.resolvedURL == nil || !row.exists || row.rule.category == .doNotDelete
    }

    @ViewBuilder
    private func trashSlot(for row: DevCacheRuleScan) -> some View {
        switch row.rule.category {
        case .safeToDelete:
            Button {
                model.requestTrash(row)
            } label: {
                Label("废纸篓…", systemImage: "trash")
            }
            .buttonStyle(MiniTagButton(tint: AppTheme.danger))
            .disabled(!row.exists)
        case .useWithCaution:
            Text("—")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(minWidth: 58, alignment: .center)
                .help("谨慎项不提供一键废纸篓，请自行在访达中处理")
        case .doNotDelete:
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                Text("不可清理")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule(style: .continuous))
            .opacity(0.85)
            .help("禁止清理项：访达按钮已禁用，不提供废纸篓")
        }
    }
}
