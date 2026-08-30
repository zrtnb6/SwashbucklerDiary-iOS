import SwiftUI

/// iOS 26 以下的系统没有 Liquid Glass，这里统一给一套「够体面」的降级外观。
///
/// 部署目标压到 18.0 是为了让包在低版本设备上也能装上；玻璃效果只在 iOS 26+
/// 出现。所有 iOS 26 专属 API 都必须走这个兜底，否则低版本设备会直接装不上。
extension View {
    /// 滚到边缘时导航栏玻璃渐隐，仅 iOS 26+。
    @ViewBuilder
    func softScrollEdge() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }

    /// 向下滚动时 tab bar 自动收起，仅 iOS 26+。
    @ViewBuilder
    func minimizeTabBarOnScroll() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// 胶囊玻璃底，仅 iOS 26+；低版本退回半透明实心胶囊。
    @ViewBuilder
    func capsuleGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: Capsule())
        } else {
            self.background(Capsule().fill(Color.primary.opacity(0.06)))
        }
    }

    /// 圆角矩形玻璃面板（设置页概览卡片那种），仅 iOS 26+。
    @ViewBuilder
    func roundedGlass(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
}

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
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                bar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        } else {
            bar
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay {
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
        }
    }

    private var bar: some View {
        HStack(spacing: spacing) {
            content
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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

    private var label: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 42, height: 42)
            .contentShape(Circle())
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) { label }
                .buttonStyle(.glass)
                .tint(tint)
        } else {
            Button(action: action) { label }
                .buttonStyle(.plain)
                .background(Circle().fill(Color.primary.opacity(0.07)))
                .tint(tint)
        }
    }
}

/// 主行动玻璃按钮。`glassProminent` 会给它实心的高光，用来区分「新建」这类主导操作。
struct GlassProminentButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    private var label: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .frame(height: 42)
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) { label }
                .buttonStyle(.glassProminent)
        } else {
            Button(action: action) { label }
                .buttonStyle(.borderedProminent)
                .clipShape(Capsule())
        }
    }
}

/// 玻璃菜单按钮（筛选 / 排序）。
struct GlassMenuButton<Content: View>: View {
    let systemImage: String
    var isActive: Bool = false
    @ViewBuilder var content: Content

    /// 自定义 init：去掉 `systemImage:` 标签，让调用点能写成
    /// `GlassMenuButton("line.3.horizontal.decrease") { ... }`。
    init(_ systemImage: String,
         isActive: Bool = false,
         @ViewBuilder content: @escaping () -> Content) {
        self.systemImage = systemImage
        self.isActive = isActive
        self.content = content()
    }

    private var label: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 42, height: 42)
            .contentShape(Circle())
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            Menu { content } label: { label }
                .buttonStyle(.glass)
                .tint(isActive ? Color.accentColor : .primary)
        } else {
            Menu { content } label: { label }
                .buttonStyle(.plain)
                .background(Circle().fill(Color.primary.opacity(0.07)))
                .tint(isActive ? Color.accentColor : .primary)
        }
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
        base.capsuleGlass()
    }

    private var base: some View {
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
    }
}
