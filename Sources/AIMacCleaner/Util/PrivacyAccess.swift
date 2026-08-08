import Foundation
import AppKit

/// 完全磁盘访问权限（Full Disk Access, FDA）探测与引导。
///
/// AIMacCleaner 是非沙盒 app，要扫描 `~/Library` 下其他 app 的数据
///（Application Support / Caches / Containers 等）必须拥有 FDA。
/// 没授权时 macOS 会在扫描时硬弹「想访问其他App的数据」系统框，
/// 且对开发版每次重编译重签名都会重弹。这里把「硬弹」换成 app 内引导，
/// 让用户一次去系统设置授权，体验更可控、也避免每次重弹。
enum PrivacyAccess {
    /// 是否已获得完全磁盘访问权限。
    ///
    /// 探测法：尝试读受 FDA 严格管控的路径，能读到内容即视为已授权。
    /// 选两个一定非空的位置——系统级 `/Library/Application Support`
    /// 与用户级 `~/Library/Containers`（其他 app 的沙盒容器），
    /// 任一可读且非空即认为有 FDA。无 FDA 时 `contentsOfDirectory`
    /// 抛 `.fileReadNoPermission`，`try?` 得 nil → 判为未授权。
    static func hasFullDiskAccess() -> Bool {
        let candidates = [
            "/Library/Application Support",
            (NSHomeDirectory() as NSString).appendingPathComponent("Library/Containers")
        ]
        let fm = FileManager.default
        for path in candidates {
            let url = URL(fileURLWithPath: path)
            if let contents = try? fm.contentsOfDirectory(at: url,
                                                          includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles]),
               !contents.isEmpty {
                return true
            }
        }
        return false
    }

    /// 打开「系统设置 → 隐私与安全性 → 完全磁盘访问权限」。
    static func openFullDiskAccessSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") else { return }
        NSWorkspace.shared.open(url)
    }
}
