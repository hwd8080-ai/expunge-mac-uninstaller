import Foundation

/// 标识一个待清理目标的元数据。
struct AppTarget: Equatable {
    let query: String        // 用户输入的关键词
    let bundleIds: [String]  // 可选：从 .app Info.plist 中读到的 bundle id
    let source: Source

    enum Source: String {
        case appBundle = "App bundle"
        case brewFormula = "Brew formula"
        case rawBinary = "Raw binary"
        case unknown = "Unknown"
    }
}
