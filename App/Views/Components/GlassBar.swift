import SwiftUI

/// iOS 26 Liquid Glass 的浮动控件层。
///
/// 设计原则（Apple HIG）：Liquid Glass 是给**悬浮在内容之上**的控件用的材质
/// ——工具栏、tab bar、浮动按钮、sheet 背景。滚动内容本身要保持不透明。
///
/// `GlassEffectContainer` 是这套材质真正的灵魂：它让相邻玻璃元素在靠近时
/// 像液体一样**融合**（liquid morphing）。单纯给每个元素各挂一个 `.glassEffect`
/// 是做不出这个效果的，那只会得到一堆互相独立的模糊块。
struct GlassFloatingBar<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            HStack(spacing: spacing) {
                content
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }
}

/// 玻璃图标按钮。`.buttonStyle(.glass)` 自带按压时的液态回弹反馈。
struct GlassIconButton: View {
    let systemImage: String
    var tint: Color = .primary
    let action: () -> Void

    init(_ systemImage: String, tint: Color = .primary, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 42, height: 42)
                .contentShape(Circle())
        }
        .buttonStyle(.glass)
        .tint(tint)
    }
}

/// 主行动玻璃按钮。`glassProminent` 会给它实心的高光，用来区分「新建」这类主导操作。
struct GlassProminentButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .frame(height: 42)
        }
        .buttonStyle(.glassProminent)
    }
}

/// 玻璃菜单按钮（筛选 / 排序）。
struct GlassMenuButton<Content: View>: View {
    let systemImage: String
    var isActive: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            content
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.glass)
        .tint(isActive ? Color.accentColor : .primary)
    }
}

/// 玻璃条内分隔线——细到几乎看不见，但足以把「次要操作」和「主行动」分开。
struct GlassBarDivider: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Color.primary.opacity(0.14))
            .frame(width: 1, height: 22)
            .padding(.horizontal, 2)
    }
}

/// 内容层用的小玻璃胶囊（心情 / 天气 / 标签）。
/// 这是少数允许玻璃出现在内容里的场景：它们是贴在实心卡片上的「浮起」小元素。
struct GlassChip: View {
    let text: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .glassEffect(.regular, in: Capsule())
    }
}
