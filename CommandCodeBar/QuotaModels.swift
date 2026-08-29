import Foundation

// MARK: - API 响应（对应 api.commandcode.ai /alpha/* 接口，字段按实际返回宽松解码）
// nonisolated：解码在并发上下文中进行，不能受 MainActor 隔离约束

nonisolated struct WhoamiResponse: Decodable {
    struct User: Decodable {
        var id: String?
        var name: String?
        var userName: String?
        var email: String?
    }

    struct Org: Decodable {
        var id: String?
        var login: String?
    }

    var user: User?
    var org: Org?
}

nonisolated struct CreditsResponse: Decodable {
    struct Credits: Decodable {
        var monthlyCredits: Double?
        var purchasedCredits: Double?
        var freeCredits: Double?
        var belowThreshold: Bool?
        var creditThreshold: Double?
    }

    struct WindowLimit: Decodable {
        var used: Double?
        var cap: Double?
        var resetAt: Double?
        var exceeded: Bool?
    }

    struct WindowLimits: Decodable {
        var limited: Bool?
        var fiveHour: WindowLimit?
        var weekly: WindowLimit?
    }

    var credits: Credits?
    var windowLimits: WindowLimits?
}

nonisolated struct SubscriptionResponse: Decodable {
    struct Data: Decodable {
        var planId: String?
        var status: String?
        var currentPeriodStart: String?
        var currentPeriodEnd: String?
    }

    var data: Data?
}

nonisolated struct UsageSummaryResponse: Decodable {
    var totalCost: Double?
    var totalCount: Double?
    var totalTokens: Double?
    var totalTokensIn: Double?
    var totalTokensOut: Double?
    var averageCost: Double?
}

// MARK: - 领域模型

/// 一个用量窗口（5 小时 / 每周），used/cap 单位为额度（≈ 美元）
struct QuotaWindow: Codable, Equatable {
    var used: Double
    var cap: Double
    var resetAt: Date?

    var usedFraction: Double { cap > 0 ? min(max(used / cap, 0), 1) : 0 }
    var remainingFraction: Double { 1 - usedFraction }
}

/// 一次成功抓取后的完整快照。刷新失败时 UI 继续展示上一次快照（对齐 TokenBar 行为）。
struct QuotaSnapshot: Codable, Equatable {
    var accountName: String?
    var planId: String?
    var planStatus: String?
    var monthlyCreditsRemaining: Double
    var purchasedCreditsRemaining: Double
    var freeCreditsRemaining: Double
    var fiveHour: QuotaWindow?
    var weekly: QuotaWindow?
    var periodStart: Date?
    var periodEnd: Date?
    var periodRequests: Int?
    var periodTokensIn: Int?
    var periodTokensOut: Int?
    var periodCost: Double?
    var fetchedAt: Date

    var creditsRemaining: Double {
        monthlyCreditsRemaining + purchasedCreditsRemaining + freeCreditsRemaining
    }

    var periodRequestsText: String? { periodRequests.map { Fmt.grouped($0) } }
    var periodTokensText: String? { periodTokensIn.map { Fmt.compact(Double($0)) } }
    var periodCostText: String? { periodCost.map { "$" + Fmt.credits($0) } }
}
