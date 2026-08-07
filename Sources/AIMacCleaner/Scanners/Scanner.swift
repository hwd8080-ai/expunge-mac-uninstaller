import Foundation

/// 扫描器协议。所有扫描器只读、不修改文件系统。
protocol Scanner {
    var name: String { get }
    /// 按解析后的查询条件扫描。
    func scan(query: ScanQuery) async -> [Artifact]
}

extension Scanner {
    /// 兼容旧的字符串入口（CLI 关键词模式、自检直接传 target 时用）。
    func scan(for target: String) async -> [Artifact] {
        await scan(query: ScanQuery(raw: target))
    }
}
