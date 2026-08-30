import SwiftData
import SwiftUI

/// 首页「标签」页：标签一览与管理。
///
/// 原项目标签页的排序可以按数量 / 名称 / 创建时间，和日记分开存。
struct TagListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @Query private var tags: [Tag]

    @State private var showCreate = false
    @State private var newTagName = ""
    @State private var renameTarget: Tag?
    @State private var renameText = ""
    @State private var deleteTarget: Tag?
    @State private var mergeTarget: Tag?
    @State private var mergeIntoID: UUID?
    @State private var errorMessage: String?

    init() {
        // 标签页的排序是运行时可变的，`@Query` 的排序参数固定，
        // 所以这里只按名称取全量，实际顺序在 `sortedTags` 里决定。
        _tags = Query(sort: \Tag.name)
    }

    private var sortedTags: [Tag] {
        let option = settings.data.tagSort
        return tags.sorted { lhs, rhs in
            let ascending: Bool
            switch option.field {
            case .count:
                ascending = lhs.diaries.count < rhs.diaries.count
            case .name:
                ascending = lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .createTime:
                ascending = lhs.createTime < rhs.createTime
            case .updateTime:
                ascending = lhs.updateTime < rhs.updateTime
            }
            return option.ascending ? ascending : !ascending
        }
    }

    var body: some View {
        content
            .navigationTitle("标签")
            .toolbar { toolbar }
            .safeAreaInset(edge: .bottom) { floatingBar }
            .alert("新建标签", isPresented: $showCreate) {
                TextField("", text: $newTagName)
                Button("取消", role: .cancel) { newTagName = "" }
                Button("创建") { createTag() }
            }
            .alert("重命名标签", isPresented: renamePresented) {
                TextField("", text: $renameText)
                Button("取消", role: .cancel) { renameTarget = nil }
                Button("保存") { commitRename() }
            }
            .confirmationDialog("删除标签", isPresented: deletePresented, titleVisibility: .visible) {
                Button("删除标签", role: .destructive) { commitDelete() }
                Button("取消", role: .cancel) { deleteTarget = nil }
            } message: {
                Text("「\(deleteTarget?.name ?? "")」会被移除，日记本身不会删除。")
            }
            .sheet(item: $mergeTarget) { tag in
                MergeTagSheet(source: tag)
            }
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        if sortedTags.isEmpty {
            ContentUnavailableView {
                Label("还没有标签", systemImage: "tag")
            } description: {
                Text("标签用来给日记归档，写日记时随手加上就行。")
            }
            .background(Color(.systemGroupedBackground))
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(sortedTags) { tag in
                        NavigationLink(value: tag.id) {
                            tagRow(tag)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteTarget = tag
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button { mergeTarget = tag } label: {
                                Label("合并到", systemImage: "arrow.triangle.merge")
                            }
                            .tint(.indigo)
                            Button {
                                renameTarget = tag
                                renameText = tag.name
                            } label: {
                                Label("重命名", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationDestination(for: UUID.self) { id in
                if let tag = tags.first(where: { $0.id == id }) {
                    TagDetailView(tag: tag)
                }
            }
        }
    }

    private func tagRow(_ tag: Tag) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "number")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text("创建于 \(tag.createTime.formatted(with: "yyyy/MM/dd"))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Text("\(tag.diaries.count)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06), in: Capsule())

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - 工具条

    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker("排序字段", selection: tagSortFieldBinding) {
                    ForEach([SortField.count, SortField.name, SortField.createTime], id: \.self) { field in
                        Text(field.displayName).tag(field)
                    }
                }
                .pickerStyle(.inline)
                Toggle("升序", isOn: tagAscendingBinding)
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
        }
    }

    private var floatingBar: some View {
        GlassFloatingBar(spacing: 8) {
            GlassProminentButton("新标签", systemImage: "plus") {
                newTagName = ""
                showCreate = true
            }
        }
    }

    private var tagSortFieldBinding: Binding<SortField> {
        Binding(
            get: { settings.data.tagSort.field },
            set: { settings.data.tagSort.field = $0 }
        )
    }

    private var tagAscendingBinding: Binding<Bool> {
        Binding(
            get: { settings.data.tagSort.ascending },
            set: { settings.data.tagSort.ascending = $0 }
        )
    }

    // MARK: - 动作

    private var renamePresented: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }

    private var deletePresented: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !tags.contains(where: { $0.name == name }) else {
            errorMessage = "标签已存在"
            newTagName = ""
            return
        }
        modelContext.insert(Tag(name: name))
        try? modelContext.save()
        newTagName = ""
    }

    private func commitRename() {
        guard let tag = renameTarget else { return }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, !tags.contains(where: { $0.id != tag.id && $0.name == name }) {
            tag.name = name
            tag.updateTime = Date()
            try? modelContext.save()
        }
        renameTarget = nil
    }

    private func commitDelete() {
        guard let tag = deleteTarget else { return }
        modelContext.delete(tag)
        try? modelContext.save()
        deleteTarget = nil
    }
}

/// 把一个标签的日记整体并入另一个标签，然后删掉源标签。
private struct MergeTagSheet: View {
    let source: Tag

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Tag.name) private var allTags: [Tag]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(candidates) { tag in
                        Button { merge(into: tag) } label: {
                            HStack {
                                Text(tag.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(tag.diaries.count) 篇")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                } header: {
                    Text("并入")
                } footer: {
                    Text("「\(source.name)」下 \(source.diaries.count) 篇日记会改挂到目标标签，源标签随后删除。")
                }
            }
            .navigationTitle("合并标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var candidates: [Tag] {
        allTags.filter { $0.id != source.id }
    }

    private func merge(into target: Tag) {
        for diary in source.diaries where !target.diaries.contains(where: { $0.id == diary.id }) {
            target.diaries.append(diary)
        }
        modelContext.delete(source)
        try? modelContext.save()
        dismiss()
    }
}
