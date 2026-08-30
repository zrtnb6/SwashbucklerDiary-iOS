import SwiftUI

/// 系统分享面板。导出日记、导出数据都走它。
struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// 分享内容的包装，供 `.sheet(item:)` 使用。
struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]

    init(_ items: [Any]) {
        self.items = items
    }
}
