import Foundation

/// 同步的 shell 工具，集中 Process 调用。
/// 扫描器和卸载器都会用到。
enum Shell {
    /// 执行命令并返回 stdout，失败返回 nil。
    static func run(_ launchPath: String, _ args: [String], timeout: TimeInterval = 30) -> String? {
        let process = Process()
        process.launchPath = launchPath
        process.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
            // 简单超时控制
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning {
                if Date() > deadline {
                    process.terminate()
                    return nil
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
