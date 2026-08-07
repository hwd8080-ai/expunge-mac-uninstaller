import Foundation

struct RemovalPlan: Identifiable {
    let id = UUID()
    let targetName: String
    let scannedAt: Date
    let artifacts: [Artifact]

    init(targetName: String, artifacts: [Artifact]) {
        self.targetName = targetName
        self.scannedAt = Date()
        self.artifacts = artifacts
    }

    /// 已勾选项的合计大小（实际会释放的空间）
    var totalSize: Int64 {
        artifacts.filter(\.selected).reduce(0) { $0 + $1.size }
    }

    /// 扫到的全部项合计大小（含未勾选的 userData）。
    /// 与 totalSize 分开，避免「发现 12 项，合计 689 MB」把 3.6 GB 的容器数据藏起来。
    var scannedTotalSize: Int64 {
        artifacts.reduce(0) { $0 + $1.size }
    }

    var selectedCount: Int {
        artifacts.filter(\.selected).count
    }

    var grouped: [(ArtifactCategory, [Artifact])] {
        let dict = Dictionary(grouping: artifacts, by: \.category)
        return ArtifactCategory.allCases.compactMap { cat in
            guard let items = dict[cat], !items.isEmpty else { return nil }
            return (cat, items.sorted { $0.path < $1.path })
        }
    }
}
