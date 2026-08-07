import SwiftUI

/// 「进程」tab：列出后台服务类进程（node / python / docker / brew service 等无 GUI 用户进程），
/// 按内存 / CPU 排序，支持按端口号搜索，挑着结束。
///
/// 安全取向（与「残留」「AI 工具」一致）：系统关键进程与 Expunge 自身始终不可杀、
/// 默认不勾选、结束前二次确认。误杀一个 node 顶多丢点未保存的工作，绝不会动系统。
struct ProcessesView: View {
    @EnvironmentObject var state: AppState
    @State private var showKillConfirm = false
    @State private var showKillResult = false
    @State private var killResultCount: Int = 0
    @State private var juryRunning = false
    @State private var showSettings = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .alert(L10n.t("结束进程", "End processes"),
               isPresented: $showKillConfirm) {
            Button(L10n.t("取消", "Cancel"), role: .cancel) {}
            Button(L10n.t("结束 \(state.selectedProcessCount) 个进程",
                          "End \(state.selectedProcessCount) processes"),
                   role: .destructive) {
                killResultCount = state.killSelectedProcesses()
                state.clearProcessVerdicts()
                showKillResult = true
                Task { await state.scanProcesses() }
            }
        } message: {
            let high = state.selectedProcesses.filter { state.processVerdicts[$0.pid]?.level == .high }.count
            let base = L10n.t("将结束选中的 \(state.selectedProcessCount) 个进程，预计释放约 \(SizeFormat.human(state.selectedMemoryBytes)) 内存。未保存的工作会丢失，且无法撤销。",
                              "This will end the \(state.selectedProcessCount) selected process(es), freeing about \(SizeFormat.human(state.selectedMemoryBytes)) of memory. Unsaved work will be lost and this cannot be undone.")
            if high > 0 {
                return Text(base + "\n\n" + L10n.t("⚠️ AI 判断其中 \(high) 个为高风险（可能崩溃重要应用或丢工作），请特别确认。",
                                                  "⚠️ AI flagged \(high) as high-risk (may crash important apps or lose work) — double-check before proceeding."))
            }
            return Text(base)
        }
        .alert(L10n.t("已结束进程", "Processes ended"),
               isPresented: $showKillResult) {
            Button(L10n.t("好的", "OK"), role: .cancel) {}
        } message: {
            Text(L10n.t("成功结束 \(killResultCount) 个进程。已自动重新扫描。",
                        "Successfully ended \(killResultCount) process(es). Re-scanned automatically."))
        }
        .sheet(isPresented: $showSettings) {
            AIModelSettingsSheet()
        }
    }

    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("进程", "Processes"))
                    .font(.headline)
                Text(L10n.t("找出后台运行、占用内存的进程", "Find background processes hogging memory"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if !state.processes.isEmpty {
                Text(L10n.t("占用 \(SizeFormat.human(state.processes.reduce(0) { $0 + $1.memoryBytes }))",
                            "\(SizeFormat.human(state.processes.reduce(0) { $0 + $1.memoryBytes })) used"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await state.scanProcesses() }
            } label: {
                Label(state.hasScannedProcesses ? L10n.t("刷新", "Refresh") : L10n.t("开始扫描", "Start scan"),
                      systemImage: "arrow.clockwise")
            }
            .disabled(state.isScanningProcesses)
            .controlSize(.small)

            if state.hasScannedProcesses && !state.processes.isEmpty {
                Divider().frame(height: 14)
                SelectionToolbar(
                    selectedCount: state.selectedProcessCount,
                    totalCount: filteredProcesses.filter(\.isKillable).count,
                    onSelectAll: { state.setAllVisibleSelected(true) },
                    onDeselectAll: { state.setAllVisibleSelected(false) }
                )
                Button {
                    showKillConfirm = true
                } label: {
                    Label(L10n.t("结束所选 (\(state.selectedProcessCount))",
                                  "End selected (\(state.selectedProcessCount))"),
                          systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(state.selectedProcessCount == 0)
                .help(state.selectedProcessCount == 0
                      ? L10n.t("先勾选要结束的进程", "Select processes first")
                      : L10n.t("结束选中的进程（二次确认）", "End the selected processes (with confirmation)"))

                Button {
                    if !state.modelStore.isConfigured {
                        showSettings = true
                        return
                    }
                    juryRunning = true
                    Task {
                        let ok = await state.aiJudgeProcesses(state.selectedProcesses)
                        await MainActor.run { juryRunning = false; _ = ok }
                    }
                } label: {
                    Label(juryRunning ? L10n.t("AI 判断中…", "AI judging…")
                                       : L10n.t("AI 判断后果", "AI consequence"),
                          systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(state.selectedProcessCount == 0 || juryRunning)
                .help(state.modelStore.isConfigured
                      ? L10n.t("让 AI 判断结束这些进程的后果", "Ask AI to judge the consequence of ending these")
                      : L10n.t("需先在 ⚙ 配置模型", "Configure a model in ⚙ first"))
            }
        }
        // 搜索栏：按进程名或端口号过滤
        if state.hasScannedProcesses && !state.processes.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField(L10n.t("搜索进程名或端口号…", "Search by process name or port…"),
                          text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Theme.bgCanvas, in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        }
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        if state.isScanningProcesses {
            VStack(spacing: 12) {
                ProgressView()
                Text(L10n.t("正在枚举运行中的进程、采样占用…", "Enumerating running processes and sampling usage…"))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !state.hasScannedProcesses {
            VStack(spacing: 14) {
                Image(systemName: "cpu")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text(L10n.t("找出忘关的后台进程", "Find the background processes you forgot to quit"))
                    .font(.title3)
                VStack(spacing: 4) {
                    Text(L10n.t("一键列出后台服务类进程（node / python / docker / brew service 等），看看哪些一直在占你的内存和端口。",
                                "One click lists background service processes (node, python, docker, brew services…) and shows what memory and ports they hold."))
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                Button {
                    Task { await state.scanProcesses() }
                } label: {
                    Label(L10n.t("开始扫描", "Start scan"), systemImage: "magnifyingglass")
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Text(L10n.t("系统关键进程与 Expunge 自身受保护、无法结束，默认不勾选，结束前需二次确认。",
                            "System-critical processes and Expunge itself are protected and can’t be ended; nothing is checked by default, and ending needs a confirmation."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else if state.visibleProcesses.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 48))
                    .foregroundStyle(.green.opacity(0.7))
                Text(L10n.t("这个筛选下没有进程", "No processes in this filter"))
                    .font(.title3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredProcesses.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text(L10n.t("没有匹配「\(searchText)」的进程", "No processes matching \"\(searchText)\""))
                    .font(.title3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            processList
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 搜索过滤：按进程名、命令行参数或端口号匹配。
    private var filteredProcesses: [LiveProcess] {
        let base = state.visibleProcesses
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        let lower = q.lowercased()
        return base.filter { p in
            if p.name.lowercased().contains(lower) { return true }
            if p.executablePath.lowercased().contains(lower) { return true }
            // 命令行参数里也可能出现端口号或项目名
            if p.arguments.joined(separator: " ").lowercased().contains(lower) { return true }
            // 按端口搜索：用 String.contains 而非 ==，支持部分匹配（如 "18" 匹配 18789）
            if p.ports.contains(where: { String($0).contains(q) }) { return true }
            return false
        }
    }

    private var processList: some View {
        List {
            ForEach(filteredProcesses) { p in
                HStack(alignment: .top, spacing: 8) {
                    Toggle("", isOn: Binding(
                        get: { state.selectedPids.contains(p.pid) },
                        set: { _ in state.toggleProcessSelected(p.pid) }
                    ))
                    .labelsHidden()
                    .disabled(!p.isKillable)
                    .padding(.top, 3)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(p.name)
                                .font(.callout)
                                .lineLimit(1)
                            Text("PID \(p.pid)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                            if !p.isKillable {
                                Text(L10n.t("受保护", "Protected"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                        if !p.executablePath.isEmpty {
                            Text(p.executablePath)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        // 后台进程把启动命令打出来，帮用户认出是哪个项目。
                        if p.kind == .background && !p.arguments.isEmpty {
                            Text(p.arguments.joined(separator: " "))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        // 监听的端口
                        if !p.ports.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "network")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                Text(p.ports.map { ":\($0)" }.joined(separator: " "))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        HStack(spacing: 6) {
                            KindPill(kind: p.kind)
                            Text(SizeFormat.human(p.memoryBytes))
                                .font(.caption2.monospacedDigit())
                            Text("·").foregroundStyle(.tertiary)
                            Text(L10n.t("CPU \(String(format: "%.0f", p.cpuPercent))%",
                                        "CPU \(String(format: "%.0f", p.cpuPercent))%"))
                                .font(.caption2.monospacedDigit())
                            Text("·").foregroundStyle(.tertiary)
                            Text("uid \(p.uid)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if let v = state.processVerdicts[p.pid] {
                            ProcessVerdictRow(verdict: v)
                                .padding(.leading, 4)
                                .padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 3)
                .contentShape(Rectangle())
                .contextMenu {
                    if !p.executablePath.isEmpty {
                        Button(L10n.t("复制路径", "Copy path")) { RevealService.copyPath(p.executablePath) }
                    }
                }
            }
        }
        .listStyle(.inset)
    }
}

/// AI 对「结束该进程后果」的判定行，挂在对应进程下方。
private struct ProcessVerdictRow: View {
    let verdict: ProcessVerdict

    private var color: Color {
        switch verdict.level {
        case .high:   return Theme.riskUserDataText
        case .medium: return Theme.riskUncertainText
        case .low:    return Theme.success
        }
    }
    private var icon: String {
        switch verdict.level {
        case .high:   return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low:    return "checkmark.seal.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            Text(verdict.text)
                .font(.system(size: 11.5))
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 进程类别小标签（色 + 字，不靠纯色传达）。
private struct KindPill: View {
    let kind: ProcessKind
    var body: some View {
        let (label, color): (String, Color) = {
            switch kind {
            case .background: return (L10n.t("后台", "BG"), Theme.warning)
            case .app:        return (L10n.t("应用", "App"), Theme.accent)
            case .system:     return (L10n.t("系统", "Sys"), Color.secondary)
            }
        }()
        Text(label)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
}
