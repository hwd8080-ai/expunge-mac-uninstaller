import Foundation

/// 系统/框架自有数据的白名单。孤儿扫描永不把这些判为孤儿。
///
/// 存在的理由：真机 dry-run 发现「跳过 com.apple 前缀」远远不够 ——
/// Apple 自己有一批不带 com.apple 的数据目录：
///   - `group.is.workflow.shortcuts`（快捷指令）
///   - `group.tvappservices.container`（Apple TV）
///   - `org.cups.PrintingPrefs`（打印系统）
///   - `loginwindow`、`pbs`、`Dock`、`CloudDocs`、`Knowledge`（系统服务）
/// 把这些当孤儿删掉会伤到系统本身。
enum SystemOwned {

    /// 系统数据的 bundle id / 目录名前缀（全小写比较）
    static let prefixes: [String] = [
        "com.apple",
        "group.com.apple",
        "groups.com.apple",
        "systemgroup.com.apple",      // ~/Library/Preferences 里有这个形状
        "is.workflow",
        "group.is.workflow",
        "tvappservices",
        "group.tvappservices",
        "org.cups",
        "com.microsoft.pasteboard",   // 系统级剪贴板 XPC，随 Office/RDC 装但独立于 app
        // ── 共享框架 / SDK 的数据。它们由某个装着的 app 写入，
        //    但目录名跟那个 app 的 bundle id 无关，按 app 反查必然找不到主人。
        //    判成孤儿会删掉活 app 正在用的缓存。
        "cocoalumberjack",
        "org.cocoapods",
        "io.flutter",
        "org.webrtc",
        "plcrashreporter",
        "com.plausiblelabs",          // PLCrashReporter 的实际 bundle id
        "com.crashlytics",
        "org.sparkle-project",
        "com.onevcat",                // Kingfisher 图片缓存库
        "org.chromium",               // Electron/CEF 系 app 共用
        // ── 开发工具链 / 包管理器自己的东西，不是「某个 app 的残留」
        "org.swift",                  // SwiftPM 缓存
        "homebrew.mxcl"               // brew services 的 launch agent，由 BrewScanner 负责
    ]

    /// 系统数据的精确目录名（全小写比较）。
    /// 这些是 ~/Library 下由系统服务而非某个 app 创建的目录。
    static let exactNames: Set<String> = [
        "apple", "dock", "clouddocs", "icloud", "knowledge", "loginwindow", "pbs",
        "mobilesync", "syncservices", "fileprovider", "crashreporter", "caches",
        "cookies", "differentialprivacy", "diskimages", "askpermission",
        "callhistorydb", "callhistorytransactions", "animoji", "familycircled",
        "homeenergyd", "icdd", "locationaccessstored", "networkserviceproxy",
        "videosubscriptionsd", "ilifemediabrowser", "scopedbookmarkagent",
        "contextstoreagent", "diagnostics_agent", "knowledge-agent", "mbuseragent",
        "minilauncher", "mobilemeaccounts", "gk", "cef", "chromium",
        "com.apple.mail", "group.com.apple.mail",
        // 共享运行时/框架目录，不属于任何单个 app
        "crashreporter", "virtualenv", "kotlin", "developer"
    ]

    /// 明显不是「app 数据目录」的形状 —— 散落的文件、占位符、脚本。
    /// 这些不该出现在孤儿列表里（它们既不是 app 痕迹，删了也没意义）。
    static func isNoise(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower == "(null)" || lower.isEmpty { return true }
        if lower.hasPrefix("@") { return true }
        if lower.hasPrefix("$(") { return true }          // $(AppIdentifierPrefix)…
        if lower.hasPrefix("default.store") { return true }
        if lower.hasPrefix("aaprofilepicture") { return true }  // 系统头像缓存
        if lower.hasSuffix("-shm") || lower.hasSuffix("-wal") { return true }
        // 散落的文件而非数据目录。这些「点」是文件扩展名，
        // 不是 bundle id 的分段 —— 真机案例：WPS_Office_7.3.0(8966)_arm64.7z、
        // AAProfilePicture_xxx.png、com.ebus.lark.nf_ipc.sock。
        for ext in [".py", ".sh", ".7z", ".zip", ".gz", ".tar", ".dmg", ".pkg",
                    ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico",
                    ".sock", ".pidlock", ".lock", ".pid", ".log", ".txt",
                    ".sqlite", ".sqlite3", ".db", ".cache", ".tmp",
                    ".kts", ".jar", ".json", ".xml", ".yaml", ".yml"] {
            if lower.hasSuffix(ext) { return true }
        }
        return false
    }

    /// 这个目录名是否属于系统 / 框架，孤儿扫描应当跳过？
    static func isSystemOwned(_ name: String) -> Bool {
        let lower = name.lowercased()
        if isNoise(lower) { return true }
        if exactNames.contains(lower) { return true }
        for p in prefixes {
            if lower == p || lower.hasPrefix("\(p).") || lower.hasPrefix("\(p)-") {
                return true
            }
        }
        return false
    }
}
