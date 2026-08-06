import Foundation

/// 扫描 shell 配置文件中的 PATH 污染（如 ~/.local/bin）。
struct ShellConfigScanner: Scanner {
    let name = "ShellConfigScanner"

    let files: [String] = [
        "\(NSHomeDirectory())/.zshrc",
        "\(NSHomeDirectory())/.zprofile",
        "\(NSHomeDirectory())/.zshenv",
        "\(NSHomeDirectory())/.bashrc",
        "\(NSHomeDirectory())/.bash_profile",
        "\(NSHomeDirectory())/.profile"
    ]

    func scan(query: ScanQuery) async -> [Artifact] {
        guard !query.isEmpty else { return [] }
        var results: [Artifact] = []

        for file in files {
            let url = URL(fileURLWithPath: file)
            guard FileManager.default.fileExists(atPath: file),
                  let content = try? String(contentsOf: url, encoding: .utf8) else { continue }

            let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
            for (idx, line) in lines.enumerated() {
                let lower = line.lowercased()
                // 只匹配明确提到 target 的行：例如 `alias mimo=...` 或 `export MIMO_xxx=...`。
                // 之前用 (line contains "path" && line contains ".local/bin") 的条件太宽，
                // 会把通用的 `export PATH="$HOME/.local/bin:$PATH"` 也当成 mimo 的痕迹——这是误报。
                let mentionsTarget = query.matches(String(line))
                let mentionsTargetPath = query.keywords.contains { kw in
                    lower.contains(".local/bin/\(kw)") || lower.contains("/\(kw)")
                }
                if mentionsTarget || mentionsTargetPath {
                    let size = Int64(line.utf8.count)
                    results.append(Artifact(
                        category: .shellRc,
                        path: "\(file):\(idx + 1)",
                        size: size,
                        risk: .uncertain,
                        meta: String(line).trimmingCharacters(in: .whitespaces)
                    ))
                }
            }
        }
        return results
    }
}
