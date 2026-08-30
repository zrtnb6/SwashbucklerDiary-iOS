import SwiftUI

/// 首页的三个分页，对应原项目 `HomePage` 的 全部 / 标签 / 模板。
enum HomeTab: String, CaseIterable, Identifiable {
    case diaries = "全部"
    case tags = "标签"
    case templates = "模板"

    var id: String { rawValue }
}

/// 首页。
///
/// 三个分页用 `TabView(.page)` 承载，支持左右横滑切换；顶部再给一个分段控件
/// 作为显式入口——只靠横滑的话，用户很难发现旁边还有分页。
struct HomeView: View {
    @State private var tab: HomeTab = .diaries
    @State private var criteria = DiaryCriteria()

    var body: some View {
        NavigationStack {
            TabView(selection: $tab) {
                DiaryListContent(criteria: $criteria)
                    .tag(HomeTab.diaries)

                TagListView()
                    .tag(HomeTab.tags)

                DiaryListContent(criteria: $criteria, templatesOnly: true)
                    .tag(HomeTab.templates)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .toolbar { toolbar }
            .searchable(text: searchBinding, prompt: "搜索标题、正文、标签或位置")
            .softScrollEdge()
        }
    }

    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("分页", selection: $tab) {
                ForEach(HomeTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)
        }
    }

    /// 标签页没有列表可搜，搜索框在那里不生效也不显示——
    /// `searchable` 是挂在 NavigationStack 上的，退而求其次：标签页下把关键词清空。
    private var searchBinding: Binding<String> {
        Binding(
            get: { tab == .tags ? "" : criteria.searchText },
            set: { criteria.searchText = $0 }
        )
    }
}
