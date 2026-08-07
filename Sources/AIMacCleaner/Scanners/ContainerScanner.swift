import Foundation

/// 扫描沙箱容器目录。
///
/// 存在的理由：沙箱化的 app（微信、大量 Mac App Store app）把数据全放在
/// `~/Library/Containers/<bundle-id>` 和 `~/Library/Group Containers/<team-id>.<bundle-id>`，
/// 而不是 `Application Support`。v1.0 漏掉了这两处——微信的 3.4 GB 数据因此完全扫不到。
///
/// 匹配以 bundle id 为主键：容器目录名就是 bundle id，比按 app 名匹配可靠得多。
struct ContainerScanner: Scanner {
    let name = "ContainerScanner"

    struct DirSpec {
        let path: String
        let category: ArtifactCategory
    }

    var baseDirs: [DirSpec] {
        [
            DirSpec(path: "\(NSHomeDirectory())/Library/Containers", category: .container),
            DirSpec(path: "\(NSHomeDirectory())/Library/Group Containers", category: .groupContainer)
        ]
    }

    func scan(query: ScanQuery) async -> [Artifact] {
        guard !query.isEmpty else { return [] }
        var results: [Artifact] = []

        for spec in baseDirs {
            let url = URL(fileURLWithPath: spec.path)
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for item in contents {
                let dirName = item.lastPathComponent
                guard matchesContainer(dirName, query: query) else { continue }
                // 已经清空的容器空壳不再报出来。
                //
                // ~/Library/Containers 的父目录由 containermanagerd 独占管理，
                // 容器目录本身**永远删不掉**（连完全磁盘访问权限也没用）。清空内容后
                // 只剩系统账本，此时把它列出来的后果是：用户看到「还有 4 KB 残留」→
                // 再点一次删除 → 又「成功」→ 再扫还在。一个删不掉又消不掉的死循环，
                // 而那 4 KB 只是目录 inode，不含任何用户数据。
                guard !isEmptyShell(item) else { continue }

                let size = (try? item.directorySize()) ?? 0
                results.append(Artifact(
                    category: spec.category,
                    path: item.path,
                    size: size,
                    // 容器里是用户数据（聊天记录、文档），必须默认不勾选
                    risk: .userData,
                    meta: "容器数据"
                ))
            }
        }
        return results
    }

    /// 容器是否只剩系统账本（没有任何用户数据）。
    ///
    /// `containermanagerd` 会在每个容器里放
    /// `.com.apple.containermanagerd.metadata.plist`。只剩它（或彻底空）时，
    /// 这个容器对用户已经没有意义 —— 而且删不掉，所以不该继续报给用户。
    static func isEmptyShell(_ dir: URL) -> Bool {
        let fm = FileManager.default
        // 注意不能用 skipsHiddenFiles：账本本身就是点文件，跳过它会让
        // 任何「只含隐藏用户数据」的容器被误判成空壳而漏报。
        guard let items = try? fm.contentsOfDirectory(atPath: dir.path) else { return false }
        return items.allSatisfy { $0 == ".com.apple.containermanagerd.metadata.plist" }
    }

    private func isEmptyShell(_ dir: URL) -> Bool { Self.isEmptyShell(dir) }

    /// 容器目录名形如 `com.tencent.xinWeChat` 或 `5A4RE8SF68.com.tencent.xinWeChat`。
    private func matchesContainer(_ dirName: String, query: ScanQuery) -> Bool {
        let lower = dirName.lowercased()

        // 有确切 bundle id 时只认它，避免 com.tencent.* 把企业微信、QQ 一起卷进来
        if let bid = query.app?.bundleId?.lowercased() {
            return lower == bid || lower.hasSuffix(".\(bid)")
        }

        // 关键词模式：退回子串匹配
        return query.matches(dirName)
    }
}
