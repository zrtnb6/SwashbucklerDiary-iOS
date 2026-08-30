import SwiftUI

/// 工具栏上的一个格式项。
struct MarkdownAction: Identifiable {
    let id: String
    let systemImage: String
    let help: String
    let edit: MarkdownEdit

    init(_ id: String, systemImage: String, help: String, edit: MarkdownEdit) {
        self.id = id
        self.systemImage = systemImage
        self.help = help
        self.edit = edit
    }
}

/// Markdown 格式工具栏。
///
/// 对齐全项目 `Vditor` 工具栏实际启用的条目。按钮多到放不下，横向滚动，
/// 按使用频率排序：加粗、斜体、标题、列表在前，表格代码块在后。
struct MarkdownToolbar: View {
    @Binding var pendingEdit: MarkdownEdit?

    private let actions: [MarkdownAction] = [
        MarkdownAction("bold", systemImage: "bold", help: "加粗",
                       edit: .wrap(before: "**", after: "**", placeholder: "加粗")),
        MarkdownAction("italic", systemImage: "italic", help: "斜体",
                       edit: .wrap(before: "*", after: "*", placeholder: "斜体")),
        MarkdownAction("strike", systemImage: "strikethrough", help: "删除线",
                       edit: .wrap(before: "~~", after: "~~", placeholder: "删除线")),
        MarkdownAction("h1", systemImage: "textformat.size.larger", help: "一级标题",
                       edit: .prefixLines("# ")),
        MarkdownAction("h2", systemImage: "textformat.size", help: "二级标题",
                       edit: .prefixLines("## ")),
        MarkdownAction("quote", systemImage: "text.quote", help: "引用",
                       edit: .prefixLines("> ")),
        MarkdownAction("ul", systemImage: "list.bullet", help: "无序列表",
                       edit: .prefixLines("- ")),
        MarkdownAction("ol", systemImage: "list.number", help: "有序列表",
                       edit: .prefixLines("1. ")),
        MarkdownAction("task", systemImage: "checklist", help: "任务列表",
                       edit: .prefixLines("- [ ] ")),
        MarkdownAction("code", systemImage: "chevron.left.forwardslash.chevron.right", help: "行内代码",
                       edit: .wrap(before: "`", after: "`", placeholder: "代码")),
        MarkdownAction("codeblock", systemImage: "curlybraces", help: "代码块",
                       edit: .insertBlock("```\n\n```", placeholderRange: NSRange(location: 4, length: 0))),
        MarkdownAction("link", systemImage: "link", help: "链接",
                       edit: .wrap(before: "[", after: "](url)", placeholder: "链接文字")),
        MarkdownAction("divider", systemImage: "minus", help: "分割线",
                       edit: .insertBlock("\n---\n")),
        MarkdownAction("table", systemImage: "tablecells", help: "表格",
                       edit: .insertBlock("""
                       | 列 1 | 列 2 |
                       | --- | --- |
                       |  |  |
                       """, placeholderRange: NSRange(location: 0, length: 0)))
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(actions) { action in
                    Button {
                        pendingEdit = action.edit
                    } label: {
                        Image(systemName: action.systemImage)
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 38, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .help(action.help)
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 40)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
