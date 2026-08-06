import Foundation

/// 通过 `pipx list --json` 检测 pipx 管理的 Python 工具。
struct PipxScanner: Scanner {
    let name = "PipxScanner"

    func scan(query: ScanQuery) async -> [Artifact] {
        guard !query.isEmpty else { return [] }
        guard let pipxPath = locatePipx() else { return [] }
        var results: [Artifact] = []

        guard let json = InventoryCache.shared.shell(pipxPath, ["list", "--json"]),
              let data = json.data(using: .utf8) else { return [] }

        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let venvs = root["venvs"] as? [String: Any] {
            for (pkgName, _) in venvs {
                guard query.matches(pkgName) else { continue }
                let venvPath = pipxVenvPath(for: pkgName, pipx: pipxPath) ?? "pipx venv: \(pkgName)"
                let size = (try? URL(fileURLWithPath: venvPath).directorySize()) ?? 0
                results.append(Artifact(
                    category: .pipxVenv,
                    path: venvPath,
                    size: size,
                    risk: .safe,
                    meta: "package: \(pkgName)"
                ))
            }
        }
        return results
    }

    private func pipxVenvPath(for pkg: String, pipx: String) -> String? {
        // pipx 默认 venv 在 ~/.local/pipx/venvs/<pkg>
        return "\(NSHomeDirectory())/.local/pipx/venvs/\(pkg)"
    }

    private func locatePipx() -> String? {
        let candidates = [
            "/opt/homebrew/bin/pipx",
            "/usr/local/bin/pipx",
            "\(NSHomeDirectory())/.local/bin/pipx"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return Shell.run("/usr/bin/env", ["which", "pipx"])
    }
}
