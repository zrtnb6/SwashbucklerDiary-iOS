import SwiftUI

/// 操作回执。复制、导出这类没有视觉结果的动作，不给反馈用户会以为没点到。
struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    var message: String
    var systemImage: String = "checkmark.circle.fill"

    static func copied(_ what: String) -> ToastItem {
        ToastItem(message: "已复制\(what)", systemImage: "doc.on.doc")
    }
}

/// 轻量 toast：从底部浮起，2 秒后自散。
///
/// 做成 `ViewModifier` 而不是全局单例——单例 toast 在多个窗口 / sheet 并存时
/// 会挂错层级，Modifier 天然跟随宿主视图。
@MainActor
struct ToastModifier: ViewModifier {
    @Binding var item: ToastItem?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let item {
                    toastView(item)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 90)
                }
            }
            .animation(.spring(duration: 0.32), value: item?.id)
            .task(id: item?.id) {
                guard item != nil else { return }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation { self.item = nil }
            }
    }

    private func toastView(_ item: ToastItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.systemImage)
            Text(item.message)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}

extension View {
    func toast(_ item: Binding<ToastItem?>) -> some View {
        modifier(ToastModifier(item: item))
    }
}
