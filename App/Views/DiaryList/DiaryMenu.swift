import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 长按日记卡片弹出的菜单，对齐原项目 `DiaryMenu` 的十项：
/// 标签 / 复制 / 删除 / 置顶 / 导出 / 排序 / 复制引用 / 复制链接 / 设为默认模板 / 私密。
///
/// 做成 `ViewModifier` 是因为这些动作各自要挂 sheet、确认弹窗、toast，
/// 塞进调用点会把列表视图撑成一团。
@MainActor
struct DiaryMenuModifier: ViewModifier {
    let diary: Diary

    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var settings

    @State private var showTagPicker = false
    @State private var showExportPicker = false
    @State private var sharePayload: SharePayload?
    @State private var showDeleteConfirm = false
    @State private var toast: ToastItem?

    func body(content: Content) -> some View {
        content
            .contextMenu { menu }
            .toast($toast)
            .sheet(isPresented: $showTagPicker) {
                TagPickerSheet(diary: diary)
            }
            .confirmationDialog("导出这篇日记", isPresented: $showExportPicker, titleVisibility: .visible) {
                ForEach(DiaryExporter.ExportFormat.allCases) { format in
                    Button(format.rawValue) { export(as: format) }
                }
                Button("取消", role: .cancel) {}
            }
            .confirmationDialog("删除这篇日记？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) { delete() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("「\(diary.displayTitle)」将被删除，且无法恢复。")
            }
            .sheet(item: $sharePayload) { payload in
                ActivitySheet(items: payload.items)
            }
    }

    // MARK: - 菜单

    @ViewBuilder
    private var menu: some View {
        Button { showTagPicker = true } label: {
            Label("标签", systemImage: "tag")
        }

        Button { togglePin() } label: {
            Label(diary.isPinned ? "取消置顶" : "置顶",
                  systemImage: diary.isPinned ? "pin.slash" : "pin")
        }

        Button { copyDiary() } label: {
            Label("复制", systemImage: "doc.on.doc")
        }

        Button { showExportPicker = true } label: {
            Label("导出", systemImage: "square.and.arrow.up")
        }

        Menu {
            Picker("排序", selection: sortBinding) {
                ForEach([SortField.updateTime, SortField.createTime, SortField.name, SortField.count], id: \.self) { field in
                    Text(field.displayName).tag(field)
                }
            }
            Toggle("升序", isOn: ascendingBinding)
        } label: {
            Label("排序", systemImage: "arrow.up.arrow.down")
        }

        Button { copyReference() } label: {
            Label("复制引用", systemImage: "quote.bubble")
        }

        Button { copyLink() } label: {
            Label("复制链接", systemImage: "link")
        }

        if diary.isTemplate {
            Button { setDefaultTemplate() } label: {
                Label(settings.data.defaultTemplateId == diary.id.uuidString
                      ? "已是默认模板" : "设为默认模板",
                      systemImage: "star")
            }
        }

        Button { togglePrivate() } label: {
            Label(diary.isPrivate ? "取消私密" : "设为私密",
                  systemImage: diary.isPrivate ? "lock.open" : "lock")
        }

        Divider()

        Button(role: .destructive) { showDeleteConfirm = true } label: {
            Label("删除", systemImage: "trash")
        }
    }

    // MARK: - 绑定

    private var sortBinding: Binding<SortField> {
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

    // MARK: - 动作

    private func togglePin() {
        diary.isPinned.toggle()
        diary.touch()
        try? modelContext.save()
    }

    private func togglePrivate() {
        diary.isPrivate.toggle()
        try? modelContext.save()
    }

    private func copyDiary() {
        let copy = diary.makeCopy()
        modelContext.insert(copy)
        try? modelContext.save()
        toast = ToastItem(message: "已复制日记", systemImage: "doc.on.doc")
    }

    private func setDefaultTemplate() {
        settings.data.defaultTemplateId = diary.id.uuidString
        toast = ToastItem(message: "已设为默认模板", systemImage: "star.fill")
    }

    /// 复制引用：把 Markdown 引用语法塞进剪贴板，粘到别的日记里就能跳转回来。
    private func copyReference() {
        let reference = "[\(diary.displayTitle)](\(Self.urlScheme(for: diary)))"
        UIPasteboard.general.string = reference
        toast = .copied("引用")
    }

    private func copyLink() {
        UIPasteboard.general.string = Self.urlScheme(for: diary)
        toast = .copied("链接")
    }

    private func export(as format: DiaryExporter.ExportFormat) {
        guard let url = DiaryExporter.writeTemporaryFile(for: diary, format: format) else { return }
        sharePayload = SharePayload([url])
    }

    private func delete() {
        modelContext.delete(diary)
        try? modelContext.save()
    }

    /// 原项目 `UrlSchemePage` 的链接格式，用于快捷指令跳转。
    private static func urlScheme(for diary: Diary) -> String {
        "\(AppSettings.shared.data.urlSchemePrefix)://diary/\(diary.id.uuidString)"
    }
}

extension View {
    func diaryMenu(_ diary: Diary) -> some View {
        modifier(DiaryMenuModifier(diary: diary))
    }
}
