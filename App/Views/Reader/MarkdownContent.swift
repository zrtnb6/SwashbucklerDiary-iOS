import SwiftUI

/// 正文的一个渲染片段。
private struct MarkdownSegment: Identifiable {
    enum Kind {
        case text(String)
        case image(String)
        case audio(String)
    }

    let id = UUID()
    let kind: Kind
}

/// Markdown 正文渲染。
///
/// `AttributedString(markdown:)` 能处理标题、强调、列表、链接，但**不认图片和音频**——
/// 它会把 `![](images/xxx.jpg)` 原样当文字显示出来。这里先把正文中
/// 的资源引用挑出来单独渲染，剩下的文本块再交给 AttributedString。
struct MarkdownContent: View {
    let content: String

    /// 排版设置：`firstLineIndent` 首行缩进、`taskListLineThrough` 任务列表删除线。
    var firstLineIndent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(segments) { segment in
                switch segment.kind {
                case .text(let text):
                    textView(text)
                case .image(let path):
                    imageView(path)
                case .audio(let path):
                    audioView(path)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 解析

    private var segments: [MarkdownSegment] {
        let pattern = "!?\\[[^\\]]*\\]\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [MarkdownSegment(kind: .text(content))]
        }

        var result: [MarkdownSegment] = []
        let nsRange = NSRange(content.startIndex..., in: content)
        var lastEnd = content.startIndex

        for match in regex.matches(in: content, range: nsRange) {
            guard let fullRange = Range(match.range, in: content),
                  let pathRange = Range(match.range(at: 1), in: content) else { continue }

            let leading = String(content[lastEnd..<fullRange.lowerBound])
            if !leading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(MarkdownSegment(kind: .text(leading)))
            }

            let path = String(content[pathRange])
            let isAudio = path.hasPrefix("audios/")
            result.append(MarkdownSegment(kind: isAudio ? .audio(path) : .image(path)))
            lastEnd = fullRange.upperBound
        }

        let trailing = String(content[lastEnd...])
        if !trailing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append(MarkdownSegment(kind: .text(trailing)))
        }

        return result
    }

    // MARK: - 渲染

    private func textView(_ text: String) -> some View {
        Group {
            if let attributed = try? AttributedString(markdown: text) {
                Text(attributed)
            } else {
                Text(text)
            }
        }
        .font(.body)
        .lineSpacing(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 首行缩进：Markdown 没有这个语法，在段落层面加。
        .padding(.leading, firstLineIndent ? 8 : 0)
    }

    private func imageView(_ path: String) -> some View {
        Group {
            if let image = UIImage(contentsOfFile: ResourceStore.url(forRelativePath: path).path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 420)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "photo.badge.exclamationmark")
                    Text("图片已丢失")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func audioView(_ path: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .foregroundStyle(Color.accentColor)
            Text(path.split(separator: "/").last.map(String.init) ?? "音频")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
