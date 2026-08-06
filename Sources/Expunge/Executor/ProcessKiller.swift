import Foundation
import Darwin

/// 杀进程工具，按 PID 优雅杀（SIGTERM）→ 强杀（SIGKILL）。
enum ProcessKiller {
    struct Result {
        let pid: String
        let success: Bool
        let message: String
    }

    /// 先 SIGTERM，1 秒后还活着就 SIGKILL。
    static func kill(pid: String) -> Result {
        guard let pidInt = pid_t(pid) else {
            return Result(pid: pid, success: false, message: "无效 PID")
        }
        // SIGTERM
        if Darwin.kill(pidInt, SIGTERM) != 0 {
            if errno == ESRCH {
                return Result(pid: pid, success: true, message: "已退出")
            }
            return Result(pid: pid, success: false, message: String(cString: strerror(errno)))
        }
        // 等 1 秒
        Thread.sleep(forTimeInterval: 1.0)
        if Darwin.kill(pidInt, 0) == 0 {
            if Darwin.kill(pidInt, SIGKILL) != 0 {
                return Result(pid: pid, success: false, message: "强杀失败: \(String(cString: strerror(errno)))")
            }
            return Result(pid: pid, success: true, message: "已 SIGKILL")
        }
        return Result(pid: pid, success: true, message: "已 SIGTERM")
    }

    /// 通过 pkill 按命令名杀（兜底）
    @discardableResult
    static func pkill(_ pattern: String) -> Bool {
        return Shell.run("/usr/bin/pkill", ["-9", "-f", pattern]) != nil
    }
}
