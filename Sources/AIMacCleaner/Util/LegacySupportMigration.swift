import Foundation

/// 一次性把旧版 `~/Library/Application Support/Expunge` 数据目录迁移到
/// `~/Library/Application Support/AIMacCleaner`，避免改名后老用户的
/// 对话历史 / 长期记忆 / 反馈 / 卸载历史读不到。
///
/// 设计要点（与 App 启动顺序解耦）：
/// - `done` 静态标志保证整进程只真正迁移一次。
/// - 若新目录已被某个 Store 的 `createDirectory` 提前建好（空目录），
///   走「复制旧文件进新目录」分支；否则走「整体 move」分支。
///   两种分支都幂等，因此无论本函数与各个 Store 的初始化谁先谁后都安全。
enum LegacySupportMigration {
    private static var done = false

    static func migrateIfNeeded() {
        guard !done else { return }
        done = true

        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let old = base.appendingPathComponent("Expunge", isDirectory: true)
        let new = base.appendingPathComponent("AIMacCleaner", isDirectory: true)

        guard fm.fileExists(atPath: old.path) else { return }

        do {
            if fm.fileExists(atPath: new.path) {
                // 新目录已存在（被某个 Store 先建了空目录）：把旧文件复制进去，再删旧目录。
                let items = try fm.contentsOfDirectory(at: old, includingPropertiesForKeys: nil)
                for item in items {
                    let dest = new.appendingPathComponent(item.lastPathComponent)
                    try? fm.removeItem(at: dest)
                    try fm.copyItem(at: item, to: dest)
                }
                try fm.removeItem(at: old)
            } else {
                try fm.moveItem(at: old, to: new)
            }
        } catch {
            // 迁移失败不致命：旧数据留在原地，新 app 用新目录正常工作。
        }
    }
}
