import Foundation

/// 扫描用户下载或自安装的命令行二进制（不在 /Applications，也不在 brew）。
/// 典型案例：~/.local/bin/mimo、~/Downloads/mimo。
struct RawBinaryScanner: Scanner {
    let name = "RawBinaryScanner"

    /// 要扫的目录。
    ///
    /// `~/Downloads` 受 TCC 保护，扫它会弹「想访问「下载」文件夹中的文件」，
    /// 所以由 `Prefs.scanDownloads` 控制，**默认不扫**。理由写在 `Prefs` 里。
    /// `~/.local/bin` 不受 TCC 管，一直照扫。
    var searchPaths: [String] {
        var paths = ["\(NSHomeDirectory())/.local/bin"]
        if Prefs.scanDownloads {
            paths.append("\(NSHomeDirectory())/Downloads")
        }
        return paths
    }

    func scan(query: ScanQuery) async -> [Artifact] {
        guard !query.isEmpty else { return [] }
        var results: [Artifact] = []

        for dir in searchPaths {
            let url = URL(fileURLWithPath: dir)
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            ) else { continue }

            for item in contents {
                let name = item.lastPathComponent.lowercased()
                // 二进制保持严格匹配（精确/前缀），避免删错同名前缀的其他工具
                let hit = query.keywords.contains { kw in
                    name == kw || name.hasPrefix(kw + ".") || name == "\(kw).app"
                }
                if hit {
                    let size = Int64((try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                    results.append(Artifact(
                        category: .cliBinary,
                        path: item.path,
                        size: size,
                        risk: .safe
                    ))
                }
            }
        }
        return results
    }
}
