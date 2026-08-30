import SwiftUI

/// 日记卡片。
///
/// **这里刻意不用 Liquid Glass。** 滚动内容里的每张卡片都做玻璃，叠在一起既糊又卡，
/// 而且完全不是 iOS 26 的样子——Apple 把玻璃留给悬浮控件层，内容层保持实心、
/// 靠大圆角和留白建立层次。真正带玻璃感的只有贴在卡片上的心情 / 天气 chip，
/// 那是名副其实「浮」在内容之上的小元素。
struct DiaryCard: View {
    let diary: Diary

    @Environment(AppSettings.self) private var settings

    private let cornerRadius: CGFloat = 24

    private var card: SettingsData { settings.data }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            topRow
            titleLine
            if !diary.plainSummary.isEmpty {
                summaryLine
            }
            bottomRow
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundFill)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        }
        .overlay(alignment: .leading) {
            if diary.isPinned {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 16)
            }
        }
    }

    private var backgroundFill: Color {
        diary.isPinned
            ? Color.accentColor.opacity(0.10)
            : Color(.secondarySystemGroupedBackground)
    }

    // MARK: - 顶部：日期 + 状态标 + 心情 / 天气

    private var topRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(diary.updateTime.formatted(with: card.cardTimeFormat))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if !Calendar.current.isDateInToday(diary.updateTime) {
                Text(diary.updateTime.diaryTimeText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            badgeRow

            Spacer(minLength: 4)

            if card.cardShowIcon {
                if !diary.mood.isEmpty {
                    GlassChip(text: diary.mood, systemImage: diary.moodSymbol)
                }
                if !diary.weather.isEmpty {
                    GlassChip(text: diary.weather, systemImage: diary.weatherSymbol)
                }
            }
        }
    }

    /// 模板 / 私密两种状态标。置顶已经有左侧色条了，不再重复占位置。
    @ViewBuilder
    private var badgeRow: some View {
        if diary.isTemplate {
            statusBadge("模板", systemImage: "doc.on.doc", tint: .indigo)
        }
        if diary.isPrivate {
            statusBadge("私密", systemImage: "lock", tint: .orange)
        }
    }

    private func statusBadge(_ text: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(tint.opacity(0.16), in: Capsule())
        .foregroundStyle(tint)
    }

    // MARK: - 标题

    private var titleLine: some View {
        // `cardDefaultTitle` 关掉后，没写标题就是真没标题，不拿首行凑数。
        let text = card.cardDefaultTitle ? diary.displayTitle : diary.title
        return Text(text.isEmpty ? "无标题" : text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(text.isEmpty ? .tertiary : .primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 摘要

    private var summaryLine: some View {
        Text(diary.plainSummary)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 底部：位置 / 标签 / 资源 / 字数

    private var bottomRow: some View {
        HStack(spacing: 10) {
            if card.cardShowLocation, !diary.locationName.isEmpty {
                Label(diary.locationName, systemImage: "location")
                    .lineLimit(1)
            }

            if card.cardShowTags, !diary.tags.isEmpty {
                tagRow
            }

            if !diary.resources.isEmpty {
                resourceRow
            }

            Spacer(minLength: 4)

            Text("\(diary.wordCount) 字")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var tagRow: some View {
        HStack(spacing: 5) {
            ForEach(diary.tags.prefix(2)) { tag in
                Text(tag.name)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.14), in: Capsule())
            }
            if diary.tags.count > 2 {
                Text("+\(diary.tags.count - 2)")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// 卡片上只标资源「类型」，不加载缩略图——列表滚动时解码图片会掉帧。
    private var resourceRow: some View {
        HStack(spacing: 6) {
            ForEach(diary.resourceSymbols, id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
            }
            if diary.resources.count > diary.resourceSymbols.count {
                Text("×\(diary.resources.count)")
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    let diary = Diary(title: "雨后的巷子", content: "今天下了一整天的雨。\n傍晚出门的时候，巷子里的青石板还泛着水光。")
    diary.mood = "平静"
    diary.weather = "小雨"
    diary.locationName = "杭州"
    diary.isPinned = true

    return DiaryCard(diary: diary)
        .padding()
        .background(Color(.systemGroupedBackground))
        .environment(AppSettings.shared)
}
