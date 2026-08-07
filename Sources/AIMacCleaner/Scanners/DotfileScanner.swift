import Foundation

/// 扫描 ~/ 下的点文件/目录，如 ~/.mimo、~/.cc-connect、~/.mimocode-project-id。
/// 跳过白名单中的常见目录（避免误伤 .ssh、.zsh_history 等）。
struct DotfileScanner: Scanner {
    let name = "DotfileScanner"

    let home = NSHomeDirectory()

    /// 这些目录绝对不能扫或删
    let skipNames: Set<String> = [
        ".", "..", ".Trash", ".cache", ".config", ".local", ".ssh", ".gnupg",
        ".zsh_history", ".zsh_sessions", ".bash_history", ".python_history",
        ".gitconfig", ".gitignore_global", ".git", ".npm", ".nvm", ".node_modules",
        ".cargo", ".rustup", ".rbenv", ".pyenv", ".gem", ".bundle",
        ".DS_Store", ".CFUserTextEncoding", ".vim", ".viminfo", ".lesshst",
        ".netrc", ".pgpass", ".git-credentials",
        "Library", "Documents", "Downloads", "Desktop", "Pictures", "Music", "Movies"
    ]

    func scan(query: ScanQuery) async -> [Artifact] {
        guard !query.isEmpty else { return [] }
        var results: [Artifact] = []

        let url = URL(fileURLWithPath: home)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for item in contents {
            let name = item.lastPathComponent
            guard name.hasPrefix(".") else { continue }
            if skipNames.contains(name) { continue }
            if query.matches(name) {
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let size: Int64
                if isDir {
                    size = (try? item.directorySize()) ?? 0
                } else {
                    size = Int64((try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                }
                results.append(Artifact(
                    category: .dotfile,
                    path: item.path,
                    size: size,
                    risk: .uncertain
                ))
            }
        }
        return results
    }
}
