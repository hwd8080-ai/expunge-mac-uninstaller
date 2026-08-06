# Expunge

**macOS 深度卸载工具**——不只是删 `.app`，连依赖和痕迹一起拔干净。

[English](README.md) | **简体中文**

免费、开源、彻底。卸载任何 Mac 应用的同时，扫清它留下的所有痕迹：Homebrew 公式、npm/pipx 包、沙箱容器、launch agent、shell 配置污染、点文件、缓存……16 类扫描器，一次覆盖。

**删除一律走废纸篓**——判错了随时拖回来。

---

## 功能

### 🧹 深度卸载
选中一个应用，Expunge 找出和它有关的一切。不只是 `.app` 包体——依赖、偏好设置、缓存、日志、容器、包管理器安装的 CLI 工具，全部列出。确认一次，全部清掉。

### 🔍 孤儿残留扫描
几个月前删掉的应用，数据往往还留在 `~/Library` 里。孤儿扫描反向查找：哪些目录已经没有活着的 app 认领？找出你根本不知道还存在的残留。

### 🤖 AI Agent（问 AI）
用自然语言描述目标——「把 Cursor 彻底卸干净」或「扫一遍所有残留」——内置 AI Agent 会自己调用相应 skill、查看结果、出计划。**任何删除操作都要你确认后才执行。**用 `/remember` 记下纠正过的结论，跨会话也不会丢。

### 🖥️ 进程管理
列出 Mac 上所有后台服务类进程——node 服务、Python 脚本、Docker 容器、Brew service。显示内存占用、CPU%、**监听端口**（如 `:3000`、`:8080`）。按端口号搜索，精确找到占用端口的进程，一键结束。

### 🛡️ 安全设计
- **默认走废纸篓。** 绝不直接 `rm`。清空废纸篓前都能找回。
- **没有通用 shell。** AI Agent 只能调用预定义的只读 skill，不能执行任意命令、不能读任意文件、不能联网。
- **执行前必确认。** 每次删除操作都要确认，不做静默操作。
- **系统保护。** 关键系统进程和路径在白名单里，永远不会被删。
- **数据不出本机。** 所有处理本地完成，不做任何网络请求。

---

## 安装

### 下载 DMG（推荐）

从 [Releases](https://github.com/expunge-mac/expunge-mac-uninstaller/releases) 下载 `Expunge-<版本>.dmg` 和同名 `.sha256`。先校验：

```bash
shasum -a 256 -c Expunge-<版本>.dmg.sha256   # 应输出 OK
```

打开 DMG，把 Expunge 拖到 Applications。首次启动：**右键 → 打开**。

### 从源码构建

```bash
git clone https://github.com/expunge-mac/expunge-mac-uninstaller.git
cd expunge-mac-uninstaller
./build_app.sh                       # → /Applications/Expunge.app
open /Applications/Expunge.app
```

打 DMG 发布包：

```bash
./build_release.sh                   # → dist/Expunge-<版本>.dmg + .sha256
```

### 仅命令行

```bash
swift build -c release
.build/release/Expunge --scan 微信       # 扫描某个应用
.build/release/Expunge --self-test       # 跑自检
.build/release/Expunge --skills          # 列出 Agent 能调用的 skill
```

---

## 扫描范围

Expunge 覆盖 16 类残留：

| 类别 | 扫描内容 |
|------|---------|
| `.app` 包体 | 已安装的应用 |
| Homebrew | formula、cask、tap |
| npm / pipx | 全局安装的包 |
| 沙箱容器 | `~/Library/Containers` 数据 |
| Launch Agent | `~/Library/LaunchAgents` plist |
| Shell 配置 | `.zshrc`、`.bashrc`、`.fish` 写入 |
| 点文件/配置 | `.cursor`、`.claude` 等隐藏目录 |
| 缓存 | `~/Library/Caches` |
| 偏好设置 | `~/Library/Preferences` plist |
| 日志 | `~/Library/Logs` |
| 认证令牌 | Keychain 相关的凭证文件 |
| AI 工具数据 | Claude Code、Cursor、Windsurf、Copilot 等 20+ 工具 |
| 孤儿残留 | 无主 `~/Library` 子目录 |
| XDG 目录 | `~/.config`、`~/.local/share` |
| MAS 回执 | Mac App Store 安装记录 |
| Application Support | `~/Library/Application Support` |

---

## AI Agent 可调用的 Skill

内置 7 个 skill：

| Skill | 功能 |
|-------|------|
| `list_apps` | 列出所有已安装应用 |
| `scan_app` | 深度扫描指定应用 |
| `scan_leftovers` | 扫描孤儿残留和 AI 工具数据 |
| `list_processes` | 列出运行中的后台进程 |
| `review_plan` | 复核待执行的卸载计划 |
| `plan_uninstall` | 生成卸载计划待确认 |
| `show_history` | 查看历史卸载记录 |

所有 skill 默认只读。Agent 出计划，你确认后才执行。

---

## 常见问题

**安全吗？** 安全。文件进废纸篓而非直接删除，系统路径受保护，每次删除都要确认。

**会上传数据吗？** 不会。无埋点、无遥测、无网络请求。全部本地处理。

**和 AppCleaner / CleanMyMac 比呢？** 那些是闭源的，有的是付费软件。Expunge 开源免费，且集成了包管理器清理、孤儿扫描、AI 辅助、进程管理于一体。

**可以再分发吗？** 可以。MIT 协议，见 [LICENSE](LICENSE)。

---

## 协议

MIT © Expunge 贡献者
