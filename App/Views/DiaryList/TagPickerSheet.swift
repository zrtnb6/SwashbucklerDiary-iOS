import SwiftData
import SwiftUI

/// 给一篇日记挑标签。可多选，也能顺手新建。
struct TagPickerSheet: View {
    let diary: Diary

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var newTagName = ""
    @State private var errorMessage: String?

    private var selectedIDs: Set<UUID> {
        Set(diary.tags.map(\.id))
    }

    var body: some View {
        NavigationStack {
            List {
                if !allTags.isEmpty {
                    Section {
                        ForEach(allTags) { tag in
                            Button { toggle(tag) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "number")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                    Text(tag.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(tag.diaries.count)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                    if selectedIDs.contains(tag.id) {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("已有标签")
                    }
                }

                Section {
                    // 新建标签的文本框刻意留空，不要默认占位值。
                    TextField("", text: $newTagName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(createTag)
                } header: {
                    Text("新建标签")
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else {
                        Text("回车即可创建，并自动勾选到这篇日记。")
                    }
                }
            }
            .navigationTitle("标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func toggle(_ tag: Tag) {
        if let index = diary.tags.firstIndex(where: { $0.id == tag.id }) {
            diary.tags.remove(at: index)
        } else {
            diary.tags.append(tag)
        }
        diary.touch()
        try? modelContext.save()
    }

    private func createTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if let existing = allTags.first(where: { $0.name == name }) {
            if !selectedIDs.contains(existing.id) { toggle(existing) }
        } else {
            let tag = Tag(name: name)
            modelContext.insert(tag)
            diary.tags.append(tag)
            diary.touch()
            try? modelContext.save()
        }
        newTagName = ""
        errorMessage = nil
    }
}
