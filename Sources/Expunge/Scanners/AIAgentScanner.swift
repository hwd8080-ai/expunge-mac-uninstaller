import Foundation

// AI 工具分组的数据结构已并入 `LeftoverGroup`（见 Models/LeftoverSource.swift），
// 这里产出 `source == .aiTool` 的分组，和无主残留共用「残留」页。

/// 扫描 AI 编程工具（Claude Code、Cursor、Windsurf、Aider …）在用户目录下留下的隐藏配置 / 数据。
///
/// **为什么独立成一个扫描器、而不是塞进 `DotfileScanner`：**
/// `DotfileScanner` 是围绕「某个被卸载的 app」做关键词匹配的 —— 你得知道工具名去搜，
/// 它才会列出 `.claude`。但 AI agent 的痕迹是「独立类别」，用户往往想一键扫出
/// 全部、再挑着清，而不是记住十几个工具名逐个搜。所以这里反过来：
/// 拿一份**已知工具目录清单**去 `~/` 下逐个核对存在性，命中的就报出来。
///
/// **扫描范围（刻意保守）：** 只在 `~/` 根下的点文件/目录、`~/.config`、`~/.cache`、
/// `~/.local/share` 里找**已知名称**。不递归项目目录去翻 `CLAUDE.md` / `.cursor/rules` 这类
/// 散落在你仓库里的文件 —— 那些很可能是你**故意保留**的，自动清掉会惹祸。
/// 也不碰 `~/Library/Containers` 等受 TCC 管的地方，免得弹授权框。
///
/// **风险判定：** 这些目录通常含会话历史、登录态、自定义命令 / skills、MCP 配置，
/// 属于不可再生的用户数据。一律 `.userData`、默认不勾选、删除进废纸篓可找回 ——
/// 和 `OrphanScanner` 的保守取向一致（宁可漏报也不误删）。
enum AIAgentScanner {

    /// 单个工具的已知痕迹清单。
    struct AIToolSpec {
        let name: String
        /// `~/` 下的隐藏目录（精确名），如 `.claude`、`.cursor`。
        let homeDirs: [String]
        /// `~/` 下的隐藏文件（精确名），如 `.claude.json`、`.cursor.json`。
        let homeFiles: [String]
        /// `~/` 下文件名前缀（用于 ~/.claude.json.backup.177… / .tmp.456 这类备份/临时变体）。
        let homeFilePrefixes: [String]
        /// `~/.config/` 下的子目录，如 `cursor`、`codex`。
        let configDirs: [String]
        /// `~/.cache/` 下的子目录。
        let cacheDirs: [String]
        /// `~/.local/share/` 下的子目录。
        let localShareDirs: [String]
    }

