import Foundation

/// 扫描 ~/Library/LaunchAgents 和 /Library/LaunchAgents 下的 plist。
/// 通过解析 plist 的 Label 字段匹配 target。
struct LaunchAgentScanner: Scanner {
    let name = "LaunchAgentScanner"

    let searchPaths: [String] = [
        "\(NSHomeDirectory())/Library/LaunchAgents",
        "/Library/LaunchAgents",
        "/Library/LaunchDaemons"
    ]

    func scan(query: ScanQuery) async -> [Artifact] {
        guard !query.isEmpty else { return [] }
        var results: [Artifact] = []

        for dir in searchPaths {
            let url = URL(fileURLWithPath: dir)
            guard let plists = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for plist in plists where plist.pathExtension == "plist" {
                let label = readLabel(from: plist) ?? ""
                let program = readProgram(from: plist) ?? ""
                let name = plist.deletingPathExtension().lastPathComponent

                if query.matches(label) || query.matches(program) || query.matches(name) {
                    let size = Int64((try? plist.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                    results.append(Artifact(
                        category: .launchAgent,
                        path: plist.path,
                        size: size,
                        risk: .safe,
                        meta: label.isEmpty ? nil : "Label: \(label)"
                    ))
                }
            }
        }
        return results
    }

    private func readLabel(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])?["Label"] as? String
    }

    private func readProgram(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]) ?? [:]
        if let prog = plist["Program"] as? String { return prog }
        if let args = plist["ProgramArguments"] as? [String], let first = args.first { return first }
        return nil
    }
}
