import SwiftUI

enum AppTab: Hashable {
    case diaries
    case settings
}

struct RootView: View {
    @State private var selection: AppTab = .diaries

    var body: some View {
        TabView(selection: $selection) {
            Tab("日记", systemImage: "book.closed.fill", value: AppTab.diaries) {
                DiaryListView()
            }
            Tab("设置", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        // iOS 26：向下滚动时 tab bar 自动收起成一小条，上滑再展开。
        // 把纵向空间还给内容，是这个版本最直观的体验变化之一。
        .minimizeTabBarOnScroll()
    }
}
