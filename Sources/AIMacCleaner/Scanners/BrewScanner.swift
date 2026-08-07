import Foundation

/// 通过 `brew list --json` 扫描已安装的 formula 和 cask。
struct BrewScanner: Scanner {
    let name = "BrewScanner"

    func scan(query: ScanQuery) async -> [Artifact] {
        guard !query.isEmpty else { return [] }
        let brewPath = locateBrew()
        guard let brew = brewPath else { return [] }
        var results: [Artifact] = []

        // Formula
        if let json = runShell(brew, ["list", "--formula", "--json", "--installed"]),
           let data = json.data(using: .utf8),
           let formulas = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for f in formulas {
                guard let name = f["name"] as? String else { continue }
                if query.matches(name) {
                    let prefix = (f["prefix"] as? String) ?? "/opt/homebrew/Cellar/\(name)"
                    let size = (try? URL(fileURLWithPath: prefix).directorySize()) ?? 0
                    results.append(Artifact(
                        category: .brewFormula,
                        path: prefix,
                        size: size,
                        risk: .safe
                    ))
                }
            }
        }

        // Cask
        if let json = runShell(brew, ["list", "--cask", "--json", "--installed"]),
           let data = json.data(using: .utf8),
           let casks = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for c in casks {
                // cask 的 json 顶层是 token，apps 在 apps 数组里
                let token = (c["token"] as? String) ?? ""
                let apps = (c["artifacts"] as? [[String: Any]]) ?? []
                let appPaths: [String] = apps.compactMap { $0["app"] as? String }
                if query.matches(token) ||
                   appPaths.contains(where: { query.matches($0) }) {
                    let installPath = appPaths.first ?? "brew cask: \(token)"
                    let size = appPaths.first.flatMap { (try? URL(fileURLWithPath: $0).directorySize()) } ?? 0
                    results.append(Artifact(
                        category: .brewCask,
                        path: installPath,
                        size: size,
                        risk: .safe
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Helpers

    private func locateBrew() -> String? {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "/home/linuxbrew/.linuxbrew/bin/brew"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    private func runShell(_ launchPath: String, _ args: [String]) -> String? {
        // 走缓存：app 列表模式下用户会连点多个 app，不能每次都起 brew 子进程
        InventoryCache.shared.shell(launchPath, args)
    }
}
