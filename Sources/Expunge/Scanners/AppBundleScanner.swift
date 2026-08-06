import Foundation

/// 扫描 /Applications 和 ~/Applications 下的 .app 包。
struct AppBundleScanner: Scanner {
    let name = "AppBundleScanner"

    func scan(query: ScanQuery) async -> [Artifact] {
        guard !query.isEmpty else { return [] }

        // app 模式：目标 app 已经定位好，直接用它的路径，不需要再猜。
        if let app = query.app {
            let url = URL(fileURLWithPath: app.bundlePath)
            guard FileManager.default.fileExists(atPath: app.bundlePath) else { return [] }
            let size = (try? url.directorySize()) ?? 0
            var meta = app.bundleId
            if let v = app.version { meta = [meta, "v\(v)"].compactMap { $0 }.joined(separator: " · ") }
            return [Artifact(
                category: .appBundle,
                path: app.bundlePath,
                size: size,
                risk: .safe,
                meta: meta
            )]
        }

        // 关键词模式：按别名搜所有已装 app。
        // 用 AppInventory 而不是只比对文件名，这样搜「微信」也能命中 WeChat.app。
        var results: [Artifact] = []
        for app in AppInventory.search(query.raw) {
            let url = URL(fileURLWithPath: app.bundlePath)
            let size = (try? url.directorySize()) ?? 0
            results.append(Artifact(
                category: .appBundle,
                path: app.bundlePath,
                size: size,
                risk: .safe,
                meta: app.bundleId
            ))
        }
        return results
    }
}
