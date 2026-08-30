import SwiftData
import SwiftUI

/// 标签详情：这个标签下的所有日记。
struct TagDetailView: View {
    let tag: Tag

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @State private var editorTarget: EditorTarget?

    private var diaries: [Diary] {
        tag.diaries.sorted(by: settings.data.diarySort)
    }

    var body: some View {
        Group {
            if diaries.isEmpty {
                ContentUnavailableView {
                    Label("这个标签下还没有日记", systemImage: "tag.slash")
                } description: {
                    Text("写日记时把它勾上，就会出现在这一页。")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(diaries) { diary in
                            Button { editorTarget = .existing(diary) } label: {
                                DiaryCard(diary: diary)
                            }
                            .buttonStyle(.plain)
                            .diaryMenu(diary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(tag.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editorTarget) {
            EditorView(diary: $0.diary, asTemplate: $0.asTemplate)
        }
    }
}
