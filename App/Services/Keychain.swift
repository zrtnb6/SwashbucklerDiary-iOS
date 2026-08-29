import Foundation
import Security

/// 极简 Keychain 封装，用于保存 WebDAV 密码。
///
/// 原版把整个 `WebDavConfig`（含明文密码）序列化成 JSON 存进 Preferences，
/// 备份文件里、越狱设备上都能直接翻出来。这里改成存钥匙串，
/// 并标记为 `WhenUnlockedThisDeviceOnly`——不随 iCloud 备份同步。
enum Keychain {
    enum KeychainError: LocalizedError {
        case encodingFailed
        case decodingFailed
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .encodingFailed:
                return "密码无法编码成 UTF-8 数据"
            case .decodingFailed:
                return "钥匙串中的数据无法解码"
            case .unexpectedStatus(let status):
                return "钥匙串操作失败（状态码 \(status)）"
            }
        }
    }

    private static var service: String {
        Bundle.main.bundleIdentifier ?? "com.zrtnb.swashbucklerdiary"
    }

    /// 写入（已存在则覆盖，等价于 upsert）。
    static func save(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query = baseQuery(account: account)
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 读取。不存在时返回 nil，而不是抛错。
    static func read(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        return value
    }

    static func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
