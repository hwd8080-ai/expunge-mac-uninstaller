import Foundation

/// 用户可调的偏好项。
enum Prefs {
    /// 是否扫描 `~/Downloads`。**默认关闭。**
    ///
    /// 那里能找到手动下载的 CLI 工具（`~/Downloads/mimo`），但代价是
    /// **每次扫描都要碰一个 TCC 保护目录** —— macOS 会弹
    /// 「Expunge 想访问「下载」文件夹中的文件」。
    ///
    /// 收益和代价不成比例：本工具的核心场景是卸载**已安装**的 app，而
    /// `~/Downloads` 里通常是安装包本身而不是安装结果。所以默认不扫，
    /// 需要的人自己开。
    ///
    /// `~/.local/bin` 不受 TCC 管，一直照扫。
    static var scanDownloads: Bool {
        get { UserDefaults.standard.bool(forKey: scanDownloadsKey) }
        set { UserDefaults.standard.set(newValue, forKey: scanDownloadsKey) }
    }

    static let scanDownloadsKey = "expunge.scanDownloads"
}
