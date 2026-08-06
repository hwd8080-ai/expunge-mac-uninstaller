import Foundation

/// 落盘信封。带 `version` 是为了将来改结构时能做迁移，
/// 而不是靠「解码失败就清空」来收场。
struct ChatArchive: Codable {
    var version: Int = 1
    var messages: [AIMessage] = []

    init(version: Int = 1, messages: [AIMessage] = []) {
        self.version = version
        self.messages = messages
    }

    /// 同 `AIMessage.init(from:)` 的纪律：全字段 `decodeIfPresent` + 默认值，
    /// 将来加字段不会让老用户的历史被静默清空。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? 1
        messages = (try? c.decodeIfPresent([AIMessage].self, forKey: .messages)) ?? []
    }
}

/// 「问 AI」对话历史的本地持久化（JSON）。
///
/// 完全复刻 `FeedbackStore` 的形状与容错策略：同一个目录、同样的 `try?` 静默降级。
/// 存在 `~/Library/Application Support/Expunge/askai-history.json` ——
/// app 自己的私有目录，不需要额外权限，也不会跟着删废纸篓误删。
///
/// **职责边界**：这是**哑存储**，不做任何裁剪、不做任何业务判断。
/// 裁剪的责任 100% 在 `AppState`（写前裁、读后裁），见 `ChatPolicy.trim`。
final class ChatStore {
    static let shared = ChatStore()

    private let url: URL

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Expunge", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("askai-history.json")
    }

    /// 记录文件路径。「在 Finder 中显示对话记录」要用 ——
    /// 用户没法回答「我的聊天记录存哪了」，除非我们把这个路径交出去。
    var fileURL: URL { url }

    /// 读盘。文件不存在 / 解码失败 → 返回 `[]`。不崩、不弹窗、不打断用户。
    func all() -> [AIMessage] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode(ChatArchive.self, from: data))?.messages ?? []
    }

    /// 整体覆写。编码或写入失败 → 静默降级。
    func save(_ messages: [AIMessage]) {
        let archive = ChatArchive(messages: messages)
        try? JSONEncoder().encode(archive).write(to: url)
    }

    /// 写入空会话（与 `FeedbackStore.clearAll` 同形）。
    func clearAll() {
        save([])
    }
}
