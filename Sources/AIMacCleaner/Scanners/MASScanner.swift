import Foundation

/// 通过 `mas list` 检测 Mac App Store 安装的应用。
struct MASScanner: Scanner {
    let name = "MASScanner"

    func scan(query: ScanQuery) async -> [Artifact] {
        guard !query.isEmpty else { return [] }
        guard let masPath = locateMas() else { return [] }
        var results: [Artifact] = []

        // mas list 输出格式: "<id>  <name> (<version>)"
        guard let output = InventoryCache.shared.shell(masPath, ["list"]) else { return [] }
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let id = parts[0]
            let nameInfo = parts[1]
            let nameOnly = nameInfo.split(separator: " (").first.map(String.init) ?? nameInfo
            if query.matches(nameOnly) {
                // MAS app 实际位置在 /Applications
                let appPath = "/Applications/\(nameOnly).app"
                let size = (try? URL(fileURLWithPath: appPath).directorySize()) ?? 0
                results.append(Artifact(
                    category: .masApp,
                    path: appPath,
                    size: size,
                    risk: .safe,
                    meta: "MAS id: \(id)"
                ))
            }
        }
        return results
    }

    private func locateMas() -> String? {
        let candidates = ["/opt/homebrew/bin/mas", "/usr/local/bin/mas"]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return Shell.run("/usr/bin/env", ["which", "mas"])
    }
}
