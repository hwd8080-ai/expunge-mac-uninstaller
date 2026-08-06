import Foundation

/// 一条长期记忆 —— 用户通过 `/remember` 显式写下的、要跨会话活下去的信息。
///
/// **与对话历史的根本区别**：`AIMessage` 是流水，会被 `ChatPolicy.trim` 裁掉、
/// 会被 `/new` 清空；这里存的是用户纠正过的结论，`/new` 不碰它，15 轮窗口也带不走它。
/// 两者刻意分成两个文件（`askai-history.json` / `memory.json`），
/// 就是为了让「清空会话」永远不可能误伤记忆。
///
/// ⚠️ `id` **参与序列化**（与 `AIMessage` 相反）：删除一条记忆需要跨启动稳定的引用，
/// 而 `AIMessage.id` 只是渲染标识、每次解码都重生成。别照抄那边的 `CodingKeys` 纪律。
struct MemoryNote: Identifiable, Codable, Equatable {
    let id: UUID
    /// 用户原话，不做任何改写。
    let text: String
    /// 从 `text` 里抽出来的绝对路径（`~` 已展开）。
    ///
    /// 空数组 = 纯笔记，只进提示词、不影响扫描；非空 = 同时作为孤儿扫描的豁免名单。
    /// 抽取规则见 `MemoryPolicy.extractPaths`。
    let paths: [String]
    let createdAt: Date

    init(id: UUID = UUID(), text: String, paths: [String]? = nil, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.paths = paths ?? MemoryPolicy.extractPaths(from: text)
        self.createdAt = createdAt
    }

    /// 同 `ChatArchive` 的纪律：全字段 `decodeIfPresent` + 默认值。
    /// 将来加字段不会让老用户的记忆被静默清空。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        text = (try? c.decodeIfPresent(String.self, forKey: .text)) ?? ""
        paths = (try? c.decodeIfPresent([String].self, forKey: .paths)) ?? []
        createdAt = (try? c.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, paths, createdAt
    }

    var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: createdAt)
    }
}

/// 落盘信封。带 `version` 是为了将来改结构时能做迁移。
struct MemoryArchive: Codable {
    var version: Int = 1
    var notes: [MemoryNote] = []

    init(version: Int = 1, notes: [MemoryNote] = []) {
        self.version = version
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? 1
        notes = (try? c.decodeIfPresent([MemoryNote].self, forKey: .notes)) ?? []
    }
}

/// 长期记忆的**纯函数**策略层：解析、抽路径、豁免判定、提示词拼装、限额。
///
/// 和 `ChatPolicy` 同样的纪律 —— 无状态、不 import SwiftUI、不碰 MainActor、
/// 不碰文件系统，所以 `SelfTest` 能彻底覆盖它。
/// 这里的判定直接决定「哪些目录不会被列为孤儿」，属于安全项，必须可自检。
enum MemoryPolicy {
    /// 记忆条数上限。超了拒绝新增而不是丢弃最老的 ——
    /// 记忆是用户显式写下的，静默丢弃比拒绝更糟。
    static let maxNotes = 50
    /// 单条记忆的字符上限。超长拒绝而不是截断：截断可能正好切掉关键的那半句。
    static let maxNoteChars = 300
    /// 注入提示词的总预算。记满 50 条也不会把上下文挤爆。
    static let maxPromptChars = 2000

    /// 归一化路径：展开 `~`、去掉尾部斜杠、小写化。
    ///
    /// 小写化的理由：macOS 默认文件系统大小写不敏感，`/Users/x/Library` 与
    /// `/users/x/library` 指同一个目录，比较时不归一会漏掉豁免。
    static func normalize(_ raw: String) -> String {
        var p = raw.trimmingCharacters(in: .whitespaces)
        if p == "~" || p.hasPrefix("~/") {
            p = NSHomeDirectory() + String(p.dropFirst(1))
        }
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return p.lowercased()
    }

