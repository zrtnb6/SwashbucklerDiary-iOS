import Foundation
import Observation

/// WebDAV 连接配置。
///
/// 密码**不**放在这里——它单独存钥匙串，避免被序列化进设置文件或备份包。
struct WebDAVConfig: Codable, Equatable, Sendable {
    /// 形如 `https://dav.example.com/dav/`
    var serverAddress: String = ""
    var account: String = ""

    /// 远程目录名。默认值沿用原版，这样老用户升级后仍能看到以前上传的备份。
    var remoteFolder: String = WebDAVConfig.defaultRemoteFolder

    static let defaultRemoteFolder = "SwashbucklerDiary"
    static let storageKey = "webdav.config"
    static let passwordAccount = "webdav.password"

    var isConfigured: Bool {
        !normalizedServerAddress.isEmpty && !account.isEmpty
    }

    var normalizedServerAddress: String {
        serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedRemoteFolder: String {
        let trimmed = remoteFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultRemoteFolder : trimmed
    }
}

/// 配置的持久化：非敏感字段存 UserDefaults，密码存钥匙串。
@Observable
final class WebDAVConfigStore {
    var config: WebDAVConfig

    init() {
        if let data = UserDefaults.standard.data(forKey: WebDAVConfig.storageKey),
           let decoded = try? JSONDecoder().decode(WebDAVConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = WebDAVConfig()
        }
    }

    /// 保存配置。密码为空时保留钥匙串里的旧值，避免清空密码字段就把凭据弄丢。
    func save(password: String) throws {
        if !password.isEmpty {
            try Keychain.save(password, account: WebDAVConfig.passwordAccount)
        }
        let data = try JSONEncoder().encode(config)
        UserDefaults.standard.set(data, forKey: WebDAVConfig.storageKey)
    }

    func loadPassword() -> String {
        (try? Keychain.read(account: WebDAVConfig.passwordAccount)) ?? ""
    }

    func clear() throws {
        try Keychain.delete(account: WebDAVConfig.passwordAccount)
        UserDefaults.standard.removeObject(forKey: WebDAVConfig.storageKey)
        config = WebDAVConfig()
    }
}
