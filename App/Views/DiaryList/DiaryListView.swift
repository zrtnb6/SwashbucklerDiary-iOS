import SwiftData
import SwiftUI

enum EditorTarget: Identifiable {
    case new
    case existing(Diary)

    var id: String {
        switch self {
        case .new:
            return "new"
        case .existing(let diary):
            return diary.id.uuidString
        }
    }

    var diary: Diary? {
        switch self {
        case .new: return nil
        case .existing(let diary): return diary
        }
    }
}

struct DiaryListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Diary.updateTime, order: .reverse)])
    private var diaries: [Diary]

    @State private var searchText = ""
    @State private var filter: DiaryFilter = .all
    @State private var sort: DiarySort = .updated
    @State private var editorTarget: EditorTarget?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("日记")
                .searchable(text: $searchText, prompt: "搜索标题、正文或标签")
                .softScrollEdge()
                .safeAreaInset(edge: .bottom) { floatingBar }
                .sheet(item: $editorTarget) { EditorView(diary: $0.diary) }
        }
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        if visibleDiaries.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 12, pinnedViews: .sectionHeaders) {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.diaries) { diary in
                                row(for: diary)
                            }
                        } header: {
                            sectionHeader(section.title)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(searchText.isEmpty ? "还没有日记" : "没有匹配的日记",
                  systemImage: searchText.isEmpty ? "book.closed" : "magnifyingglass")
        } description: {
            Text(searchText.isEmpty
                 ? "点下方「新日记」，写下第一篇。"
                 : "换个关键词试试。")
        }
        .background(Color(.systemGroupedBackground))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            // 吸顶时必须有不透明背景，否则滚动内容会从标题下穿帮。
            .background(Color(.systemGroupedBackground))
    }

    private func row(for diary: Diary) -> some View {
        Button { editorTarget = .existing(diary) } label: {
            DiaryCard(diary: diary)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { delete(diary) } label: {
                Label("删除", systemImage: "trash")
            }
            Button { togglePin(diary) } label: {
                Label(diary.isPinned ? "取消置顶" : "置顶",
                      systemImage: diary.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
        .contextMenu {
            Button { togglePin(diary) } label: {
                Label(diary.isPinned ? "取消置顶" : "置顶",
                      systemImage: diary.isPinned ? "pin.slash" : "pin")
            }
            Button(role: .destructive) { delete(diary) } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: - 底部浮动玻璃工具条

    /// iOS 26 最重要的一个变化：主要操作从顶部导航栏挪到底部的悬浮玻璃条。
    /// `GlassFloatingBar` 里的 `GlassEffectContainer` 会让这几个按钮在视觉上连成一体。
    private var floatingBar: some View {
        GlassFloatingBar(spacing: 8) {
            GlassMenuButton("line.3.horizontal.decrease", isActive: filter != .all) {
                Picker("筛选", selection: $filter) {
                    ForEach(DiaryFilter.allCases) { option in
                        Label(option.rawValue, systemImage: option.systemImage).tag(option)
                    }
                }
            }

            GlassMenuButton("arrow.up.arrow.down", isActive: sort != .updated) {
                Picker("排序", selection: $sort) {
                    ForEach(DiarySort.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            }

            GlassBarDivider()

            GlassProminentButton("新日记", systemImage: "square.and.pencil") {
                editorTarget = .new
            }
        }
    }

    // MARK: - 数据

    private var visibleDiaries: [Diary] {
        let base = diaries.filter { !$0.isTemplate && filter.matches($0) }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [Diary]
        if query.isEmpty {
            filtered = base
        } else {
            let needle = query.lowercased()
            filtered = base.filter { diary in
                diary.title.lowercased().contains(needle)
                    || diary.content.lowercased().contains(needle)
                    || diary.tags.contains { $0.name.lowercased().contains(needle) }
            }
        }

        return sort.sort(filtered)
    }

    private var sections: [DiarySection] {
        DiarySection.build(from: visibleDiaries)
    }

    // MARK: - 操作

    private func delete(_ diary: Diary) {
        modelContext.delete(diary)
        try? modelContext.save()
    }

    private func togglePin(_ diary: Diary) {
        diary.isPinned.toggle()
        diary.touch()
        try? modelContext.save()
    }
}
