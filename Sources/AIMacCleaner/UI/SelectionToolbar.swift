import SwiftUI

/// 批量选择开关，扫描页 / 残留页 / 历史页共用。
///
/// 行为是直接的开关：点一下全选，再点一下全不选。图标随状态变。
/// 已选计数不再显示在这里 —— 各页面标题区已经展示「已选 N 项 · X GB」，
/// 放这里会导致选中时工具栏宽度突变，把旁边的按钮/框顶到左边。
struct SelectionToolbar: View {
    /// 当前已选数量，用于决定这一次点击是全选还是全不选。
    let selectedCount: Int
    /// 可选总数。为 0 时按钮禁用。
    let totalCount: Int
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    /// 是否已经全选。据此决定点击行为和图标。
    private var allSelected: Bool {
        totalCount > 0 && selectedCount == totalCount
    }

    var body: some View {
        Button {
            if allSelected { onDeselectAll() } else { onSelectAll() }
        } label: {
            Image(systemName: allSelected ? "checkmark.circle.fill" : "checklist.checked")
                .foregroundStyle(allSelected ? Color.accentColor : Color.secondary)
        }
        .disabled(totalCount == 0)
        .help(allSelected ? L10n.t("全不选", "Deselect all")
                          : L10n.t("全选", "Select all"))
    }
}