    /// 从一句自然语言里抽出用户提到的路径。
    ///
    /// 用户不该被要求学两套语法 —— 他只会说
    /// 「~/Library/Application Support/JetBrains 别动，IDEA 还装着」，
    /// 所以这里从整句话里认路径，同一条记忆既是笔记也是豁免规则。
    ///
    /// **路径里可以带空格**（macOS 上 `Application Support` 这类目录名天天见）。
    /// 旧实现按空白切词，会把上面那句话劈成 `~/Library/Application` 和
    /// `Support/JetBrains` 两段 —— 结果错抽成*父目录*、还漏掉了真正的目标，
    /// 豁免完全失效。所以改成「手动扫描」：从一个 `/` 或 `~/` 起，一直吃到
    /// 碰到 (a) 句子结束符 (b) CJK / 非 ASCII（自然语言恢复）或 (c) 闭引号 为止，
    /// 中间的空格照吃不误。
    ///
    /// 收敛纪律（方向一律「宁可不认」，认错路径 = 该报的孤儿不报了，属漏报，
    /// 与本项目「宁可漏报不可误删」同向）：
    ///  1. 必须以 `/` 或 `~/` 开头，且前面是词边界（句首 / 空白 / 开引号）
    ///  2. 展开后必须 ≥2 段且 ≥6 字符 —— 挡掉 `/new`、`/tmp` 这类单段词
    ///     （用户写 `/remember /new 很危险` 时不该产生路径豁免）
    ///  3. 整条 home 根（`~/`）不认 —— 否则「记得我的家目录别动」会把
    ///     全部残留都豁免掉，孤儿扫描直接瘫痪
    static func extractPaths(from text: String) -> [String] {
        let openQuote = Set<Character>(["\"", "'", "`", "「", "《", "（", "【", "("])
        let stop = Set<Character>([",", "。", ";", "；", "：", ":", "、", "!", "！", "?", "？",
                                    ")", "）", "]", "】", "》", "」", "\"", "'", "`",
                                    "\n", "\r"])
        let home = NSHomeDirectory()
        var out: [String] = []
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let prevBoundary = i == 0
                || chars[i-1].isWhitespace || chars[i-1].isNewline
                || openQuote.contains(chars[i-1])
            let isTilde = c == "~" && i + 1 < chars.count && chars[i+1] == "/"
            guard (c == "/" || isTilde), prevBoundary else { i += 1; continue }

            // 吃到路径结束：句子结束符 / 非 ASCII（CJK 自然语言）/ 闭引号 即停。
            var run = ""
            var j = i
            while j < chars.count {
                let d = chars[j]
                if stop.contains(d) || !d.isASCII { break }
                run.append(d)
                j += 1
            }
            while run.hasSuffix(" ") { run.removeLast() }
            i = j

            guard !run.isEmpty else { continue }
            var expanded = run
            if expanded.hasPrefix("~/") {
                expanded = home + String(expanded.dropFirst(1))
            }
            while expanded.count > 1 && expanded.hasSuffix("/") { expanded.removeLast() }
            // 不认整条 home 根。
            guard expanded != home else { continue }
            let segs = expanded.split(separator: "/").count
            guard segs >= 2, expanded.count >= 6 else { continue }
            if !out.contains(expanded) { out.append(expanded) }
        }
        return out
    }

    /// 这个路径被用户豁免了吗？
    ///
    /// **双向前缀匹配**，和 `OrphanScanner.isClaimed` 同一思路：
    ///  - 候选是豁免路径的**后代** → 跳过（用户说「JetBrains 别动」，
    ///    那 `JetBrains/IdeaIC2024` 自然也别动）
    ///  - 候选是豁免路径的**祖先** → 也跳过（用户只点名了子目录，
    ///    但删掉父目录会把它一起带走 —— 不跳过就等于没豁免）
    static func isExempt(_ path: String, keepPaths: Set<String>) -> Bool {
        guard !keepPaths.isEmpty else { return false }
        let p = normalize(path)
        guard !p.isEmpty else { return false }
        for raw in keepPaths {
            let k = normalize(raw)
            guard !k.isEmpty else { continue }
            if p == k { return true }
            if p.hasPrefix(k + "/") { return true }
            if k.hasPrefix(p + "/") { return true }
        }
        return false
    }

    /// 校验一条待写入的记忆。返回 nil = 通过，否则是给用户看的拒绝理由。
    static func rejectionReason(for text: String, existingCount: Int) -> String? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            return L10n.t("用法：/remember 后面跟上要我长期记住的内容。",
                          "Usage: /remember followed by what I should remember.")
        }
        if t.count > maxNoteChars {
            return L10n.t("这条太长了（\(t.count) 字）。记忆要精炼，请压到 \(maxNoteChars) 字以内。",
                          "That's too long (\(t.count) chars). Keep each memory under \(maxNoteChars).")
        }
        if existingCount >= maxNotes {
            return L10n.t("记忆已满（\(maxNotes) 条）。先在记忆面板里删掉一些再记。",
                          "Memory is full (\(maxNotes) items). Delete some in the memory panel first.")
        }
        return nil
    }

    /// 写入成功后给用户的回执。路径豁免必须说出来 ——
    /// 它会实际改变扫描结果，用户有权知道自己刚刚触发了什么。
    static func receipt(for note: MemoryNote) -> String {
        let head = L10n.t("已记住：", "Remembered: ") + note.text
        guard !note.paths.isEmpty else { return head }
        let list = note.paths.map { "· " + abbreviate($0) }.joined(separator: "\n")
        return head + "\n\n" + L10n.t("以下路径已加入豁免，之后的残留扫描不会再把它们列为孤儿：",
                                      "These paths are now exempt — future leftover scans won't flag them as orphans:")
            + "\n" + list
    }

    /// 把 home 前缀缩回 `~`，显示用。
    static func abbreviate(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + String(path.dropFirst(home.count)) }
        return path
    }

    /// 拼装注入 system prompt 的记忆块。空记忆返回空串（提示词里一个字都不多加）。
    ///
    /// 从**最新往最老**取直到预算用尽：记忆满了的时候，新纠正比陈年旧账更该被看见。
    static func promptBlock(_ notes: [MemoryNote], budget: Int = maxPromptChars) -> String {
        guard !notes.isEmpty else { return "" }
        var lines: [String] = []
        var used = 0
        for note in notes.reversed() {
            let t = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            let line = "- " + t
            if used + line.count > budget { break }
            used += line.count
            lines.append(line)
        }
        guard !lines.isEmpty else { return "" }
        // 反转回时间正序：模型读起来是「用户先说了什么、后说了什么」。
        let body = lines.reversed().joined(separator: "\n")
        return L10n.t("""

            用户之前明确要求你长期记住以下信息。它们**优先于**你的默认判断，冲突时以这里为准：
            \(body)
            """, """

            The user has explicitly asked you to remember the following. These **override** your \
            default judgement — when in conflict, follow these:
            \(body)
            """)
    }
}

