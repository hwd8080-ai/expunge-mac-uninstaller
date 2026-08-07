import Foundation

/// 反馈记录的本地持久化（JSON）。
///
/// 「反馈记录」入口打开的是历史列表，而不是提交表单。每次从
/// `FeedbackSheet` 成功提交后，把一条摘要写进来，用户可回看、可编辑、可删除、可清空。
///
/// 存在 `~/Library/Application Support/AIMacCleaner/feedback.json`：
/// 这是 app 自己的私有目录，不需要任何额外权限，也不会跟着删废纸篓误删。
struct FeedbackEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    /// 针对的具体痕迹名（泛化反馈为 nil）。
    let targetName: String?
    /// 问题类型文案（已本地化，落库时定格）。
    let reason: String
    /// 问题类型的原始 key，二次编辑时用来还原 Reason 枚举。
    let reasonRaw: String?
    let note: String
    /// 提交通道："github" / "mail"。
    let channel: String
    /// 提交时的标题（便于回看这条反馈说了什么）。
    let title: String

    var dateText: String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: L10n.isChinese ? "zh_CN" : "en_US")
        return f.string(from: date)
    }

    var channelLabel: String {
        channel == "github" ? "GitHub" : "Email"
    }
}

final class FeedbackStore {
    static let shared = FeedbackStore()

    private let url: URL

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("AIMacCleaner", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("feedback.json")
    }

    func all() -> [FeedbackEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([FeedbackEntry].self, from: data)) ?? []
    }

    func record(_ entry: FeedbackEntry) {
        var list = all()
        list.insert(entry, at: 0)
        try? JSONEncoder().encode(list).write(to: url)
    }

    func delete(_ id: UUID) {
        let list = all().filter { $0.id != id }
        try? JSONEncoder().encode(list).write(to: url)
    }

    /// 用同 id 的新 entry 替换旧记录（二次编辑）。日期保持原值。
    func update(_ entry: FeedbackEntry) {
        var list = all()
        guard let idx = list.firstIndex(where: { $0.id == entry.id }) else { return }
        list[idx] = entry
        try? JSONEncoder().encode(list).write(to: url)
    }

    func clearAll() {
        try? JSONEncoder().encode([FeedbackEntry]()).write(to: url)
    }
}
