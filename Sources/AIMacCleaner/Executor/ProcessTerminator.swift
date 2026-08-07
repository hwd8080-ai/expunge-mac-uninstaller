import AppKit
import Foundation
import Darwin

/// 卸载 / 删除前，主动把「目标 app 自身」的运行进程退掉。
///
/// **为什么需要**：`RemovalExecutor` 阶段 1 只会杀用户勾选的 `runningProcess` 类目项。
/// 但很多 app 的主进程并不在那张残留列表里 —— 于是 `.app` 被移进废纸篓、进程却还
/// 占着内存继续跑，表现就是用户说的「删了还在用」。这里在真正删文件之前，按
/// bundle id / 显示名 / 关键词把目标 app 的所有实例先优雅退出、不退就强杀。
///
/// **安全**：绝不终止本工具自身（否则卸载跑到一半进程没了，后面的活全砸了）。
enum ProcessTerminator {
    /// 终止匹配给定 bundle id / 名称 / 关键词、且仍在运行的 app（排除自身）。
    /// - Returns: 实际发起终止的进程数。
    @discardableResult
    static func terminate(targetBundleId: String? = nil,
                          targetName: String? = nil,
                          keywords: [String] = []) -> Int {
        let ownBundle = Bundle.main.bundleIdentifier
        let ownPid = ProcessInfo.processInfo.processIdentifier
        let lowerKeywords = keywords.map { $0.lowercased() }

        let byBundle = NSRunningApplication.runningApplications(withBundleIdentifier: targetBundleId ?? "")
        let all = NSWorkspace.shared.runningApplications
        let matched = Set(byBundle).union(all.filter { app in
            guard let bid = app.bundleIdentifier?.lowercased(),
                  let name = app.localizedName?.lowercased() else { return false }
            if let t = targetBundleId?.lowercased(), bid == t { return true }
            if let n = targetName?.lowercased(), name == n { return true }
            return lowerKeywords.contains(where: { bid.contains($0) || name.contains($0) })
        })

        // 排除自己：正在执行的卸载工具不能被自己干掉。
        let targets = matched.filter { app in
            if let bid = app.bundleIdentifier, bid == ownBundle { return false }
            if app.processIdentifier == ownPid { return false }
            return true
        }
        guard !targets.isEmpty else { return 0 }

        // 1) 先优雅退出（发 Quit Apple Event，让 app 有机会保存）。
        for app in targets { app.terminate() }
        // 2) 给 1 秒收尾；还活着的强杀。
        Thread.sleep(forTimeInterval: 1.0)
        for app in targets where !app.isTerminated {
            if let bid = app.bundleIdentifier, bid == ownBundle { continue }
            if app.processIdentifier == ownPid { continue }
            app.forceTerminate()
        }
        return targets.count
    }

    /// 按 PID 终止一组进程（优雅退出 → 强杀）。用于「进程」tab 的手动清理。
    /// - Returns: 实际结束（已退出）的进程数。
    ///
    /// 排除自身与 `pid ≤ 1`，绝不终止 AI Mac Cleaner 自己或 init/launchd 之类。
    @discardableResult
    static func terminate(pids: [pid_t]) -> Int {
        let ownPid = ProcessInfo.processInfo.processIdentifier
        let targets = pids.filter { $0 != ownPid && $0 > 1 }
        guard !targets.isEmpty else { return 0 }

        // 1) 先 SIGTERM，给进程保存 / 退出的机会。
        for pid in targets { kill(pid, SIGTERM) }
        // 2) 等 1 秒收尾。
        Thread.sleep(forTimeInterval: 1.0)
        // 3) 还活着的强杀。
        var killed = 0
        for pid in targets {
            if kill(pid, 0) == 0 {        // 仍然存活
                kill(pid, SIGKILL)
            }
            // 再确认一次：已退出（ESRCH，kill 返回非 0）才算成功结束。
            if kill(pid, 0) != 0 { killed += 1 }
        }
        return killed
    }
}
