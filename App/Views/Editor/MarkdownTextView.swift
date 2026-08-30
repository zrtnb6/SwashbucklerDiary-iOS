import SwiftUI
import UIKit

/// 一次编辑操作。
///
/// SwiftUI 的 `TextEditor` 拿不到选区，工具栏就无从下手——加粗只能作用在整段，
/// 那不是编辑器。这里包一层 `UITextView`，把「当前选区 + 待执行操作」暴露给
/// SwiftUI 侧，工具栏才能真正按选区工作。
enum MarkdownEdit: Equatable {
    /// 用前后缀包住选区；没选区时插入占位文字并选中它。
    case wrap(before: String, after: String, placeholder: String)
    /// 给选区覆盖的每一行加前缀，重复点击则取消。
    case prefixLines(String)
    /// 在光标处插入一个块级片段（代码块 / 分割线 / 表格）。
    case insertBlock(String, placeholderRange: NSRange? = nil)
}

/// 支持选区操作的 Markdown 输入视图。
struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    /// 工具栏写入、视图消费后清空。用 `@Binding` 是为了让 SwiftUI 侧
    /// 只管「发指令」，具体的光标处理留在 UIKit 层。
    @Binding var pendingEdit: MarkdownEdit?

    var onSelectionChange: ((NSRange) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.allowsEditingTextAttributes = false
        // 关掉 UITextView 自带的链接自动识别：Markdown 原文里方括号和括号
        // 一旦被识别成 URL，取到的 attributedText 就和 text 对不上了。
        textView.dataDetectorTypes = []
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        guard let edit = pendingEdit else { return }
        // 先消费再执行：清空动作要异步，否则在 updateUIView 期间改 Binding 会递归。
        DispatchQueue.main.async { pendingEdit = nil }
        context.coordinator.apply(edit, to: uiView)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate {
        private var parent: MarkdownTextView

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.onSelectionChange?(textView.selectedRange)
        }

        // MARK: 执行编辑

        func apply(_ edit: MarkdownEdit, to textView: UITextView) {
            switch edit {
            case .wrap(let before, let after, let placeholder):
                wrap(textView, before: before, after: after, placeholder: placeholder)
            case .prefixLines(let prefix):
                prefixLines(textView, prefix: prefix)
            case .insertBlock(let snippet, let placeholderRange):
                insertBlock(textView, snippet: snippet, placeholderRange: placeholderRange)
            }
        }

        /// 包住选区。再点一次同样的符号会脱掉——这是所有 Markdown 编辑器的通用手感。
        private func wrap(_ textView: UITextView,
                          before: String,
                          after: String,
                          placeholder: String) {
            let nsText = textView.text as NSString
            var range = textView.selectedRange

            // 选区外已经包着同样的符号 -> 脱掉
            if range.location >= (before as NSString).length,
               range.location + range.length + (after as NSString).length <= nsText.length {
                let outerBefore = nsText.substring(
                    with: NSRange(location: range.location - (before as NSString).length,
                                  length: (before as NSString).length))
                let outerAfter = nsText.substring(
                    with: NSRange(location: range.location + range.length,
                                  length: (after as NSString).length))
                if outerBefore == before, outerAfter == after {
                    let mutable = NSMutableString(string: nsText)
                    // 先删后面再删前面，前面的位置才不会算错。
                    mutable.replaceCharacters(
                        in: NSRange(location: range.location + range.length,
                                    length: (after as NSString).length), with: "")
                    mutable.replaceCharacters(
                        in: NSRange(location: range.location - (before as NSString).length,
                                    length: (before as NSString).length), with: "")
                    textView.text = mutable as String
                    textView.selectedRange = NSRange(
                        location: range.location - (before as NSString).length,
                        length: range.length)
                    parent.text = textView.text
                    return
                }
            }

            let selected = nsText.substring(with: range)
            let body = selected.isEmpty ? placeholder : selected
            textView.text = nsText.replacingCharacters(
                in: range, with: before + body + after)
            textView.selectedRange = NSRange(location: range.location + (before as NSString).length,
                                             length: (body as NSString).length)
            parent.text = textView.text
        }

        /// 给选区覆盖的每一行加 / 去前缀。列表、引用、标题都走这里。
        private func prefixLines(_ textView: UITextView, prefix: String) {
            let nsText = textView.text as NSString
            let range = textView.selectedRange
            let lineRange = nsText.lineRange(for: range)
            let block = nsText.substring(with: lineRange)
            let lines = block.components(separatedBy: "\n")

            // 全部已经有前缀 -> 整段去掉；否则整段加上。
            let allPrefixed = lines.allSatisfy { $0.hasPrefix(prefix) }
            let updated = lines.map { line -> String in
                if allPrefixed {
                    return String(line.dropFirst(prefix.count))
                }
                return line.isEmpty ? line : prefix + line
            }.joined(separator: "\n")

            textView.text = nsText.replacingCharacters(in: lineRange, with: updated)
            let delta = (updated as NSString).length - (block as NSString).length
            textView.selectedRange = NSRange(location: range.location,
                                             length: max(0, range.length + delta))
            parent.text = textView.text
        }

        private func insertBlock(_ textView: UITextView,
                                 snippet: String,
                                 placeholderRange: NSRange?) {
            let nsText = textView.text as NSString
            let range = textView.selectedRange

            // 块级片段插在独立一行，否则会把当前行的文字劈成两半。
            let needsLeadingNewline = range.location > 0
                && !nsText.substring(with: NSRange(location: range.location - 1, length: 1))
                    .contains("\n")
            let insertion = (needsLeadingNewline ? "\n" : "") + snippet
            textView.text = nsText.replacingCharacters(in: range, with: insertion)

            if let placeholderRange {
                textView.selectedRange = NSRange(
                    location: range.location + (insertion as NSString).length
                        - (snippet as NSString).length + placeholderRange.location,
                    length: placeholderRange.length)
            } else {
                textView.selectedRange = NSRange(
                    location: range.location + (insertion as NSString).length, length: 0)
            }
            parent.text = textView.text
        }
    }
}
