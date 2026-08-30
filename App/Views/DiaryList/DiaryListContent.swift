import SwiftData
import SwiftUI

/// 首页「全部」页：日记列表 + 筛选 + 排序 + 浮动操作条。
///
/// 排序直接读 `AppSettings.diarySort`，改完自动落盘，下次打开还在。
struct DiaryListContent: View {
    /// 筛选条件由 `HomeView` 持有：搜索框挂在导航栈上，三个分页共用一个搜索词。
    @Binding var criteria: DiaryCriteria

    /// 只显示模板的场合复用本视图（首页第三个 tab）。
    var templatesOnly: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query(sort: [SortDescriptor(\Diary.updateTime, order: .reverse)])
    private var diaries: [Diary]

    @State private var showFilterSheet = false
    @State private var editorTarget: EditorTarget?

    var body: some View {
        content
            .safeAreaInset(edge: .bottom) { floatingBar }
            .sheet(item: $editorTarget) { EditorView(diary: $0.diary) }
            .sheet(isPresented: $showFilterSheet) {
                DiaryFilterSheet(criteria: $criteria)
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
            Label(emptyTitle, systemImage: emptySymbol)
        } description: {
            Text(emptyMessage)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var emptyTitle: String {
        if criteria.isActive { return "没有匹配的日记" }
        return templatesOnly ? "还没有模板" : "还没有日记"
    }

    private var emptySymbol: String {
        if criteria.isActive { return "magnifyingglass" }
        return templatesOnly ? "doc.on.doc" : "book.closed"
    }

    private var emptyMessage: String {
        if criteria.isActive { return "放宽筛选条件，或换个关键词试试。" }
        return templatesOnly
            ? "把一篇日记长按设为模板，写新日记时就能直接套用。"
            : "点下方「新日记」，写下第一篇。"
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
        .diaryMenu(diary)
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
        .swipeActions(edge: .leading) {
            Button { editorTarget = .existing(diary) } label: {
                Label("编辑", systemImage: "pencil")
            }
            .tint(Color.accentColor)
        }
    }

    // MARK: - 底部浮动玻璃工具条

    /// iOS 26 最重要的一个变化：主要操作从顶部导航栏挪到底部的悬浮玻璃条。
    /// `GlassFloatingBar` 里的 `GlassEffectContainer` 会让这几个按钮在视觉上连成一体。
    private var floatingBar: some View {
        GlassFloatingBar(spacing: 8) {
            GlassMenuButton("line.3.horizontal.decrease", isActive: criteria.isActive) {
                Button {
                    showFilterSheet = true
                } label: {
                    Label("筛选条件", systemImage: "line.3.horizontal.decrease")
                }
                if criteria.isActive {
                    Button(role: .destructive) {
                        criteria = DiaryCriteria()
                    } label: {
                        Label("清空筛选", systemImage: "xmark.circle")
                    }
                }
            }

            GlassMenuButton("arrow.up.arrow.down") {
                Picker("排序字段", selection: sortFieldBinding) {
                    ForEach(SortField.allCases) { field in
                        Text(field.displayName).tag(field)
                    }
                }
                .pickerStyle(.inline)

                Toggle("升序", isOn: ascendingBinding)
            }

            GlassBarDivider()

            GlassProminentButton(primaryButtonTitle, systemImage: "square.and.pencil") {
                editorTarget = .new
            }
        }
    }

    private var primaryButtonTitle: String {
        templatesOnly ? "新模板" : "新日记"
    }

    private var sortFieldBinding: Binding<SortField> {
        Binding(
            get: { settings.data.diarySort.field },
            set: { settings.data.diarySort.field = $0 }
        )
    }

    private var ascendingBinding: Binding<Bool> {
        Binding(
            get: { settings.data.diarySort.ascending },
            set: { settings.data.diarySort.ascending = $0 }
        )
    }

    // MARK: - 数据

    private var visibleDiaries: [Diary] {
        let now = Date()
        let calendar = Calendar.current
        let filtered = diaries.filter { diary in
            diary.isTemplate == templatesOnly
                && criteria.matches(diary, calendar: calendar, now: now)
        }
        return filtered.sorted(by: settings.data.diarySort)
    }

    private var sections: [DiarySection] {
        DiarySection.build(from: visibleDiaries, sort: settings.data.diarySort)
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
