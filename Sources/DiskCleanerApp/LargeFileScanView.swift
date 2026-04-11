import AppKit
import Charts
import SwiftUI

struct LargeFileScanView: View {
    @ObservedObject var model: LargeFileScanViewModel
    @State private var filterGroupKey: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("空间分析看板")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("洞察存储瓶颈，管理磁盘空间")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

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
        ChromeCard(useMaterial: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("目录明细", systemImage: "folder.fill.badge.gearshape")
                        .font(.headline)
                    Spacer()
                    
                    // 重新统计按钮
                    Button {
                        model.refreshResults()
                    } label: {
                        Label("重新统计", systemImage: "arrow.clockwise")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(GhostPillButton(tint: AppTheme.accent, compact: true))
                    .help("快速检查列表中文件是否依然存在，并更新统计数据")
                    
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
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(Capsule(style: .continuous))
                    }
                }

                if !r.smallFiles.topParents.isEmpty {
                    let filtered = filterGroupKey == nil
                        ? Array(r.smallFiles.topParents.prefix(100))
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
                                .fontWeight(.medium)
                        }
                        .width(min: 70, ideal: 80, max: 90)
                        TableColumn("占比") { row in
                            Gauge(value: row.percentage, in: 0...100) {
                                Text("\(Int(row.percentage))%")
                            }
                            .gaugeStyle(.accessoryLinear)
                            .tint(AppTheme.accent.opacity(0.7))
                            .frame(width: 80)
                        }
                        .width(90)
                        TableColumn("目录路径") { row in
                            HStack(spacing: 8) {
                                Button {
                                    model.revealInFinder(URL(fileURLWithPath: row.dir.path, isDirectory: true))
                                } label: {
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .buttonStyle(IconPillButton(tint: .blue))
                                .help("在 Finder 中查看")

                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(row.dir.path, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(IconPillButton(tint: .secondary))
                                .help("复制完整路径")
                                
                                Text(row.dir.path)
                                    .font(.system(size: 11, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .width(min: 160, ideal: 480, max: .infinity)
                    }
                    .frame(minHeight: 330)
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
    @State private var phase = 0.0
    @State private var isPulsing = false

    var body: some View {
        ChromeCard(useMaterial: true) {
            VStack(spacing: 24) {
                // 顶部扫描状态
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("扫描目录")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(AppTheme.accent)
                            Text(model.scanRoot?.path ?? "~")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    Spacer()
                    Button("更改") { model.chooseScanRoot() }
                        .buttonStyle(GhostPillButton(compact: true))
                        .disabled(model.isScanning)
                }

                // 中心大按钮区域
                ZStack {
                    // 背景光晕 (Aurora Effect - Compatible with macOS 14)
                    if model.isScanning {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.15))
                                .frame(width: 140, height: 140)
                                .offset(x: isPulsing ? 30 : -30, y: isPulsing ? -20 : 20)
                            Circle()
                                .fill(AppTheme.accentSecondary.opacity(0.15))
                                .frame(width: 160, height: 160)
                                .offset(x: isPulsing ? -40 : 40, y: isPulsing ? 30 : -30)
                        }
                        .blur(radius: 35)
                        .rotationEffect(.degrees(phase))
                        .onAppear {
                            isPulsing = true
                            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                                isPulsing = false
                            }
                            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                                phase = 360
                            }
                        }
                    }

                    Button {
                        withAnimation {
                            if model.isScanning {
                                model.stopScan()
                            } else {
                                model.startScan()
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: model.isScanning 
                                            ? [AppTheme.danger, AppTheme.danger.opacity(0.8)] 
                                            : [Color.green, Color.green.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(color: (model.isScanning ? AppTheme.danger : .green).opacity(0.4), radius: 12, y: 6)

                            VStack(spacing: 4) {
                                Image(systemName: model.isScanning ? "stop.fill" : "play.fill")
                                    .font(.system(size: 24, weight: .bold))
                                Text(model.isScanning ? "停止" : "开始扫描")
                                    .font(.system(size: 12, weight: .heavy))
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 10)

                // 进度条与路径
                if model.isScanning {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .tint(AppTheme.accent)
                            .frame(maxWidth: 300)
                        
                        Text(model.progressPath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2, reservesSpace: false)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
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
    
    @State private var isExpanded = false
    @State private var rawSelectedAngle: Int64?

    private var chartLimit: Int { isExpanded ? 60 : 10 }
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
        if otherBytes > 0 && !isExpanded {
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
        ChromeCard(useMaterial: true) {
            VStack(spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label("分类统计", systemImage: "chart.donut")
                        .font(.headline)
                    Spacer()
                    
                    if appGroups.count > 10 {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isExpanded ? "收起" : "查看更多明细")
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 4) {
                        Text("合计")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(ByteFormat.string(fromBytes: totalBytes))
                            .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                
                HStack(spacing: 40) {
                    // 图表
                    ZStack {
                        Chart(allSlices) { s in
                            let isActive = selectedGroup == nil || selectedGroup == s.name
                            SectorMark(
                                angle: .value("大小", s.bytes),
                                innerRadius: .ratio(0.65),
                                outerRadius: hoveredSlice?.id == s.id ? .ratio(1.0) : .ratio(0.92),
                                angularInset: 1.5
                            )
                            .foregroundStyle(Self.palette[s.colorIndex % Self.palette.count].gradient)
                            .cornerRadius(4)
                            .opacity(isActive ? (hoveredSlice == nil || hoveredSlice?.id == s.id ? 1.0 : 0.4) : 0.15)
                        }
                        .chartAngleSelection(value: $rawSelectedAngle)
                        .chartLegend(.hidden)
                        .frame(width: 220, height: 220)
                        .onTapGesture {
                            if let h = hoveredSlice { toggleFilter(for: h) }
                        }

                        // 中心文案
                        VStack(spacing: 2) {
                            if let h = hoveredSlice {
                                let pct = totalBytes > 0 ? Double(h.bytes) / Double(totalBytes) * 100 : 0
                                Text(h.name)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                                    .multilineTextAlignment(.center)
                                Text(ByteFormat.string(fromBytes: h.bytes))
                                    .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                                Text("\(String(format: "%.1f", pct))%")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "hand.pointer.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.quaternary)
                                    .symbolEffect(.pulse)
                                Text("悬停分析")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(width: 100)
                    }

                    // 图例
                    legendGrid
                }
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
