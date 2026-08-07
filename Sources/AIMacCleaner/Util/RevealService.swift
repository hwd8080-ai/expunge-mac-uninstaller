import AppKit
import Foundation

/// 在访达中显示文件 / 打开文件 / 复制路径。封装 NSWorkspace 调用。
enum RevealService {

    /// 在访达中显示。文件则选中，目录则打开。
    /// 对于 shell rc 类的「file:line」格式，提取文件部分。
    @MainActor
    static func revealInFinder(path: String) {
        let url = parseURL(path)
        guard let url = url else { return }
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            // 选中文件/目录
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            // 父目录都不存在
            NSSound.beep()
        }
    }

    /// 在访达中显示一个**可能还不存在**的数据文件：文件在就选中它，
    /// 不在就退回选中它所在的目录。
    ///
    /// 存在的理由：`askai-history.json` / `memory.json` 都是懒创建的 ——
    /// 从没聊过天、没记过东西的时候文件根本不存在，而「我的记录到底存哪了」
    /// 恰恰是这种时候最想问的。走 `revealInFinder` 会直接 beep，
    /// 等于对这个问题一个字都没回答。
    @MainActor
    static func revealDataFile(_ url: URL) {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }
        let dir = url.deletingLastPathComponent()
        if fm.fileExists(atPath: dir.path) {
            NSWorkspace.shared.activateFileViewerSelecting([dir])
        } else {
            NSSound.beep()
        }
    }

    /// 用默认 app 打开文件
    @MainActor
    static func openFile(path: String) {
        let url = parseURL(path)
        guard let url = url else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            NSSound.beep()
        }
    }

    /// 复制路径到剪贴板
    @MainActor
    static func copyPath(_ path: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(path, forType: .string)
    }

    /// 解析 shell rc 类的「/path/to/file:line」格式，返回 file URL
    private static func parseURL(_ path: String) -> URL? {
        // shell rc 行：「/Users/x/.zshrc:52」→ 取前半部分
        // 但 macOS 路径里也可能含冒号（如 /Volumes/Foo:Bar/...），所以要谨慎
        // 启发式：如果路径前 80 字符内存在以 : 开头且后面全是数字，就当行号
        let pattern = #"^(.+?):(\d+)$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)),
           match.numberOfRanges == 3,
           let fileRange = Range(match.range(at: 1), in: path) {
            // 进一步检查：行号不能超过 99999
            if let lineRange = Range(match.range(at: 2), in: path),
               let line = Int(path[lineRange]),
               line < 100000 {
                let file = String(path[fileRange])
                return URL(fileURLWithPath: file)
            }
        }
        return URL(fileURLWithPath: path)
    }
}
