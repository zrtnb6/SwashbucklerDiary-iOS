import Foundation

/// WebDAV 的结构化错误，每条都能直接展示给用户。
///
/// 原版直接把 C# 响应对象的 `ToString()` 抛出去，显示出来是一串类型名
/// （如 `WebDav.WebDavStreamResponse`），使用者完全看不懂错在哪。
/// 这里按语义分类，把状态码翻译成人话。
enum WebDAVError: LocalizedError {
    case invalidURL(String)
    case insecureScheme
    case missingCredentials
    case unauthorized
    case notFound(String)
    case conflict(String)
    case serverStatus(code: Int, message: String)
    case malformedResponse
    case transport(URLError)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let text):
            return "服务器地址无法识别：\(text)"
        case .insecureScheme:
            return "请使用 https 地址，http 会明文传输密码"
        case .missingCredentials:
            return "账号或密码为空"
        case .unauthorized:
            return "账号或密码不正确"
        case .notFound(let path):
            return "远程路径不存在：\(path)"
        case .conflict(let path):
            return "远程目录创建失败，父目录可能不存在：\(path)"
        case .serverStatus(let code, let message):
            return "服务器返回 \(code)：\(message)"
        case .malformedResponse:
            return "服务器返回的响应无法解析，它可能不是 WebDAV 服务"
        case .transport(let error):
            switch error.code {
            case .cannotConnectToHost, .cannotFindHost:
                return "连不上服务器，请检查地址和网络"
            case .timedOut:
                return "连接超时"
            case .notConnectedToInternet:
                return "当前没有网络"
            case .secureConnectionFailed:
                return "SSL 连接失败，请检查服务器证书"
            default:
                return error.localizedDescription
            }
        }
    }
}
