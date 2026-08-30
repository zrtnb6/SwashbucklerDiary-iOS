import SwiftData
import SwiftUI

struct EditorView: View {
    /// nil 表示在写新日记。
    let diary: Diary?
    /// 从模板页进来时，新建的日记直接就是模板。
    var asTemplate: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var title = ""
    @State private var content = ""
    @State private var mood = ""
    @State private var weather = ""
    @State private var locationName = ""
    @State private var isTemplate = false
    @State private var selectedTags: [Tag] = []

    @State private var pendingEdit: MarkdownEdit?
    @State private var isPreviewing = false
    @State private var showDiscardAlert = false
    @State private var showTagPicker = false
    @State private var showImagePicker = false
    @State private var showTemplatePicker = false
    @State private var toast: ToastItem?
    @FocusState private var isTitleFocused: Bool

    /// 正在编辑的对象。新建时也会立刻入库，这样自动保存有落点，
    /// 中途杀进程不会丢内容；取消时再把它删掉。
    @State private var draft: Diary?

    init(diary: Diary? = nil, asTemplate: Bool = false) {
        self.diary = diary
        self.asTemplate = asTemplate
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                metaBar
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 8)

                if isPreviewing {
                    previewArea
                } else {
                    editArea
                }

                if !isPreviewing {
                    MarkdownToolbar(pendingEdit: $pendingEdit)
                }
            }
            .navigationTitle(diary == nil ? "新日记" : "编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) { editorToolbar }
            .task {
                prepare()
                await runAutoSaveLoop()
            }
            .onDisappear(perform: flushIfNeeded)
            .toast($toast)
            .alert("丢弃这篇日记？", isPresented: $showDiscardAlert) {
                Button("丢弃", role: .destructive) { discard() }
                Button("继续编辑", role: .cancel) {}
            }
            .sheet(isPresented: $showTagPicker) {
                if let draft { TagPickerSheet(diary: draft) }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker { data in insertImage(data) }
            }
            .sheet(isPresented: $showTemplatePicker) {
                TemplatePickerSheet { template in applyTemplate(template) }
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

    private var editArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("标题", text: $title)
                .font(.title2.weight(.semibold))
                .focused($isTitleFocused)
                .submitLabel(.next)
                .onSubmit { isTitleFocused = false }
                .padding(.horizontal, 18)
                .padding(.bottom, 4)

            MarkdownTextView(text: $content, pendingEdit: $pendingEdit)
                .padding(.horizontal, 18)
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
                // `AttributedString(markdown:)` 覆盖标题 / 强调 / 列表 / 链接这些
                // 常用语法，够预览用；图片和表格要等阅读页用真正的解析器渲染。
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
        .frame(maxHeight: .infinity)
    }

    // MARK: - 底部工具条

    private var editorToolbar: some View {
        GlassFloatingBar(spacing: 6) {
            GlassIconButton("photo") { showImagePicker = true }

            GlassMenuButton("doc.on.doc") {
                Button {
                    showTemplatePicker = true
                } label: {
                    Label("套用模板", systemImage: "doc.on.doc")
                }
                Button {
                    isTemplate.toggle()
                } label: {
                    Label(isTemplate ? "取消模板" : "存为模板",
                          systemImage: isTemplate ? "xmark.circle" : "plus.circle")
                }
            }

            GlassIconButton("tag") { showTagPicker = true }

            GlassBarDivider()

            GlassIconButton(isPreviewing ? "pencil" : "eye",
                            tint: isPreviewing ? Color.accentColor : .primary) {
                isPreviewing.toggle()
            }

            GlassBarDivider()

            Text("\(wordCount) 字")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.horizontal, 10)
                .frame(height: 42)
        }
    }

    private var wordCount: Int {
        content.filter { !$0.isWhitespace && !$0.isNewline }.count
    }

    // MARK: - 顶部按钮

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("取消") {
                if hasChanges {
                    showDiscardAlert = true
                } else {
                    discard()
                }
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("保存") { commit() }
                .disabled(title.isEmpty && content.isEmpty)
        }
    }

    // MARK: - 生命周期

    private func prepare() {
        guard draft == nil else { return }

        if let diary {
            draft = diary
            title = diary.title
            content = diary.content
            mood = diary.mood
            weather = diary.weather
            locationName = diary.locationName
            isTemplate = diary.isTemplate
            selectedTags = diary.tags
        } else {
            let fresh = Diary()
            fresh.isTemplate = asTemplate
            modelContext.insert(fresh)
            draft = fresh
            isTemplate = asTemplate

            // 新建时是否直接套模板，由「新建时选择模板」这个开关决定。
            if settings.data.selectTemplateWhenCreate {
                applyDefaultTemplateIfAvailable()
            }
            isTitleFocused = true
        }
    }

    /// 按设置里的时间间隔自动落盘。
    ///
    /// 循环跑在 `.task` 的生命周期里，视图一消失就被取消，不需要手动收尾。
    private func runAutoSaveLoop() async {
        let interval = settings.data.editAutoSaveSeconds
        guard interval > 0 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            if Task.isCancelled { break }
            sync()
        }
    }

    private func flushIfNeeded() {
        guard hasChanges else { return }
        // 直接关闭（下滑手势）时兜底存一次，避免自动保存还没到点就没了。
        sync()
    }

    // MARK: - 数据

    private var hasChanges: Bool {
        guard let draft else { return false }
        return title != draft.title
            || content != draft.content
            || mood != draft.mood
            || weather != draft.weather
            || locationName != draft.locationName
            || isTemplate != draft.isTemplate
    }

    /// 把界面上的值写回对象并落盘。
    private func sync() {
        guard let draft else { return }
        // 先记下有没有变化再写回，否则写完再比永远是「没变」，更新时间就不动了。
        let changed = hasChanges
        draft.title = title
        draft.content = content
        draft.mood = mood
        draft.weather = weather
        draft.locationName = locationName
        draft.isTemplate = isTemplate
        draft.tags = selectedTags
        if changed { draft.touch() }
        try? modelContext.save()
    }

    private func commit() {
        sync()
        dismiss()
    }

    private func discard() {
        // 新建的草稿原本就是为了自动保存才提前入库的，用户不要就删掉，
        // 否则列表里会留下一堆空白日记。
        if let draft, diary == nil, draft.title.isEmpty, draft.content.isEmpty {
            modelContext.delete(draft)
            try? modelContext.save()
        }
        dismiss()
    }

    // MARK: - 模板

    private func applyDefaultTemplateIfAvailable() {
        let id = settings.data.defaultTemplateId
        guard !id.isEmpty,
              let uuid = UUID(uuidString: id),
              let template = fetchTemplate(id: uuid) else { return }
        applyTemplate(template)
    }

    private func fetchTemplate(id: UUID) -> Diary? {
        let descriptor = FetchDescriptor<Diary>(
            predicate: #Predicate { $0.isTemplate && $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    /// 套用方式由设置决定：覆盖直接换掉正文，插入则追加在光标之后。
    private func applyTemplate(_ template: Diary) {
        switch settings.data.useTemplateMethod {
        case .cover:
            if content.isEmpty || settings.data.selectTemplateWhenCreate {
                content = template.content
            } else {
                content += "\n\n" + template.content
            }
        case .insert:
            content += content.isEmpty ? template.content : "\n\n" + template.content
        }
        if title.isEmpty, !template.title.isEmpty { title = template.title }
        if mood.isEmpty { mood = template.mood }
        if weather.isEmpty { weather = template.weather }
        if locationName.isEmpty { locationName = template.locationName }
        if selectedTags.isEmpty { selectedTags = template.tags }
        toast = ToastItem(message: "已套用模板", systemImage: "doc.on.doc")
    }

    // MARK: - 资源

    private func insertImage(_ data: Data) {
        guard let normalized = try? ResourceStore.normalizedImageData(data),
              let relativePath = try? ResourceStore.save(normalized, type: .image, fileExtension: "jpg")
        else {
            toast = ToastItem(message: "图片保存失败", systemImage: "exclamationmark.triangle")
            return
        }

        let resource = Resource(resourceUri: relativePath, type: .image)
        modelContext.insert(resource)
        draft?.resources.append(resource)

        // Markdown 引用写相对路径，渲染时再拼上沙盒根目录——
        // 这样导出的 md 文件换个设备也能对上资源目录结构。
        pendingEdit = .insertBlock("![](\(relativePath))\n")
        try? modelContext.save()
    }
}

/// 挑一个模板套用。
private struct TemplatePickerSheet: View {
    let onPick: (Diary) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Diary> { $0.isTemplate },
           sort: [SortDescriptor(\Diary.updateTime, order: .reverse)])
    private var templates: [Diary]

    var body: some View {
        NavigationStack {
            List {
                if templates.isEmpty {
                    Text("还没有模板")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(templates) { template in
                        Button {
                            onPick(template)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(template.displayTitle.isEmpty ? "无标题模板" : template.displayTitle)
                                    .foregroundStyle(.primary)
                                Text(template.plainSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("套用模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
