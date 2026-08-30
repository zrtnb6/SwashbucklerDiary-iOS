import SwiftData
import SwiftUI

/// 阅读页。原项目 `ReadPage`：点卡片进的是这里，要看可编辑的字段才去编辑器。
struct ReadView: View {
    let diary: Diary

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @State private var showEditor = false
    @State private var sharePayload: SharePayload?
    @State private var showExportPicker = false
    @State private var showDeleteConfirm = false
    @State private var toast: ToastItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider().opacity(0.5)

                if diary.content.isEmpty {
                    Text("（这篇日记还没有正文）")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                } else {
                    MarkdownContent(content: diary.content,
                                    firstLineIndent: settings.data.firstLineIndent)
                }

                if !diary.tags.isEmpty {
                    tagRow
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .toast($toast)
        .diaryMenu(diary)
        .sheet(isPresented: $showEditor) { EditorView(diary: diary) }
        .sheet(item: $sharePayload) { ActivitySheet(items: $0.items) }
        .confirmationDialog("导出这篇日记", isPresented: $showExportPicker, titleVisibility: .visible) {
            ForEach(DiaryExporter.ExportFormat.allCases) { format in
                Button(format.rawValue) {
                    guard let url = DiaryExporter.writeTemporaryFile(for: diary, format: format) else { return }
                    sharePayload = SharePayload([url])
                }
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("删除这篇日记？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) { delete() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("「\(diary.displayTitle)」将被删除，且无法恢复。")
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(diary.displayTitle.isEmpty ? "无标题" : diary.displayTitle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(diary.displayTitle.isEmpty ? .tertiary : .primary)

            Text(diary.createTime.formatted(with: settings.data.diaryTimeFormat))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            FlowLayout(spacing: 8) {
                if !diary.mood.isEmpty {
                    GlassChip(text: diary.mood, systemImage: diary.moodSymbol)
                }
                if !diary.weather.isEmpty {
                    GlassChip(text: diary.weather, systemImage: diary.weatherSymbol)
                }
                if !diary.locationName.isEmpty {
                    GlassChip(text: diary.locationName, systemImage: "location")
                }
                if diary.isTemplate {
                    GlassChip(text: "模板", systemImage: "doc.on.doc")
                }
                if diary.isPrivate {
                    GlassChip(text: "私密", systemImage: "lock")
                }
            }
        }
    }

    private var tagRow: some View {
        FlowLayout(spacing: 8) {
            ForEach(diary.tags) { tag in
                Text(tag.name)
                    .font(.caption)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
            }
        }
    }

    // MARK: - 工具条

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button { showEditor = true } label: {
                    Label("编辑", systemImage: "pencil")
                }
                Button { showExportPicker = true } label: {
                    Label("导出", systemImage: "square.and.arrow.up")
                }
                Button { copyText() } label: {
                    Label("复制正文", systemImage: "doc.on.doc")
                }
                Divider()
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("删除", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - 动作

    private func copyText() {
        UIPasteboard.general.string = diary.content
        toast = .copied("正文")
    }

    private func delete() {
        modelContext.delete(diary)
        try? modelContext.save()
        dismiss()
    }
}

/// 自动换行的横向布局。心情 / 天气 / 标签这些数量不定的 chip，
/// 用 `HStack` 会溢出，用 `LazyVGrid` 又算不准列宽。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width + (rowWidth > 0 ? spacing : 0) > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth)

        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
