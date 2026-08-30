import SwiftData
import SwiftUI

/// 筛选面板。对应原项目首页 `FilterConditionChipGroup` + 筛选弹窗的组合。
///
/// 四个维度（标签 / 时间 / 文件 / 置顶）在同一个 sheet 里一起调，
/// 比 chip 一个个点更快，也更符合 iOS 的表单习惯。
struct DiaryFilterSheet: View {
    @Binding var criteria: DiaryCriteria

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.name) private var allTags: [Tag]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("只看置顶", isOn: $criteria.pinnedOnly)
                }

                Section("时间") {
                    Picker("范围", selection: $criteria.timeRange) {
                        ForEach(DiaryTimeRange.allCases) { range in
                            Label(range.rawValue, systemImage: range.systemImage).tag(range)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("文件") {
                    Picker("类型", selection: $criteria.resourceFilter) {
                        ForEach(DiaryResourceFilter.allCases) { filter in
                            Label(filter.rawValue, systemImage: filter.systemImage).tag(filter)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("标签") {
                    if allTags.isEmpty {
                        Text("还没有标签")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(allTags) { tag in
                            Toggle(isOn: tagBinding(tag)) {
                                HStack {
                                    Text(tag.name)
                                    Spacer()
                                    Text("\(tag.diaries.count)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("选中多个标签时，命中任意一个即可。")
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if criteria.isActive {
                        Button("清空") { criteria = DiaryCriteria() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func tagBinding(_ tag: Tag) -> Binding<Bool> {
        Binding(
            get: { criteria.tagIDs.contains(tag.id) },
            set: { isOn in
                if isOn {
                    criteria.tagIDs.insert(tag.id)
                } else {
                    criteria.tagIDs.remove(tag.id)
                }
            }
        )
    }
}
