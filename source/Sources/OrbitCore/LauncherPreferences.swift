import Foundation

public struct LauncherPreferences: Codable, Equatable {
    public var holdDuration: Double = 1
    public var dialScale: Double = 1
    public init() {}
    public var effectiveHoldDuration: Double { holdDuration.isFinite ? min(5, max(0.3, holdDuration)) : 1 }
    public var effectiveDialScale: Double { dialScale.isFinite ? min(1.5, max(0.75, dialScale)) : 1 }
    enum CodingKeys: String, CodingKey { case holdDuration, dialScale }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        holdDuration = try container.decodeIfPresent(Double.self, forKey: .holdDuration) ?? 1
        dialScale = try container.decodeIfPresent(Double.self, forKey: .dialScale) ?? 1
    }
}
