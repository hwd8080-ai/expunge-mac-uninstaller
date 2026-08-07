import Foundation

/// 通过 `npm ls -g --json` 检测全局安装的 npm 包。
struct NpmScanner: Scanner {
    let name = "NpmScanner"

    func scan(query: ScanQuery) async -> [Artifact] {
        guard !query.isEmpty else { return [] }
        guard let npmPath = locateNpm() else { return [] }
        var results: [Artifact] = []

        guard let json = InventoryCache.shared.shell(npmPath, ["ls", "-g", "--json", "--depth=0"]),
              let data = json.data(using: .utf8) else { return [] }

        // npm ls 的 JSON 顶层是 { dependencies: { pkg: {version, ...}, ... } }
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let deps = root["dependencies"] as? [String: Any] {
            for (pkgName, info) in deps {
                guard query.matches(pkgName) else { continue }
                let infoDict = info as? [String: Any]
                let version = infoDict?["version"] as? String ?? "?"
                let resolvedPath: String
                if let p = infoDict?["path"] as? String {
                    resolvedPath = p
                } else if let rootPath = InventoryCache.shared.shell(npmPath, ["root", "-g"])?.trimmingCharacters(in: .whitespacesAndNewlines), !rootPath.isEmpty {
                    resolvedPath = "\(rootPath)/\(pkgName)"
                } else {
                    resolvedPath = "npm global: \(pkgName)"
                }
                let size: Int64 = (try? URL(fileURLWithPath: resolvedPath).directorySize()) ?? 0
                results.append(Artifact(
                    category: .npmGlobal,
                    path: resolvedPath,
                    size: size,
                    risk: .safe,
                    meta: "v\(version)"
                ))
            }
        }
        return results
    }

    private func locateNpm() -> String? {
        let candidates = [
            "/opt/homebrew/bin/npm",
            "/usr/local/bin/npm",
            "\(NSHomeDirectory())/.nvm/versions/node/current/bin/npm"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        // 兜底：which npm
        return Shell.run("/usr/bin/env", ["which", "npm"])
    }
}
