import SwiftData
import SwiftUI

struct SettingsView: View {
    @Query private var diaries: [Diary]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    overviewCard
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                Section {
                    NavigationLink {
                        PlaceholderView(title: "WebDAV 备份",
                                        message: "同步模块正在开发中。")
                    } label: {
                        Label("WebDAV 备份", systemImage: "externaldrive.connected.to.line.below")
                    }
                } header: {
                    Text("同步")
                }

                Section {
                    NavigationLink {
                        PlaceholderView(title: "导出", message: "导出与导入正在开发中。")
                    } label: {
                        Label("导出日记", systemImage: "square.and.arrow.up")
                    }
                    NavigationLink {
                        PlaceholderView(title: "导入", message: "导出与导入正在开发中。")
                    } label: {
                        Label("导入日记", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("数据")
                }

                Section {
                    LabeledContent("版本") {
                        Text(appVersion)
                    }
                    LabeledContent("数据位置") {
                        Text("本机")
                    }
                } header: {
                    Text("关于")
                } footer: {
                    Text("所有数据只存在这台设备上，不会上传服务器。")
                }
            }
            .listSectionSpacing(18)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("设置")
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    /// 悬浮的玻璃概览面板——这类「浮在内容之上」的面板正是 Liquid Glass 的正当用法。
    private var overviewCard: some View {
        HStack(spacing: 0) {
            statItem(title: "日记", value: diaries.count)
            statItem(title: "置顶", value: diaries.filter(\.isPinned).count)
            statItem(title: "媒体", value: diaries.reduce(0) { $0 + $1.resources.count })
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func statItem(title: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct PlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "hammer")
        } description: {
            Text(message)
        }
        .navigationTitle(title)
    }
}
