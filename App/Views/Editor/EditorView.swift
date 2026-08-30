import SwiftData
import SwiftUI

struct EditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// nil 表示在写新日记。
    let diary: Diary?

    @State private var title = ""
    @State private var content = ""
    @State private var mood = ""
    @State private var weather = ""
    @State private var locationName = ""

    @State private var isPreviewing = false
    @State private var isShowingDiscardAlert = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case content
    }

    init(diary: Diary? = nil) {
        self.diary = diary
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                metaBar
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                bodyArea
            }
            .navigationTitle(diary == nil ? "新日记" : "编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) { editorToolbar }
            .background(Color(.systemGroupedBackground))
            .onAppear(perform: load)
            .alert("丢弃这篇日记？", isPresented: $isShowingDiscardAlert) {
                Button("丢弃", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            }
        }
    }

    // MARK: - 心情 / 天气 / 位置

    /// 三个胶囊放在同一个 `GlassEffectContainer` 里，会像液体一样连成一整条玻璃。
    /// 低于 iOS 26 时容器不存在，直接平铺即可。
    @ViewBuilder
    private var metaBar: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 8) { metaChips }
        } else {
            metaChips
        }
    }

    private var metaChips: some View {
        HStack(spacing: 8) {
            metaChip("心情", text: $mood, symbol: "face.smiling")
            metaChip("天气", text: $weather, symbol: "cloud.sun")
            metaChip("位置", text: $locationName, symbol: "location")
        }
    }

    private func metaChip(_ placeholder: String,
                          text: Binding<String>,
                          symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .font(.footnote)
                .textFieldStyle(.plain)
                .submitLabel(.done)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .capsuleGlass()
    }

    // MARK: - 正文

    @ViewBuilder
    private var bodyArea: some View {
        if isPreviewing {
            previewArea
        } else {
            editArea
        }
    }

    private var editArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("标题", text: $title)
                .font(.title2.weight(.semibold))
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .onSubmit { focusedField = .content }
                .padding(.horizontal, 18)
                .padding(.bottom, 6)

            TextEditor(text: $content)
                .font(.body)
                .focused($focusedField, equals: .content)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .frame(maxHeight: .infinity)
        }
    }

    private var previewArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !title.isEmpty {
                    Text(title)
                        .font(.title2.weight(.semibold))
                }
                if let attributed = try? AttributedString(markdown: content) {
                    Text(attributed)
                        .font(.body)
                } else {
                    Text(content)
                        .font(.body)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
    }

    // MARK: - 底部玻璃工具条

    private var editorToolbar: some View {
        GlassFloatingBar(spacing: 6) {
            GlassIconButton("photo") { }
            GlassIconButton("mic") { }
            GlassIconButton("tag") { }

            GlassBarDivider()

            GlassIconButton(isPreviewing ? "pencil" : "eye",
                            tint: isPreviewing ? Color.accentColor : .primary) {
                isPreviewing.toggle()
            }

            GlassBarDivider()

            Text("\(content.filter { !$0.isWhitespace && !$0.isNewline }.count) 字")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.horizontal, 10)
                .frame(height: 42)
        }
    }

    // MARK: - 顶部按钮

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("取消") {
                if hasChanges {
                    isShowingDiscardAlert = true
                } else {
                    dismiss()
                }
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("保存") { save() }
                .disabled(title.isEmpty && content.isEmpty)
        }
    }

    // MARK: - 数据

    private var hasChanges: Bool {
        guard let diary else {
            return !title.isEmpty || !content.isEmpty
        }
        return title != diary.title
            || content != diary.content
            || mood != diary.mood
            || weather != diary.weather
            || locationName != diary.locationName
    }

    private func load() {
        guard let diary else {
            focusedField = .content
            return
        }
        title = diary.title
        content = diary.content
        mood = diary.mood
        weather = diary.weather
        locationName = diary.locationName
    }

    private func save() {
        let target: Diary
        if let diary {
            target = diary
        } else {
            target = Diary()
            modelContext.insert(target)
        }

        target.title = title
        target.content = content
        target.mood = mood
        target.weather = weather
        target.locationName = locationName
        target.touch()

        try? modelContext.save()
        dismiss()
    }
}
