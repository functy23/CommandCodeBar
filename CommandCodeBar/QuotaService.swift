import Foundation

enum QuotaError: LocalizedError {
    case noAPIKey
    case authRejected(Int)
    case httpStatus(Int)
    case network(String)
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "未找到 Command Code API Key"
        case .authRejected(let status):
            return "API Key 被拒绝（HTTP \(status)）"
        case .httpStatus(let status):
            return "Command Code 服务器错误（HTTP \(status)）"
        case .network(let message):
            return "网络错误：\(message)"
        case .unexpectedResponse:
            return "Command Code 返回了无法识别的数据"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noAPIKey:
            return "先完成 Command Code CLI 登录（生成 ~/.commandcode/auth.json），或在设置中手动粘贴 API Key。"
        default:
            return nil
        }
    }
}

/// Command Code 额度 API 客户端。
/// 接口与字段对齐 Command Code CLI 的 /usage 与 pi-commandcode-provider 的实现：
/// GET /alpha/whoami、/alpha/billing/credits、/alpha/billing/subscriptions、/alpha/usage/summary
struct QuotaService {
    static let apiBase = URL(string: "https://api.commandcode.ai")!

    enum KeySource: Equatable {
        case environment
        case customSetting
        case file(String)
        case none

        var summary: String {
            switch self {
            case .environment: return "环境变量 COMMAND_CODE_API_KEY"
            case .customSetting: return "设置中手动配置的 Key"
            case .file(let path): return path
            case .none: return "未找到"
            }
        }
    }

    /// 凭据文件查找顺序，与 pi-commandcode-provider 支持的 JSON 形状一致：
    /// {"apiKey": "user_..."} / {"command-code": {"key": "user_..."}} / {"commandcode": "user_..."}
    private static let credentialFiles = [
        ".commandcode/auth.json",
        ".pi/agent/auth.json",
        ".omp/agent/auth.json",
    ]

    func resolveKey() -> (key: String, source: KeySource)? {
        if let key = ProcessInfo.processInfo.environment["COMMAND_CODE_API_KEY"], !key.isEmpty {
            return (key, .environment)
        }
        if let key = UserDefaults.standard.string(forKey: "customAPIKey"), !key.isEmpty {
            return (key, .customSetting)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        for relative in Self.credentialFiles {
            let url = home.appendingPathComponent(relative)
            guard let data = try? Data(contentsOf: url),
                  let key = Self.extractKey(from: data), !key.isEmpty else { continue }
            return (key, .file(url.path))
        }
        return nil
    }

    static func extractKey(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let apiKey = object["apiKey"] as? String { return apiKey }
        if let entry = object["command-code"] as? [String: Any], let key = entry["key"] as? String {
            return key
        }
        if let key = object["commandcode"] as? String { return key }
        return nil
    }

    // MARK: - 抓取

    func fetchQuota() async throws -> (snapshot: QuotaSnapshot, source: KeySource) {
        guard let (apiKey, source) = resolveKey() else { throw QuotaError.noAPIKey }

        let whoami = try await get(WhoamiResponse.self, path: "alpha/whoami", apiKey: apiKey)
        guard let whoami else { throw QuotaError.unexpectedResponse }

        let query: [String: String] = {
            if let orgID = whoami.org?.id, !orgID.isEmpty {
                return ["orgId": orgID]
            }
            return [:]
        }()

        async let creditsTask = get(CreditsResponse.self, path: "alpha/billing/credits", query: query, apiKey: apiKey)
        async let subscriptionTask = get(SubscriptionResponse.self, path: "alpha/billing/subscriptions", query: query, apiKey: apiKey)
        async let summaryTask = get(UsageSummaryResponse.self, path: "alpha/usage/summary", query: query, apiKey: apiKey)

        let credits = try await creditsTask
        let subscription = try await subscriptionTask
        let summary = try await summaryTask

        guard let creditData = credits?.credits else { throw QuotaError.unexpectedResponse }

        func makeWindow(_ raw: CreditsResponse.WindowLimit?) -> QuotaWindow? {
            guard let raw, let used = raw.used, let cap = raw.cap, cap > 0 else { return nil }
            return QuotaWindow(used: used, cap: cap, resetAt: Self.date(fromMilliseconds: raw.resetAt))
        }

        let accountName = whoami.user?.name ?? whoami.user?.userName ?? whoami.org?.login

        let snapshot = QuotaSnapshot(
            accountName: accountName,
            planId: subscription?.data?.planId,
            planStatus: subscription?.data?.status,
            monthlyCreditsRemaining: creditData.monthlyCredits ?? 0,
            purchasedCreditsRemaining: creditData.purchasedCredits ?? 0,
            freeCreditsRemaining: creditData.freeCredits ?? 0,
            fiveHour: makeWindow(credits?.windowLimits?.fiveHour),
            weekly: makeWindow(credits?.windowLimits?.weekly),
            periodStart: Self.parseISO(subscription?.data?.currentPeriodStart),
            periodEnd: Self.parseISO(subscription?.data?.currentPeriodEnd),
            periodRequests: summary?.totalCount.map { Int($0) },
            periodTokensIn: summary?.totalTokensIn.map { Int($0) },
            periodTokensOut: summary?.totalTokensOut.map { Int($0) },
            periodCost: summary?.totalCost,
            fetchedAt: Date()
        )
        return (snapshot, source)
    }

    // MARK: - 网络

    private func get<T: Decodable>(
        _ type: T.Type,
        path: String,
        query: [String: String] = [:],
        apiKey: String
    ) async throws -> T? {
        var components = URLComponents(
            url: Self.apiBase.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty {
            components?.queryItems = query
                .map { URLQueryItem(name: $0.key, value: $0.value) }
                .sorted { $0.name < $1.name }
        }
        guard let url = components?.url else { throw QuotaError.unexpectedResponse }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw QuotaError.unexpectedResponse }
            guard (200 ..< 300).contains(http.statusCode) else {
                if http.statusCode == 401 || http.statusCode == 403 {
                    throw QuotaError.authRejected(http.statusCode)
                }
                throw QuotaError.httpStatus(http.statusCode)
            }
            if data.isEmpty { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        } catch let error as QuotaError {
            throw error
        } catch {
            throw QuotaError.network(error.localizedDescription)
        }
    }

    // MARK: - 解析工具

    /// resetAt 为毫秒时间戳；对秒级时间戳做兼容
    static func date(fromMilliseconds value: Double?) -> Date? {
        guard let value, value > 0 else { return nil }
        if value >= 1e12 {
            return Date(timeIntervalSince1970: value / 1000)
        }
        return Date(timeIntervalSince1970: value)
    }

    private static let fractionalISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let plainISOFormatter = ISO8601DateFormatter()

    static func parseISO(_ value: String?) -> Date? {
        guard let value else { return nil }
        return fractionalISOFormatter.date(from: value) ?? plainISOFormatter.date(from: value)
    }
}
