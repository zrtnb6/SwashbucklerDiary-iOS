import SwiftUI

struct WebDAVSettingsView: View {
    @State private var store = WebDAVConfigStore()
    @State private var password = ""

    @State private var isConnecting = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    @State private var remoteFiles: [WebDAVFile] = []
    @State private var hasConnected = false

    var body: some View {
        List {
            configurationSection
            statusSection
            remoteFilesSection
        }
        .listSectionSpacing(18)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("WebDAV 备份")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { actionBar }
        .task { password = store.loadPassword() }
    }

    // MARK: - 配置

    private var configurationSection: some View {
        Section {
            TextField("https://dav.example.com/dav", text: $store.config.serverAddress)
                .keyboardType(.URL)
                .textContentType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("账号", text: $store.config.account)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("密码", text: $password)
                .textContentType(.password)

            TextField(WebDAVConfig.defaultRemoteFolder, text: $store.config.remoteFolder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("服务器")
        } footer: {
            Text("密码只存进本机钥匙串，不会写入备份文件。目录名沿用默认值即可看到旧版上传的备份。")
        }
    }

    // MARK: - 状态

    @ViewBuilder
    private var statusSection: some View {
        if let statusMessage {
            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: statusIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(statusIsError ? Color.red : Color.green)
                    Text(statusMessage)
                        .font(.footnote)
                }
            } header: {
                Text("状态")
            }
        }
    }

    // MARK: - 远程文件

    private var remoteFilesSection: some View {
        Section {
            if remoteFiles.isEmpty {
                Text(hasConnected ? "远程目录里还没有备份。" : "连接成功后会列出远程备份。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(remoteFiles) { file in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(file.name)
                                .font(.footnote)
                                .lineLimit(2)
                            if let date = file.lastModified {
                                Text(date.diaryLongText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        if let size = file.size {
                            Text(readableSize(size))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        } header: {
            Text(remoteFiles.isEmpty ? "远程备份" : "远程备份 \(remoteFiles.count)")
        }
    }

    // MARK: - 底部操作

    private var actionBar: some View {
        GlassFloatingBar(spacing: 8) {
            GlassProminentButton(isConnecting ? "连接中" : "连接并保存",
                                 systemImage: "bolt.horizontal") {
                Task { await connectAndSave() }
            }
            .disabled(isConnecting)
        }
    }

    // MARK: - 行为

    private func connectAndSave() async {
        guard !isConnecting else { return }
        isConnecting = true
        defer { isConnecting = false }

        do {
            let client = try WebDAVClient(config: store.config, password: password)
            // shutdown 是 actor 方法，defer 里不能 await，丢进 Task 异步执行。
            defer { Task { await client.shutdown() } }

            try await client.ensureRemoteFolderExists()
            let files = try await client.listFiles()

            // 只有连通了才落盘，避免把一份连不上的配置存下来。
            try store.save(password: password)

            hasConnected = true
            remoteFiles = files
            statusMessage = "连接成功，配置已保存。远程共有 \(files.count) 个备份。"
            statusIsError = false
        } catch {
            remoteFiles = []
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    private func readableSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
