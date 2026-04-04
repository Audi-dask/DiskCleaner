import AppKit
import Charts
import SwiftUI

struct LargeFileScanView: View {
    @ObservedObject var model: LargeFileScanViewModel
    @State private var filterGroupKey: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    title: "空间透视分析",
                    subtitle: "按阈值列出占用空间的大文件；更小的文件自动合并为数量与总大小，避免列表爆炸。",
                    systemImage: "magnifyingglass"
                )

                ScanControlCard(model: model)

                if let err = model.errorMessage {
                    ChromeCard {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.warning)
                            Text(err)
                                .foregroundStyle(.primary)
                                .font(.callout)
                        }
                    }
                }

                if let r = model.scanResult {
                    HStack(alignment: .top, spacing: 12) {
                        MetricTile(
                            title: "列表中大文件",
                            value: "\(r.largeFiles.count)",
                            systemImage: "doc.text.fill",
                            tint: AppTheme.success
                        )
                        MetricTile(
                            title: "已统计文件",
                            value: "\(r.scannedFileCount)",
                            systemImage: "number.circle.fill",
                            tint: AppTheme.accentSecondary
                        )
                        MetricTile(
                            title: "低于阈值合计",
                            value: ByteFormat.string(fromBytes: r.smallFiles.totalBytes),
                            systemImage: "square.stack.3d.up.fill",
                            tint: AppTheme.belowThreshold
                        )
                    }

                    summarySection(r, model: model)

                    ChromeCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("大文件列表", systemImage: "list.bullet.rectangle")
                                .font(.headline)
                            Text("≥ \(ByteFormat.string(fromBytes: r.thresholdBytes)) 的文件逐条展示。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            // 列顺序：序号 → 大小 → 说明 → 路径（访达 + 复制 + 文本）
                            Table(Array(r.largeFiles.enumerated().map { NumberedLargeFile(ordinal: $0.offset + 1, entry: $0.element) })) {
                                TableColumn("序号") { row in
                                    Text("\(row.ordinal)")
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .width(min: 36, ideal: 44, max: 52)
                                TableColumn("大小") { row in
                                    Text(ByteFormat.string(fromBytes: row.entry.size))
                                        .monospacedDigit()
                                }
                                .width(min: 64, ideal: 72, max: 88)
                                TableColumn("说明") { row in
                                    Text(row.entry.friendlyPathLabel)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                        .foregroundStyle(row.entry.friendlyPathLabel == "—" ? .tertiary : .primary)
                                }
                                .width(min: 120, ideal: 144, max: 360)
                                TableColumn("路径") { row in
                                    HStack(spacing: 6) {
                                        Button {
                                            model.revealInFinder(row.entry.url)
                                        } label: {
                                            Image(systemName: "arrow.right.circle.fill")
                                        }
                                        .buttonStyle(IconPillButton(tint: AppTheme.accent))
                                        .help("在访达中显示该文件")
                                        Button {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(row.entry.pathDisplay, forType: .string)
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                        }
                                        .buttonStyle(IconPillButton(tint: .secondary))
                                        .help("复制完整路径")
                                        Text(row.entry.pathDisplay)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                                .width(min: 160, ideal: 480, max: .infinity)
                            }
                            .frame(minHeight: 330)
                        }
                    }
                }
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func summarySection(_ r: ScanResult, model: LargeFileScanViewModel) -> some View {
        // --- 1) 饼图概要：按应用分组 ---
        if !r.smallFiles.appGroups.isEmpty {
            SmallFilePieCard(
                appGroups: r.smallFiles.appGroups,
                totalBytes: r.smallFiles.totalBytes,
                selectedGroup: $filterGroupKey
            )
        }

        // --- 2) 目录明细表 ---
        ChromeCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("小文件目录明细", systemImage: "folder.fill.badge.gearshape")
                        .font(.headline)
                    Spacer()
                    if let key = filterGroupKey {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                            Text(key)
                                .font(.caption.weight(.semibold))
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) { filterGroupKey = nil }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(IconPillButton(tint: .secondary))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.accent.opacity(0.08))
                        .clipShape(Capsule(style: .continuous))
                    }
                }
                Text("低于阈值（\(ByteFormat.string(fromBytes: r.thresholdBytes))）的文件按直接父目录汇总。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !r.smallFiles.topParents.isEmpty {
                    let filtered = filterGroupKey == nil
                        ? r.smallFiles.topParents
                        : r.smallFiles.topParents.filter { $0.groupKey == filterGroupKey }
                    let rows = filtered.enumerated().map {
                        NumberedParentDir(ordinal: $0.offset + 1, dir: $0.element, totalSmallBytes: r.smallFiles.totalBytes)
                    }
                    Table(rows) {
                        TableColumn("排名") { row in
                            Text("\(row.ordinal)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .width(min: 36, ideal: 44, max: 52)
                        TableColumn("大小") { row in
                            Text(ByteFormat.string(fromBytes: row.dir.totalBytes))
                                .monospacedDigit()
                        }
                        .width(min: 64, ideal: 72, max: 88)
                        TableColumn("占比") { row in
                            Text("\(String(format: "%.1f", row.percentage))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .width(min: 48, ideal: 56, max: 64)
                        TableColumn("文件数") { row in
                            Text("\(row.dir.fileCount)")
                                .monospacedDigit()
                        }
                        .width(min: 48, ideal: 56, max: 72)
                        TableColumn("目录路径") { row in
                            HStack(spacing: 6) {
                                Button {
                                    model.revealInFinder(URL(fileURLWithPath: row.dir.path, isDirectory: true))
                                } label: {
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                .buttonStyle(IconPillButton(tint: AppTheme.accent))
                                .help("在访达中打开该目录")
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(row.dir.path, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(IconPillButton(tint: .secondary))
                                .help("复制完整路径")
                                Text(row.dir.path)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .width(min: 160, ideal: 480, max: .infinity)
                    }
                    .frame(minHeight: 330)

                    let topSum = r.smallFiles.topParents.reduce(Int64(0)) { $0 + $1.totalBytes }
                    let otherBytes = r.smallFiles.totalBytes - topSum
                    if otherBytes > 0 {
                        let otherPct = Double(otherBytes) / Double(r.smallFiles.totalBytes) * 100
                        Text("其余目录合计 \(ByteFormat.string(fromBytes: otherBytes))（\(String(format: "%.1f", otherPct))%）")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                if !r.errors.isEmpty {
                    Divider()
                    DisclosureGroup {
                        ScrollView {
                            Text(r.errors.prefix(50).joined(separator: "\n"))
                                .font(.caption2)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 120)
                    } label: {
                        Label("扫描警告（\(r.errors.count)）", systemImage: "exclamationmark.circle")
                            .foregroundStyle(AppTheme.warning)
                    }
                }
            }
        }
    }

}

// MARK: - Scan Control Card

private struct ScanControlCard: View {
    @ObservedObject var model: LargeFileScanViewModel
    @State private var isPulsing = false

    var body: some View {
        ChromeCard {
            VStack(spacing: 20) {
                // 目录行
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(AppTheme.accent)
                    Text(model.scanRoot?.path ?? "~")
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Button("更换目录") { model.chooseScanRoot() }
                        .buttonStyle(GhostPillButton(compact: true))
                        .disabled(model.isScanning)
                }

                // 大圆按钮
                ZStack {
                    // 扫描中光晕
                    if model.isScanning {
                        Circle()
                            .fill(AppTheme.danger.opacity(0.15))
                            .frame(width: 148, height: 148)
                            .scaleEffect(isPulsing ? 1.18 : 1.0)
                            .opacity(isPulsing ? 0 : 0.7)
                            .animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: isPulsing)
                    }

                    Button {
                        if model.isScanning {
                            model.stopScan()
                        } else {
                            model.startScan()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    model.isScanning
                                        ? LinearGradient(colors: [AppTheme.danger, AppTheme.warning], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [AppTheme.accent, AppTheme.accentSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 120, height: 120)
                                .shadow(color: (model.isScanning ? AppTheme.danger : AppTheme.accent).opacity(0.35), radius: 18, y: 6)

                            if model.isScanning {
                                VStack(spacing: 4) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text("停止")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            } else {
                                Text("扫描")
                                    .font(.system(size: 26, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(model.isScanning ? .cancelAction : .defaultAction)
                }
                .frame(maxWidth: .infinity)
                .onChange(of: model.isScanning) {
                    isPulsing = model.isScanning
                }

                // 进度信息
                if model.isScanning {
                    VStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.85)
                        Text(model.progressPath.isEmpty ? "正在准备…" : model.progressPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 480)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .animation(.easeOut(duration: 0.25), value: model.isScanning)
            .padding(.vertical, 8)
        }
    }
}

private struct NumberedLargeFile: Identifiable {
    let ordinal: Int
    let entry: LargeFileEntry
    var id: UUID { entry.id }
}

private struct NumberedParentDir: Identifiable {
    let ordinal: Int
    let dir: ParentDirSummary
    let totalSmallBytes: Int64
    var id: String { dir.path }
    var percentage: Double {
        totalSmallBytes > 0 ? Double(dir.totalBytes) / Double(totalSmallBytes) * 100 : 0
    }
}

// MARK: - Pie Chart Card

private struct SmallFilePieCard: View {
    let appGroups: [AppGroup]
    let totalBytes: Int64
    @Binding var selectedGroup: String?

    @State private var rawSelectedAngle: Int64?

    private let chartLimit = 10
    private static let palette: [Color] = [
        .blue, .orange, .green, .red, .purple,
        .cyan, .pink, .yellow, .mint, .indigo, .gray,
    ]

    private var topSlices: [AppGroup] { Array(appGroups.prefix(chartLimit)) }
    private var topSum: Int64 { topSlices.reduce(0) { $0 + $1.totalBytes } }
    private var otherBytes: Int64 { totalBytes - topSum }

    private struct Slice: Identifiable, Equatable {
        let name: String
        let bytes: Int64
        let fileCount: Int
        let dirCount: Int
        let colorIndex: Int
        let isOther: Bool
        var id: String { name }
    }

    private var allSlices: [Slice] {
        var result = topSlices.enumerated().map { idx, g in
            Slice(name: g.name, bytes: g.totalBytes, fileCount: g.fileCount, dirCount: g.dirCount, colorIndex: idx, isOther: false)
        }
        if otherBytes > 0 {
            let otherFileCount = appGroups.dropFirst(chartLimit).reduce(0) { $0 + $1.fileCount }
            let otherDirCount = appGroups.dropFirst(chartLimit).reduce(0) { $0 + $1.dirCount }
            result.append(Slice(name: "其余", bytes: otherBytes, fileCount: otherFileCount, dirCount: otherDirCount, colorIndex: chartLimit, isOther: true))
        }
        return result
    }

    private var hoveredSlice: Slice? {
        guard let rawSelectedAngle else { return nil }
        var cumulative: Int64 = 0
        for s in allSlices {
            cumulative += s.bytes
            if rawSelectedAngle <= cumulative { return s }
        }
        return nil
    }

    private func toggleFilter(for slice: Slice) {
        guard !slice.isOther else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            selectedGroup = selectedGroup == slice.name ? nil : slice.name
        }
    }

    var body: some View {
        ChromeCard {
            VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label("小文件概要", systemImage: "chart.pie.fill")
                        .font(.headline)
                    Spacer()
                    Text("共 \(ByteFormat.string(fromBytes: totalBytes))")
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text("按应用 / 标识聚合。悬停扇区查看详情，点击可筛选下方目录明细。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Chart(allSlices) { s in
                        let isActive = selectedGroup == nil || selectedGroup == s.name
                        SectorMark(
                            angle: .value("大小", s.bytes),
                            innerRadius: .ratio(0.52),
                            outerRadius: hoveredSlice?.id == s.id ? .ratio(1.0) : .ratio(0.92),
                            angularInset: 1.2
                        )
                        .foregroundStyle(Self.palette[s.colorIndex % Self.palette.count])
                        .cornerRadius(3)
                        .opacity(isActive ? (hoveredSlice == nil || hoveredSlice?.id == s.id ? 1.0 : 0.55) : 0.2)
                        .annotation(position: .overlay) {
                            let pct = totalBytes > 0 ? Double(s.bytes) / Double(totalBytes) * 100 : 0
                            if pct >= 6 {
                                Text("\(String(format: "%.0f", pct))%")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .opacity(isActive ? 1 : 0.3)
                            }
                        }
                    }
                    .chartAngleSelection(value: $rawSelectedAngle)
                    .chartLegend(.hidden)
                    .frame(width: 280, height: 280)
                    .onTapGesture {
                        if let h = hoveredSlice { toggleFilter(for: h) }
                    }

                    VStack(spacing: 2) {
                        if let h = hoveredSlice {
                            let pct = totalBytes > 0 ? Double(h.bytes) / Double(totalBytes) * 100 : 0
                            Text(h.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            Text(ByteFormat.string(fromBytes: h.bytes))
                                .font(.system(size: 18, weight: .heavy, design: .rounded).monospacedDigit())
                            Text("\(String(format: "%.1f", pct))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("\(h.fileCount) 文件 · \(h.dirCount) 目录")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            if !h.isOther {
                                Text("点击筛选")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(AppTheme.accent)
                                    .padding(.top, 2)
                            }
                        } else if let sel = selectedGroup {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(AppTheme.accent)
                            Text(sel)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Text("已筛选")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "chart.pie.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.quaternary)
                            Text("悬停查看")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 120)
                    .animation(.easeOut(duration: 0.15), value: hoveredSlice?.id)
                }

                legendGrid
            }
        }
    }

    private var legendGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 6),
            GridItem(.flexible(), spacing: 6),
        ]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
            ForEach(allSlices) { s in
                let pct = totalBytes > 0 ? Double(s.bytes) / Double(totalBytes) * 100 : 0
                let isActive = selectedGroup == nil || selectedGroup == s.name
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Self.palette[s.colorIndex % Self.palette.count])
                        .frame(width: 12, height: 12)
                        .opacity(isActive ? 1 : 0.3)
                    Text(s.name)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if selectedGroup == s.name {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.accent)
                    }
                    Spacer()
                    Text(ByteFormat.string(fromBytes: s.bytes))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("\(String(format: "%.1f", pct))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
                .background(
                    selectedGroup == s.name
                        ? RoundedRectangle(cornerRadius: 5, style: .continuous).fill(AppTheme.accent.opacity(0.08))
                        : hoveredSlice?.id == s.id
                            ? RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.04))
                            : nil
                )
                .opacity(isActive ? 1 : 0.5)
                .contentShape(Rectangle())
                .onTapGesture { toggleFilter(for: s) }
            }
        }
    }
}
