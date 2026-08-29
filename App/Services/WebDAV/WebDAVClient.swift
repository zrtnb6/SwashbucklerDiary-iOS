import Foundation

/// WebDAV 上的一个远程文件。
struct WebDAVFile: Identifiable, Hashable, Sendable {
    let name: String
    let path: String
    let isCollection: Bool
    let size: Int64?
    let lastModified: Date?

    var id: String { path }
}

/// WebDAV 客户端。
///
/// 用 actor 隔离来串行化所有请求。原版在没有并发锁的情况下共享一个 HttpClient，
/// 配置变更与上传下载会互相打架；而且旧 client 从不释放，反复配置会泄漏连接。
///
/// 针对原版实现的修正：
/// - 路径逐段百分号编码（原版直接拼字符串，中文 / 空格文件名必然失败）
/// - 递归创建目录（原版 MKCOL 只建单层，父目录不存在就 409）
/// - 预发送 Basic 认证（默认的挑战-响应会先吃一个 401，坚果云等服务器不友好）
/// - 显式超时、结构化错误（原版把响应对象 ToString 抛给用户）
actor WebDAVClient {
    private let base: URL
    private let account: String
    private let password: String
    private let remoteFolder: String
    private let session: URLSession

    init(config: WebDAVConfig, password: String) throws {
        let address = config.normalizedServerAddress
        guard let url = URL(string: address), url.scheme != nil, url.host != nil else {
            throw WebDAVError.invalidURL(address)
        }
        // 明文 http 会把 Basic 凭据直接暴露在链路上，直接拒绝。
        guard url.scheme?.lowercased() == "https" else {
            throw WebDAVError.insecureScheme
        }
        guard !config.account.isEmpty, !password.isEmpty else {
            throw WebDAVError.missingCredentials
        }

        self.base = url
        self.account = config.account
        self.password = password
        self.remoteFolder = config.normalizedRemoteFolder

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - 对外操作

    /// 确保远程目录存在，逐级创建。
    func ensureRemoteFolderExists() async throws {
        let components = remoteFolder
            .split(separator: "/")
            .map(String.init)

        var accumulated: [String] = []
        for component in components {
            accumulated.append(component)
            if try await exists(accumulated) { continue }
            try await makeCollection(accumulated)
        }
    }

    /// 列出远程目录里的文件，按修改时间倒序。
    func listFiles() async throws -> [WebDAVFile] {
        let url = try url(for: [remoteFolder])
        var request = authorizedRequest(url: url, method: "PROPFIND")
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.setValue("application/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(Self.propfindBody.utf8)

        let (data, response) = try await perform(request)
        try validate(response)
        return try WebDAVPropfind.parse(data, folder: remoteFolder)
    }

    func download(fileName: String) async throws -> Data {
        let url = try url(for: [remoteFolder, fileName])
        let request = authorizedRequest(url: url, method: "GET")
        let (data, response) = try await perform(request)
        try validate(response)
        return data
    }

    /// 上传。会先确保目标目录存在——原版直接 PUT，目录没了就 409。
    func upload(data: Data, fileName: String) async throws {
        try await ensureRemoteFolderExists()
        let url = try url(for: [remoteFolder, fileName])
        var request = authorizedRequest(url: url, method: "PUT")
        request.setValue("application/zip", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await session.upload(for: request, from: data)
        try validate(response)
    }

    func delete(fileName: String) async throws {
        let url = try url(for: [remoteFolder, fileName])
        let request = authorizedRequest(url: url, method: "DELETE")
        let (_, response) = try await perform(request)
        try validate(response)
    }

    /// 释放底层连接。URLSession 会自己 retain，不 invalidate 就会泄漏。
    func shutdown() {
        session.invalidateAndCancel()
    }

    // MARK: - 请求构造

    private func url(for components: [String]) throws -> URL {
        let basePath = base.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let segments = ([basePath] + components).filter { !$0.isEmpty }

        var builder = URLComponents()
        builder.scheme = base.scheme
        builder.host = base.host
        builder.port = base.port
        builder.percentEncodedPath = "/" + segments
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
            .joined(separator: "/")

        guard let url = builder.url else {
            throw WebDAVError.invalidURL(base.absoluteString)
        }
        return url
    }

    /// 预置 Authorization 头，省掉一次 401 往返。
    private func authorizedRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        let credential = Data("\(account):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(credential)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            throw WebDAVError.transport(error)
        } catch {
            throw error
        }
    }

    // MARK: - 目录

    private func exists(_ components: [String]) async throws -> Bool {
        let url = try url(for: components)
        var request = authorizedRequest(url: url, method: "PROPFIND")
        request.setValue("0", forHTTPHeaderField: "Depth")

        do {
            let (_, response) = try await perform(request)
            try validate(response)
            return true
        } catch WebDAVError.notFound {
            return false
        }
    }

    private func makeCollection(_ components: [String]) async throws {
        let url = try url(for: components)
        let request = authorizedRequest(url: url, method: "MKCOL")

        do {
            let (_, response) = try await perform(request)
            try validate(response)
        } catch WebDAVError.conflict {
            // 可能是并发下别人已经建好了，再确认一次再决定要不要抛。
            if try await exists(components) { return }
            throw WebDAVError.conflict(components.joined(separator: "/"))
        }
    }

    // MARK: - 响应

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw WebDAVError.malformedResponse
        }

        switch http.statusCode {
        case 200...299:
            return
        case 401, 403:
            throw WebDAVError.unauthorized
        case 404:
            throw WebDAVError.notFound(Self.readablePath(http.url))
        case 405:
            throw WebDAVError.serverStatus(code: 405,
                                           message: "服务器不允许该操作，请确认已开启 WebDAV")
        case 409:
            throw WebDAVError.conflict(Self.readablePath(http.url))
        default:
            throw WebDAVError.serverStatus(
                code: http.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            )
        }
    }

    /// `http.url?.lastPathComponent.removingPercentEncoding` 的类型是 String??，
    /// 拆成两步才拿得到干净的 String。
    private static func readablePath(_ url: URL?) -> String {
        let raw = url?.lastPathComponent ?? ""
        return raw.removingPercentEncoding ?? raw
    }

    private static let propfindBody = """
    <?xml version="1.0" encoding="utf-8" ?>
    <d:propfind xmlns:d="DAV:">
      <d:prop>
        <d:displayname/>
        <d:getcontentlength/>
        <d:getlastmodified/>
        <d:resourcetype/>
      </d:prop>
    </d:propfind>
    """
}

