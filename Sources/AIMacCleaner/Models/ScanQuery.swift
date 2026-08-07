import Foundation

/// 一次扫描的匹配条件。
///
/// 存在的理由：13 个扫描器原先各自拿用户输入的原始字符串做 `contains`，
/// 于是搜「微信」时 WeChat.app 漏掉（磁盘名是 WeChat），
/// 反而命中了 `Application Support/微信开发者工具`（目录名恰好含中文）。
///
/// 现在先把用户输入解析成「一个具体 app + 它的全部别名」，再把这些别名一起下发给扫描器。
struct ScanQuery {
    /// 用户原始输入
    let raw: String
    /// 已定位到的 app（可能为 nil：mimo/cc-connect 这类 CLI 工具没有 .app）
    let app: AppIdentity?
    /// 用于文件/目录名匹配的关键词集合（全小写）
    let keywords: [String]
    /// 其他已安装 app 的别名。命中这些的痕迹要排除掉——
    /// 否则搜 ChatGPT（bundle id com.openai.codex）会把另一个名字里带 Codex 的 app 的数据也算进来。
    let foreignKeywords: Set<String>

    /// 仅关键词模式：没找到对应 app，退回用原始输入匹配（保持 v1.0 对 CLI 工具的能力）
    init(raw: String) {
        self.raw = raw
        self.app = nil
        let k = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.keywords = k.isEmpty ? [] : [k]
        self.foreignKeywords = []
    }

    /// app 模式：用该 app 的全部别名做匹配。
    /// `others` 传入其他已安装 app，用于排除它们的痕迹。
    init(raw: String, app: AppIdentity, others: [AppIdentity] = []) {
        self.raw = raw
        self.app = app

        var set = Set<String>()
        // 文件名和 bundle id 末段是最可靠的痕迹线索：
        // WeChat.app 的残留目录通常叫 WeChat / com.tencent.xinWeChat，而不是「微信」
        set.insert(app.fileName.lowercased())
        if let bid = app.bundleId?.lowercased() { set.insert(bid) }
        if let suffix = app.bundleIdSuffix { set.insert(suffix) }
        set.insert(app.displayName.lowercased())

        // 去空格的紧凑写法：「Codex Sample App」→ codexsampleapp，
        // 用于命中 Application Support/CodexSampleAppStudio 这类无空格目录名
        for n in [app.fileName.lowercased(), app.displayName.lowercased()] {
            let compact = n.replacingOccurrences(of: " ", with: "")
            if compact != n { set.insert(compact) }
        }

        // 过滤掉过短的关键词，避免 "ai"、"cc" 之类扫出满屏无关项
        let filtered = set.filter { $0.count >= 3 }
        // 若全被过滤（如 app 名就叫 "Go"），保留原始输入兜底
        self.keywords = filtered.isEmpty
            ? [app.fileName.lowercased()]
            : filtered.sorted()

        // 收集其他 app 的可辨识名字。只取「比本 app 关键词更长」的，
        // 这样那个第三方 app 的目录会被排除，但不会把 codex 本身排掉。
        var foreign = Set<String>()
        for other in others where other.bundlePath != app.bundlePath {
            for candidate in [other.fileName.lowercased(),
                              other.displayName.lowercased(),
                              other.bundleId?.lowercased()].compactMap({ $0 }) {
                guard candidate.count >= 3 else { continue }
                // 只有当这个名字不是本 app 的关键词时才算「外来」
                if !self.keywords.contains(candidate) {
                    foreign.insert(candidate)
                    // 去掉空格的紧凑写法：Codex Sample App → codexsampleapp，
                    // 用于匹配 CodexSampleAppStudio 这类目录名
                    let compact = candidate.replacingOccurrences(of: " ", with: "")
                    if compact.count >= 3 && !self.keywords.contains(compact) {
                        foreign.insert(compact)
                    }
                }
            }
        }
        self.foreignKeywords = foreign
    }

    /// 给定的名字是否命中本次查询。
    func matches(_ name: String) -> Bool {
        let lower = name.lowercased()
        guard keywords.contains(where: { lower.contains($0) }) else { return false }
        // 命中了别的已安装 app 的名字 → 这痕迹属于那个 app，不是本次目标
        if isForeign(lower) { return false }
        return true
    }

    /// 这个名字看起来属于另一个已安装的 app 吗？
    private func isForeign(_ lower: String) -> Bool {
        for foreign in foreignKeywords where lower.contains(foreign) {
            // 只有当外来名字比本 app 的所有命中关键词都长时才判定为外来，
            // 避免「更长的名字」反过来把正主排掉
            let myBestHit = keywords.filter { lower.contains($0) }.map(\.count).max() ?? 0
            if foreign.count > myBestHit { return true }
        }
        return false
    }

    /// 用于展示的目标名
    var displayTarget: String {
        app?.displayName ?? raw
    }

    var isEmpty: Bool { keywords.isEmpty }
}
