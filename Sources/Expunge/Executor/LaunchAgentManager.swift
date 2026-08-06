import Foundation

/// Launch agent / daemon 的 load/unload 管理。
enum LaunchAgentManager {
    struct Result {
        let plist: String
        let success: Bool
        let message: String
    }

    /// 优先用 launchctl bootout（macOS 13+），失败回退 unload。
    static func unload(plistPath: String) -> Result {
        // 解析 Label 用于 bootout
        var label: String?
        if let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)) {
            label = (try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])?["Label"] as? String
        }
        if let label = label {
            _ = Shell.run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(label)"])
        }
        // 兜底
        let ok = Shell.run("/bin/launchctl", ["unload", plistPath]) != nil
        // 无论 unload 成功与否，删除 plist 文件本身
        try? FileManager.default.removeItem(atPath: plistPath)
        return Result(plist: plistPath, success: ok, message: ok ? "已 unload 并删除" : "unload 失败但已删除")
    }
}