    /// 全部已知工具的目录清单。新增工具只加一项，扫描与 UI 自动适配。
    ///
    /// 资料来源：各工具官方卸载文档 + 真机路径核对（Claude Code / Cursor / Windsurf
    /// 等官网 clean uninstall 指南，以及社区实测的隐藏目录）。
    static let catalog: [AIToolSpec] = [
        // ── Anthropic ──
        AIToolSpec(
            name: "Claude Code",
            homeDirs: [".claude", ".chelper"],           // .chelper 是旧版 Coding Helper 残留
            homeFiles: [".claude.json"],
            homeFilePrefixes: [".claude.json."],          // .claude.json.backup.* / .claude.json.tmp.*
            configDirs: ["claude"],
            cacheDirs: ["claude"],
            localShareDirs: ["claude"]
        ),
        // ── Anysphere Cursor ──
        AIToolSpec(
            name: "Cursor",
            homeDirs: [".cursor"],
            homeFiles: [".cursor.json"],
            homeFilePrefixes: [],
            configDirs: ["cursor"],
            cacheDirs: ["cursor"],
            localShareDirs: []
        ),
        // ── Codeium Windsurf ──
        AIToolSpec(
            name: "Windsurf",
            homeDirs: [".windsurf", ".codeium"],         // 旧名 Codeium 的残留也一并清
            homeFiles: [".windsurf.json"],
            homeFilePrefixes: [],
            configDirs: ["windsurf", "codeium"],
            cacheDirs: ["windsurf", "codeium"],
            localShareDirs: ["windsurf", "codeium"]
        ),
        // ── Aider ──
        AIToolSpec(
            name: "Aider",
            homeDirs: [".aider"],
            homeFiles: [".aider.conf.yml", ".aider.conf.yaml",
                        ".aider.chat.history.md", ".aider.input.history"],
            homeFilePrefixes: [],
            configDirs: ["aider"],
            cacheDirs: [],
            localShareDirs: []
        ),
        // ── Cline (VS Code 扩展) ──
        AIToolSpec(
            name: "Cline",
            homeDirs: [".cline"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["cline"],
            cacheDirs: ["cline"],
            localShareDirs: []
        ),
        // ── Continue (VS Code 扩展) ──
        AIToolSpec(
            name: "Continue",
            homeDirs: [".continue"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["continue"],
            cacheDirs: ["continue"],
            localShareDirs: []
        ),
        // ── Roo Code (VS Code 扩展) ──
        AIToolSpec(
            name: "Roo Code",
            homeDirs: [".roo"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["roo"],
            cacheDirs: ["roo"],
            localShareDirs: []
        ),
        // ── Kilo Code (VS Code 扩展) ──
        AIToolSpec(
            name: "Kilo Code",
            homeDirs: [".kilocode"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["kilocode"],
            cacheDirs: [],
            localShareDirs: []
        ),
        // ── OpenAI Codex CLI ──
        AIToolSpec(
            name: "OpenAI Codex",
            homeDirs: [".codex"],
            homeFiles: [".codexrc"],
            homeFilePrefixes: [],
            configDirs: ["codex"],
            cacheDirs: ["codex"],
            localShareDirs: ["codex"]
        ),
        // ── Google Gemini CLI ──
        AIToolSpec(
            name: "Gemini CLI",
            homeDirs: [".gemini"],
            homeFiles: ["GEMINI.md"],
            homeFilePrefixes: [],
            configDirs: ["gemini"],
            cacheDirs: ["gemini"],
            localShareDirs: ["gemini"]
        ),
        // ── GitHub Copilot (主要集成在编辑器内) ──
        AIToolSpec(
            name: "GitHub Copilot",
            homeDirs: [],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["github-copilot"],
            cacheDirs: ["github-copilot"],
            localShareDirs: []
        ),
        // ── 阿里 Qwen Code / 通义千问 ──
        AIToolSpec(
            name: "Qwen Code",
            homeDirs: [".qwen"],
            homeFiles: ["QWEN.md"],
            homeFilePrefixes: [],
            configDirs: ["qwen"],
            cacheDirs: ["qwen"],
            localShareDirs: ["qwen"]
        ),
        // ── 智谱 AI / GLM（社区实测残留为 .zai）──
        AIToolSpec(
            name: "智谱 GLM",
            homeDirs: [".zai"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: [],
            cacheDirs: [],
            localShareDirs: []
        ),
        // ── Block Goose ──
        AIToolSpec(
            name: "Goose",
            homeDirs: [".goose"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["goose"],
            cacheDirs: ["goose"],
            localShareDirs: ["goose"]
        ),
        // ── OpenCode ──
        AIToolSpec(
            name: "OpenCode",
            homeDirs: [".opencode"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["opencode"],
            cacheDirs: ["opencode"],
            localShareDirs: ["opencode"]
        ),
        // ── Amazon Q Developer CLI ──
        // 注意：不扫 ~/.aws —— 那是 AWS CLI 等一堆工具共用的大目录，误伤面太广。
        AIToolSpec(
            name: "Amazon Q",
            homeDirs: [],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["amazonq"],
            cacheDirs: ["amazonq"],
            localShareDirs: ["amazonq"]
        ),
        // ── xAI Grok ──
        AIToolSpec(
            name: "Grok",
            homeDirs: [".grok"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["grok"],
            cacheDirs: ["grok"],
            localShareDirs: ["grok"]
        ),
        // ── OpenClaw ──
        AIToolSpec(
            name: "OpenClaw",
            homeDirs: [".openclaw"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["openclaw"],
            cacheDirs: ["openclaw"],
            localShareDirs: ["openclaw"]
        ),
        // ── 字节跳动 Trae ──
        AIToolSpec(
            name: "Trae（字节）",
            homeDirs: [".trae"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["trae"],
            cacheDirs: ["trae"],
            localShareDirs: ["trae"]
        ),
        // ── 扣子 Coze（字节）──
        AIToolSpec(
            name: "扣子 Coze（字节）",
            homeDirs: [".coze"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["coze"],
            cacheDirs: ["coze"],
            localShareDirs: ["coze"]
        ),
        // ── 豆包 Doubao（字节）──
        AIToolSpec(
            name: "豆包 Doubao（字节）",
            homeDirs: [".doubao"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["doubao"],
            cacheDirs: ["doubao"],
            localShareDirs: ["doubao"]
        ),
        // ── Hermes ──
        AIToolSpec(
            name: "Hermes",
            homeDirs: [".hermes"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["hermes"],
            cacheDirs: ["hermes"],
            localShareDirs: ["hermes"]
        ),
        // ── CodeBuddy（腾讯）──
        AIToolSpec(
            name: "CodeBuddy",
            homeDirs: [".codebuddy"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["codebuddy"],
            cacheDirs: ["codebuddy"],
            localShareDirs: ["codebuddy"]
        ),
        // ── Qoder ──
        AIToolSpec(
            name: "Qoder",
            homeDirs: [".qoder"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["qoder"],
            cacheDirs: ["qoder"],
            localShareDirs: ["qoder"]
        ),
        // ── RAGFlow ──
        AIToolSpec(
            name: "RAGFlow",
            homeDirs: [".ragflow"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["ragflow"],
            cacheDirs: ["ragflow"],
            localShareDirs: ["ragflow"]
        ),
        // ── QoderWork ──
        AIToolSpec(
            name: "QoderWork",
            homeDirs: [".qoderwork"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["qoderwork"],
            cacheDirs: ["qoderwork"],
            localShareDirs: ["qoderwork"]
        ),
        // ── OpenAI ChatGPT ──
        AIToolSpec(
            name: "ChatGPT",
            homeDirs: [".chatgpt"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["chatgpt", "openai"],
            cacheDirs: ["chatgpt"],
            localShareDirs: ["chatgpt"]
        ),
        // ── WorkBuddy ──
        AIToolSpec(
            name: "WorkBuddy",
            homeDirs: [".workbuddy"],
            homeFiles: [],
            homeFilePrefixes: [],
            configDirs: ["workbuddy"],
            cacheDirs: ["workbuddy"],
            localShareDirs: ["workbuddy"]
        )
    ]

    /// 扫描全部已知 AI 编程工具的残留，按工具分组返回（按占用从大到小排序）。
    ///
    /// 只读、不删。调用方负责 UI 展示与（经 ConfirmSheet 确认的）删除。
    static func scanAll() -> [LeftoverGroup] {
        let home = NSHomeDirectory()
        let fm = FileManager.default
        // 列出 ~/ 下所有条目（含隐藏的），用于前缀匹配备份/临时变体文件。
        let homeEntries = (try? fm.contentsOfDirectory(atPath: home)) ?? []

        var groups: [String: LeftoverGroup] = [:]
        for spec in catalog {
            var artifacts: [Artifact] = []

            for d in spec.homeDirs {
                if let a = artifact(base: home, name: d, tool: spec.name) { artifacts.append(a) }
            }
            for f in spec.homeFiles {
                if let a = artifact(base: home, name: f, tool: spec.name) { artifacts.append(a) }
            }
            for prefix in spec.homeFilePrefixes {
                for e in homeEntries where e.hasPrefix(prefix) {
                    if let a = artifact(base: home, name: e, tool: spec.name) { artifacts.append(a) }
                }
            }
            for d in spec.configDirs {
                if let a = artifact(base: "\(home)/.config", name: d, tool: spec.name) { artifacts.append(a) }
            }
            for d in spec.cacheDirs {
                if let a = artifact(base: "\(home)/.cache", name: d, tool: spec.name) { artifacts.append(a) }
            }
            for d in spec.localShareDirs {
                if let a = artifact(base: "\(home)/.local/share", name: d, tool: spec.name) { artifacts.append(a) }
            }

            if !artifacts.isEmpty {
                groups[spec.name] = LeftoverGroup(owner: spec.name, source: .aiTool, artifacts: artifacts)
            }
        }

        return groups.values.sorted {
            $0.totalSize != $1.totalSize ? $0.totalSize > $1.totalSize : $0.owner < $1.owner
        }
    }

    /// 路径存在才返回一条 Artifact；不存在返回 nil。
    private static func artifact(base: String, name: String, tool: String) -> Artifact? {
        let path = "\(base)/\(name)"
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return nil }

        let url = URL(fileURLWithPath: path)
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let size: Int64
        if isDir {
            size = (try? url.directorySize()) ?? 0
        } else {
            size = Int64((try? fm.attributesOfItem(atPath: path)[.size] as? UInt64 ?? 0) ?? 0)
        }

        // 这些目录里是会话历史 / 登录态 / 自定义命令，不可再生 → userData、默认不勾选。
        return Artifact(
            category: .dotfile,
            path: path,
            size: size,
            risk: .userData,
            meta: L10n.t("AI 工具：\(tool)", "AI tool: \(tool)"),
            selected: false
        )
    }
}
