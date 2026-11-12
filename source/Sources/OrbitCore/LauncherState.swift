import Foundation

public struct AppRecord: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let path: String
    public init(id: String, name: String, path: String) { self.id = id; self.name = name; self.path = path }
}

public struct LauncherState: Codable, Equatable {
    public var slotCount = 6
    public var pinned: [AppRecord?] = [nil, nil]
    public var recent: [AppRecord] = []
    public init() {}
    public var slots: [AppRecord?] {
        let count = min(8, max(2, slotCount))
        let pins = Array((pinned + [nil, nil]).prefix(2))
        var seen = Set(pins.compactMap { $0?.id })
        let candidates = recent.filter { seen.insert($0.id).inserted }
        let tail = Array(candidates.prefix(count - 2)).map { Optional($0) }
        return pins + tail + Array(repeating: nil, count: count - 2 - tail.count)
    }
    public mutating func activate(_ app: AppRecord) {
        recent.removeAll { $0.id == app.id }
        recent.insert(app, at: 0)
        recent = Array(recent.prefix(50))
    }
    public mutating func pin(_ app: AppRecord?, at index: Int) {
        guard (0..<2).contains(index) else { return }
        pinned = Array((pinned + [nil, nil]).prefix(2))
        if let app {
            for other in 0..<2 where other != index && pinned[other]?.id == app.id { pinned[other] = nil }
        }
        pinned[index] = app
    }
}
