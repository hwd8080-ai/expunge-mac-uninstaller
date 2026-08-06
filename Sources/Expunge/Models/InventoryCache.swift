import Foundation

/// 进程内缓存：app 索引 + 包管理器输出。
///
/// 存在的理由：v1.1 每次 `scan()` 都重跑 `AppInventory.allApps()` 并起
/// brew/npm/pipx/mas 四个子进程。加了 app 列表入口之后，用户会连着点很多个 app，
/// 28 个 app 就是 112 次 shell 调用 —— 每次点击卡两三秒。
///
/// 卸载完成后必须 `invalidate()`，否则列表还显示已经删掉的 app。
final class InventoryCache: @unchecked Sendable {
    static let shared = InventoryCache()

    private let lock = NSLock()
    private var _allApps: [AppIdentity]?
    private var _liveBundleIds: Set<String>?
    private var _shellOutputs: [String: String?] = [:]

    private init() {}

    /// 已安装 app 索引（不含 /System）
    func allApps() -> [AppIdentity] {
        lock.lock()
        if let cached = _allApps { lock.unlock(); return cached }
        lock.unlock()

        let fresh = AppInventory.allApps()
        lock.lock()
        _allApps = fresh
        lock.unlock()
        return fresh
    }

    /// 活 bundle id 全集（含嵌套，孤儿判定用）。递归全部 .app，约 0.4s，务必缓存。
    func liveBundleIds() -> Set<String> {
        lock.lock()
        if let cached = _liveBundleIds { lock.unlock(); return cached }
        lock.unlock()

        let fresh = AppInventory.liveBundleIds()
        lock.lock()
        _liveBundleIds = fresh
        lock.unlock()
        return fresh
    }

    /// 缓存一次 shell 调用的结果。key 用 launchPath + args 拼成。
    func shell(_ launchPath: String, _ args: [String]) -> String? {
        let key = ([launchPath] + args).joined(separator: "\u{1}")
        lock.lock()
        if let cached = _shellOutputs[key] { lock.unlock(); return cached }
        lock.unlock()

        let result = Shell.run(launchPath, args)
        lock.lock()
        _shellOutputs[key] = result
        lock.unlock()
        return result
    }

    /// 缓存命中次数统计（自检用：确认第二次调用不再起子进程）
    func hasCachedShell(_ launchPath: String, _ args: [String]) -> Bool {
        let key = ([launchPath] + args).joined(separator: "\u{1}")
        lock.lock()
        defer { lock.unlock() }
        return _shellOutputs[key] != nil
    }

    /// 卸载后调用：文件系统变了，全部重读。
    func invalidate() {
        lock.lock()
        _allApps = nil
        _liveBundleIds = nil
        _shellOutputs.removeAll()
        lock.unlock()
    }
}