// MARK: - PROPFIND 响应解析

/// 解析 207 Multi-Status 响应。
enum WebDAVPropfind {
    static func parse(_ data: Data, folder: String) throws -> [WebDAVFile] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // WebDAV 的 getlastmodified 是 RFC 1123，例如 "Sun, 30 Aug 2026 01:20:44 GMT"
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

        let parser = XMLParser(data: data)
        let delegate = Delegate(formatter: formatter)
        parser.delegate = delegate

        guard parser.parse() else {
            throw WebDAVError.malformedResponse
        }

        return delegate.entries
            .filter { !$0.isCollection }
            .compactMap { entry -> WebDAVFile? in
                let rawName = (entry.href as NSString).lastPathComponent
                let name = rawName.removingPercentEncoding ?? rawName
                guard !name.isEmpty else { return nil }
                return WebDAVFile(
                    name: name,
                    path: folder + "/" + name,
                    isCollection: entry.isCollection,
                    size: entry.contentLength,
                    lastModified: entry.lastModified
                )
            }
            .sorted { ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast) }
    }

    private final class Delegate: NSObject, XMLParserDelegate, @unchecked Sendable {
        struct Entry {
            var href = ""
            var isCollection = false
            var contentLength: Int64?
            var lastModified: Date?
        }

        var entries: [Entry] = []

        private var current = Entry()
        private var elementName = ""
        private let formatter: DateFormatter

        init(formatter: DateFormatter) {
            self.formatter = formatter
        }

        func parser(_ parser: XMLParser,
                    didStartElement elementName: String,
                    namespaceURI: String?,
                    qualifiedName qName: String?,
                    attributes: [String: String] = [:]) {
            let local = Self.localName(elementName)
            self.elementName = local
            if local == "response" {
                current = Entry()
            } else if local == "collection" {
                current.isCollection = true
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            switch elementName {
            case "href":
                current.href += string
            case "getcontentlength":
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                current.contentLength = Int64(trimmed)
            case "getlastmodified":
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                current.lastModified = formatter.date(from: trimmed)
            default:
                break
            }
        }

        func parser(_ parser: XMLParser,
                    didEndElement elementName: String,
                    namespaceURI: String?,
                    qualifiedName qName: String?) {
            if Self.localName(elementName) == "response" {
                entries.append(current)
            }
            self.elementName = ""
        }

        /// 命名空间前缀不固定（d: / D: / 无前缀），统一取冒号之后的本地名。
        private static func localName(_ name: String) -> String {
            name.components(separatedBy: ":").last ?? name
        }
    }
}
