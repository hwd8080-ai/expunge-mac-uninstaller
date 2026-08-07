import AppKit

/// 读取 .app 的图标。用户认图标比认名字快得多。
enum AppIconLoader {
    /// 图标读取有磁盘开销，缓存住避免列表滚动时反复读
    private static var cache: [String: NSImage] = [:]
    private static let lock = NSLock()

    static func icon(forBundlePath path: String) -> NSImage? {
        lock.lock()
        if let cached = cache[path] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 32, height: 32)

        lock.lock()
        cache[path] = image
        lock.unlock()
        return image
    }
}
