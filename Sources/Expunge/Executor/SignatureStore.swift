import Foundation

/// 自定义应用签名规则库。v1 用一份内置 JSON + 用户可加的自定义文件。
/// 规则用于补充扫描器对特殊应用路径的识别。
struct AppSignature: Codable, Hashable {
    let name: String
    let bundleIds: [String]
    let extraPathGlobs: [String]   // 额外要扫的路径
    let extraProcessNames: [String]
    let knownAuthFiles: [String]  // 已知的鉴权文件
}

enum SignatureStore {
    static var customSignaturesPath: String {
        let dir = "\(NSHomeDirectory())/Library/Application Support/Expunge"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return "\(dir)/signatures.json"
    }

    /// 内置签名（v1 演示用：包含 mimo、cc-connect）
    static let builtIn: [AppSignature] = [
        AppSignature(
            name: "Mimo",
            bundleIds: ["ai.mimo.client", "com.mimocode.Mimo"],
            extraPathGlobs: [
                "~/.local/share/mimocode",
                "~/.cache/mimocode",
                "~/.config/mimocode",
                "~/.local/state/mimocode",
                "~/.local/bin/mimo",
                "~/.git/mimocode-project-id"
            ],
            extraProcessNames: ["mimo"],
            knownAuthFiles: ["mimo-free-client"]
        ),
        AppSignature(
            name: "cc-connect",
            bundleIds: [],
            extraPathGlobs: [
                "~/.cc-connect",
                "/opt/homebrew/etc/cc-connect"
            ],
            extraProcessNames: ["cc-connect"],
            knownAuthFiles: []
        )
    ]

    static func all() -> [AppSignature] {
        var result = builtIn
        if let data = try? Data(contentsOf: URL(fileURLWithPath: customSignaturesPath)),
           let userSigs = try? JSONDecoder().decode([AppSignature].self, from: data) {
            result.append(contentsOf: userSigs)
        }
        return result
    }

    /// 查找与 target 匹配的签名
    static func match(target: String) -> AppSignature? {
        let lower = target.lowercased()
        return all().first { sig in
            sig.name.lowercased() == lower ||
            sig.bundleIds.contains(where: { $0.lowercased().contains(lower) }) ||
            sig.extraProcessNames.contains(where: { $0.lowercased().contains(lower) })
        }
    }
}
