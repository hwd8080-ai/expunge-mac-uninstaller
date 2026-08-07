import Foundation

/// 各包管理器的卸载动作。
enum PackageUninstallers {

    static func brew(_ kind: BrewKind, name: String) -> ActionResult {
        let brew = locateBrew() ?? "/opt/homebrew/bin/brew"
        let arg = kind == .formula ? "--formula" : "--cask"
        let out = Shell.run(brew, ["uninstall", arg, name, "--force"])
        // brew uninstall 退出码 0 = 成功
        return ActionResult(success: out != nil, message: out ?? "brew 不可用")
    }

    static func npm(_ pkg: String) -> ActionResult {
        guard let npm = locateNpm() else {
            return ActionResult(success: false, message: "npm 未安装")
        }
        let out = Shell.run(npm, ["uninstall", "-g", pkg])
        return ActionResult(success: out != nil, message: out ?? "npm 不可用")
    }

    static func pipx(_ pkg: String) -> ActionResult {
        guard let pipx = locatePipx() else {
            return ActionResult(success: false, message: "pipx 未安装")
        }
        let out = Shell.run(pipx, ["uninstall", pkg])
        return ActionResult(success: out != nil, message: out ?? "pipx 不可用")
    }

    static func mas(_ id: String) -> ActionResult {
        guard let mas = locateMas() else {
            return ActionResult(success: false, message: "mas 未安装")
        }
        let out = Shell.run(mas, ["uninstall", id])
        return ActionResult(success: out != nil, message: out ?? "mas 不可用")
    }

    // MARK: - locators

    private static func locateBrew() -> String? {
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func locateNpm() -> String? {
        let candidates = [
            "/opt/homebrew/bin/npm",
            "/usr/local/bin/npm",
            "\(NSHomeDirectory())/.nvm/versions/node/current/bin/npm"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? Shell.run("/usr/bin/env", ["which", "npm"])
    }

    private static func locatePipx() -> String? {
        let candidates = [
            "/opt/homebrew/bin/pipx",
            "/usr/local/bin/pipx",
            "\(NSHomeDirectory())/.local/bin/pipx"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? Shell.run("/usr/bin/env", ["which", "pipx"])
    }

    private static func locateMas() -> String? {
        let candidates = ["/opt/homebrew/bin/mas", "/usr/local/bin/mas"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
            ?? Shell.run("/usr/bin/env", ["which", "mas"])
    }
}

enum BrewKind { case formula, cask }

struct ActionResult {
    let success: Bool
    let message: String
}