/// 长期记忆的本地持久化（JSON）。
///
/// 存在 `~/Library/Application Support/Expunge/memory.json`，与
/// `askai-history.json` 同目录但**独立成文件** —— `/new`、`/clear` 只覆写对话历史，
/// 碰不到这里。这是整个设计的要点：用户纠正过的东西不该被一次误点清空。
///
/// **职责边界**：哑存储，不做校验、不做裁剪、不拼提示词，那些全在 `MemoryPolicy`。
///
/// 并发：`OrphanScanner` 会在后台线程读 `keepPaths()`，所以照 `InventoryCache`
/// 的模式加锁，而不是照 `ChatStore`（那个只在 MainActor 上用）。
final class MemoryStore: @unchecked Sendable {
    static let shared = MemoryStore()

    private let lock = NSLock()
    private let url: URL

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Expunge", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("memory.json")
    }

    /// 记忆文件路径。「在 Finder 中显示」和文档要用。
    var fileURL: URL { url }

    /// 读盘。文件不存在 / 解码失败 → `[]`。不崩、不弹窗。
    func all() -> [MemoryNote] {
        lock.lock(); defer { lock.unlock() }
        return readLocked()
    }

    /// 追加一条并落盘，返回写入后的完整列表。
    ///
    /// 不在这里做上限校验 —— 调用方先问 `MemoryPolicy.rejectionReason`，
    /// 这样拒绝理由能原样展示给用户，而不是在存储层静默吞掉。
    @discardableResult
    func add(_ note: MemoryNote) -> [MemoryNote] {
        lock.lock(); defer { lock.unlock() }
        var notes = readLocked()
        notes.append(note)
        writeLocked(notes)
        return notes
    }

    @discardableResult
    func delete(_ id: UUID) -> [MemoryNote] {
        lock.lock(); defer { lock.unlock() }
        var notes = readLocked()
        notes.removeAll { $0.id == id }
        writeLocked(notes)
        return notes
    }

    func clearAll() {
        lock.lock(); defer { lock.unlock() }
        writeLocked([])
    }

    /// 全部豁免路径。`OrphanScanner` 每次扫描取一次（别在循环里调，这会读盘）。
    func keepPaths() -> Set<String> {
        lock.lock(); defer { lock.unlock() }
        return Set(readLocked().flatMap(\.paths))
    }

    // MARK: - 锁内私有

    private func readLocked() -> [MemoryNote] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode(MemoryArchive.self, from: data))?.notes ?? []
    }

    private func writeLocked(_ notes: [MemoryNote]) {
        let archive = MemoryArchive(notes: notes)
        try? JSONEncoder().encode(archive).write(to: url)
    }
}
