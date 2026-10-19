# GC-MS Quant Mass Manager：全量重算 → 增量重算

> 状态：未开工。用户已确认要本地留交接文档，未决定是否上 GitHub issue / PR。
> 作者：fork 内 AI 协作会话。日期：2026 年初（具体看 git log）。

## TL;DR

GC-MS Alignment 里的 **Quant mass manager**（`QuantmassBrowser`）允许用户逐 spot 编辑 `QuantMass`，但点 Finish 后会走**全文件 × 全 spot** 的 `RecalculatePeakQuantificationAsync`，对每个 spot 重新跑 `GapFillCore` → `SetAlignmentChromPeakFeature`，**无条件覆盖** `ChromXsTop/Left/Right`、`PeakHeightTop/Left/Right`、`PeakAreaAboveZero/Baseline`、`PeakShape.SignalToNoise`。结果：用户手工核对过的峰边界、峰高、峰面积会被一起冲掉，即便他只改了一个 spot 的 QuantMass。

预期行为：只对 **QuantMass 真的变了** 的 spot 重算；其他 spot 完全不动；EIC 序列化只 patch 受影响的索引而不是整体覆写。

## 用户原始诉求（中文转写）

> 我记得是可以单独修改每个物质的定量离子的，但是好像我记得如果我处理了 ALIGNMENT 结果，比如手工核对了，如果突然改了某个物质的定量离子，那整个 ALIGNMENT 会被重置，那我之前所做的手工核对就没有了，是否可以修改定量离子，只影响到对应的物质的定量离子，峰高，峰面积这些信息，其他不相关的不要动？

随后追问：

1. 是否只有 GC-MS 有这问题？ → 确认只有 GC-MS（LC-MS / IMMS / DIMS / LC-IM-MS 没有 Quant mass manager 入口）。
2. 看的是不是 MSDIAL5 代码？ → 是；MSDIAL4 (`src/MSDIAL4/`) 也有同一入口，行为一致（甚至更无条件）。

## 范围

| 模态 | 是否受影响 | 备注 |
| --- | --- | --- |
| GC-MS | **是** | 唯一有此 UI 入口和重算路径的模态 |
| LC-MS / LC-IM-MS / IMMS / DIMS | 否 | 没有 Quant mass manager；`MassCenter` 不可由用户编辑；其他注释字段的 setter 都不触发 chromatogram 重提或 peak picking 重跑 |
| MSDIAL4 GC-MS | **是**（同 MSDIAL5） | 同一行为，下面单独列 |

## 现状：UI 入口

MSDIAL5：

- `src/MSDIAL5/MsdialGuiApp/ViewModel/Gcms/GcmsAlignmentViewModel.cs:77` 注册 `ShowQuantmassBrowserCommand`。
- `src/MSDIAL5/MsdialGuiApp/ViewModel/Gcms/QuantmassBrowserViewModel.cs` `FinishCommand` 触发 `QuantmassBrowserModel.RunQuantificationAsync`。
- `src/MSDIAL5/MsdialGuiApp/View/Gcms/QuantmassBrowserView.xaml:39-46` 是一个 `DataGrid`，`QuantMass` 列用 `TextBox` + `LostFocus` 更新绑定，可逐 spot 改。

MSDIAL4：

- `src/MSDIAL4/MsDial/Quantmass browser/QuantmassBrowser.xaml.cs` 的 `Update` DelegateCommand 调用 `src/MSDIAL4/MsDial/Process for GC/QuantmassUpdateProcess.cs` 的 `Execute`。

## 现状：代码路径

### MSDIAL5

```
QuantmassBrowserViewModel.FinishCommand
  → QuantmassBrowserModel.RunQuantificationAsync                          (Model/Gcms/QuantmassBrowserModel.cs:37)
    → PeakQuantCalculation.RecalculatePeakQuantificationAsync            (MsdialGcMsApi/Algorithm/PeakQuantCalculation.cs:29)
      → PeakRecalculationAsync                                          (:50)
        for each (file, spots)                                          (:63-79)
          → CollectAlignmentPeaksAsync                                  (:85)
            for each (peak, spot)                                       (:97)
              _gapFiller.UpdateQuantMass(rawSpectra, spot, fileId)      (:98)
                → GcmsGapFiller.UpdateQuantMass                           (MsdialGcMsApi/Algorithm/Alignment/GcmsGapFiller.cs:53)
                  → GapFillCore                                          (:74)
                    → SetAlignmentChromPeakFeature                      (:209)
                       // 强制覆盖：ChromScanIdTop/Left/Right、ChromXsTop/Left/Right、
                       //            PeakHeightTop/Left/Right、
                       //            PeakAreaAboveZero/Baseline、PeakShape.SignalToNoise
              _accessor.AccumulateChromatogram                          (:101)
      → SerializeSpotInfo                                                (:111)
        // 把**所有** spot 的 chromatogram 整体覆写写到 alignmentFile.EicFilePath
```

关键文件 / 行号：

| 位置 | 作用 |
| --- | --- |
| `src/MSDIAL5/MsdialGcMsApi/Algorithm/PeakQuantCalculation.cs:29-79` | `RecalculatePeakQuantificationAsync` + `PeakRecalculationAsync`：遍历所有 analysis files 和**所有** spots |
| `src/MSDIAL5/MsdialGcMsApi/Algorithm/PeakQuantCalculation.cs:85-105` | `CollectAlignmentPeaksAsync`：每个 (peak, spot) 调 `UpdateQuantMass` + `AccumulateChromatogram` |
| `src/MSDIAL5/MsdialGcMsApi/Algorithm/PeakQuantCalculation.cs:111-120` | `SerializeSpotInfo`：整体覆写 EIC |
| `src/MSDIAL5/MsdialGcMsApi/Algorithm/Alignment/GcmsGapFiller.cs:53-62` | `UpdateQuantMass`：取所有 peak → 取中心 / 宽度 → `GetPeaks` → `GapFillCore` |
| `src/MSDIAL5/MsdialGcMsApi/Algorithm/Alignment/GcmsGapFiller.cs:209-238` | `SetAlignmentChromPeakFeature`：无条件覆盖 peak picking 字段 |
| `src/MSDIAL5/MsdialGuiApp/Model/Gcms/QuantmassBrowserModel.cs:37` | 把**所有** spot 喂给重算，没有任何 dirty 过滤 |

### MSDIAL4

```
QuantmassBrowserVM.Update
  → QuantmassUpdateProcess.Execute                                     (MSDIAL4/MsDial/Process for GC/QuantmassUpdateProcess.cs:24)
    → bgWorkerInitialize                                                (:30)
      MessagePackHandler.SaveToFile<AlignmentResultBean>(...)           (:38)  // 整体 round-trip 序列化
      LoadFromFile<AlignmentResultBean>(...)                            (:42)
    → PeakAlignment.QuantmassUpdate                                     (MSDIAL4/MsdialGcmsProcessStandard/Algorithm/PeakAlignment.cs:298)
      for each file                                                     (:317)
        for each alignmentSpot                                          (:344)
          if peakProperty.PeakID < 0: gapFilling(...)                   (:348)
          else:        recalculationByQuantMass(...)                    (:353)
            // 同样无条件覆盖 peakProperty.RetentionTime/Variable/Area/RetentionTimeLeft/Right/SignalToNoise
            // (PeakAlignment.cs:824-840 附近)
      序列化对齐 EIC 到 tmpFolder
    → AlignedMS1DecStorageProcess.Finalize
```

关键文件 / 行号：

| 位置 | 作用 |
| --- | --- |
| `src/MSDIAL4/MsDial/Quantmass browser/QuantmassBrowser.xaml.cs:97 closingmethod()` | Cancel 时按 `AlignmentidToOriginalQuantmass` 回滚；**一旦点了 Update 已经落盘，救不回来** |
| `src/MSDIAL4/MsDial/Process for GC/QuantmassUpdateProcess.cs:24-52` | `Execute` + `bgWorkerInitialize`：先 Save 再 Load，每次点击整体 round-trip |
| `src/MSDIAL4/MsdialGcmsProcessStandard/Algorithm/PeakAlignment.cs:298-388` | `QuantmassUpdate`：双重 for 循环，无 dirty 过滤 |
| `src/MSDIAL4/MsdialGcmsProcessStandard/Algorithm/PeakAlignment.cs:629-851` | `recalculationByQuantMass`：取 sPeaklist → 重新挑 `localMinLeft/maxID/localMinRight` → 覆盖 RT / area / height / S/N |

## 为什么只有 GC-MS 受影响

`QuantMass` 字段虽然在 `AlignmentSpotProperty` (`src/MSDIAL5/MsdialCore/DataObj/AlignmentSpotProperty.cs:36`) 上对所有模态都有 schema —— 那是老 MSDIAL4 留下来的数据 schema —— 但**只有 GC-MS 用它做 EIC 提取**。代码注释自己都写了 `// gcms`。LC-MS / IMMS / DIMS / LC-IM-MS 的 EIC 提取 m/z 就是 spot 本身的 `MassCenter` / `Mass`（即 precursor m/z，观测得到的），并且 `MassCenter` 在 GUI 路径上根本没有 setter，spot 级别的 m/z 用户改不了。

其他模态允许编辑的字段都是纯标签 / 注释字段（`AdductType` / `Name` / `Ontology` / `Comment` / `IonAbundanceUnit` / `FillPercentage`），setter 都只 `OnPropertyChanged`，不会触发 chromatogram 重提或 peak picking 重跑。

LC-MS / IMMS / DIMS / LC-IM-MS 上"接近"但**不**等价的入口是 "Peak curation → Modify aligned peaks"（`AlignedChromatogramModificationViewModelLegacy.UpdatePeakInfo`，`src/MSDIAL5/MsdialGuiApp/ViewModel/PeakCuration/AlignedChromatogramModificationViewModelLegacy.cs:127`），它只更新**被编辑的那个 spot** 的对应 `AlignedChromPeakFeature`，不会动其他 spot，也没有 peak picking 重跑。

## 已经存在的"手工核对"标志（但没人读）

`AlignmentSpotProperty.IsManuallyModifiedForQuant` 和 `AlignmentChromPeakFeature.IsManuallyModifiedForQuant` 字段都在：

- 设值点：`AlignedChromatogramModificationViewModelLegacy.UpdatePeakInfo`（line 127）和 `p.Model.IsManuallyModifiedForQuant = true`（line 138）—— 用户手工改峰边界时设。
- 读点：仅在 export（`Export/ResultExport.cs:331` 和 `Export/IMetadataAccessor.cs:128` / `Export/ProteomicsAccessor.cs:72`）。

`GcmsGapFiller.UpdateQuantMass` 和 `SetAlignmentChromPeakFeature` 都不读这个 flag，挡不住重算。这是 MSDIAL5 路径上的修复契机。

MSDIAL4 没有等价标志 —— 最简单的等价护栏就是只对 dirty spot 的每个 `(file, spot)` 重算，没改的不动。

## 设计决策（待定）

这四项要落地前先和用户 / 上游对齐：

### 1. EIC 文件改写方式

`PeakQuantCalculation.SerializeSpotInfo` 现在是"打开文件 → 写 N 个 spot → 关闭"。改法：

- **方案 A：in-place patch**。需要先定 EIC 文件的 spot 索引格式（按 spot 物理 ID 偏移 / 按 AlignmentID 索引 / 加一个小索引头）。需要阅读 `ChromatogramSerializer<ChromatogramSpotInfo>` / `ChromatogramSerializer<ChromatogramPeakInfo>` 的序列化格式，看是否支持定位到第 N 个 spot。
- **方案 B：写到新文件再 atomic rename**。实现简单，但 GC-MS 通常一个 alignment 文件对应多个文件数十万 peak，IO 翻倍。
- **方案 C：保留整体覆写，但跳过 unchanged spot 的 chromatogram 收集**。最保守，只是把"传所有 spot 给重算"改成"只传 dirty spot"。对其他 spot 的 EIC 二进制数据不重新提取也不重新写，但 EIC 文件整体会被 `SerializeN` 覆写一遍。实现最简单，修复了"手工核对被覆盖"这一核心问题。

建议起步选 **C**，先把核心 bug 修了；EIC 的 partial-write 优化放在后续。

### 2. "尊重手工修改"的语义

- **方案 X：跳过整个 peak picking**。`SetAlignmentChromPeakFeature` 检查 `IsManuallyModifiedForQuant`，若 true 则保留现有 `ChromXsTop/Left/Right`、`PeakHeightTop/Left/Right`、`PeakAreaAboveZero/Baseline`，只更新 `PeakShape.SignalToNoise`（用新的 ChromXsTop / EstimatedNoise 重算）。
- **方案 Y：保留 ChromXs 但重算 height/area**。在新的 QuantMass 下重新提取 chromatogram，但保留 `ChromXsTop/Left/Right` 不变；只重算 height/area。
- **方案 Z：不读 flag，但只对 dirty spot 重算**。根本没改的 spot 不进入重算路径，自然就不被覆盖。

方案 Z 已经能解决用户的核心痛点；方案 X 是更稳的护栏。两者可以叠加。

### 3. dirty spot 收集方式

- **方案 ①**：在 `AlignmentSpotPropertyModel.QuantMass` setter 里 push 到一个 `ReactivePropertySlim<HashSet<int>>`。
- **方案 ②**：参考 MSDIAL4 的 `AlignmentidToOriginalQuantmass`，在 Finish 时用 `oldValue != newValue` 比对，得到 dirty 集合。
- **方案 ③**：直接对比 `innerModel.QuantMass` 和 `AlignmentidToOriginalQuantmass[alignmentID]`，最简单。

方案 ③ 实现最简单，不需要改 model 层。① 和 ② 在 dirty 集合需要跨多个 UI 触发点共享时更有用，目前只有一个触发点（QuantmassBrowserModel.RunQuantificationAsync），③ 够用。

### 4. MSDIAL4 要不要一起改

仓库里两个 MSDIAL 大版本都有这问题。两种选择：

- 只修 MSDIAL5。MSDIAL4 是 legacy，仓库里修不修看上游策略。
- 一起修。MSDIAL4 改法对称：把 `PeakAlignment.QuantmassUpdate` 的循环改成只对 dirty spot 跑，`recalculationByQuantMass` / `gapFilling` 内部可以保持。MSDIAL4 没有 `IsManuallyModifiedForQuant` 标志，所以护栏只能靠"只对 dirty spot 重算"这一条。

## 建议的修复步骤（按依赖顺序）

1. **MSDIAL5 step 1 — dirty 集合**：`QuantmassBrowserModel` 构造时拍一份 `Dictionary<int, double> originalQuantMass`；`RunQuantificationAsync` 里比对出 dirty spot。
2. **MSDIAL5 step 2 — 部分 peak picking**：把 dirty spot 列表（而不是全部 spot）传给 `PeakQuantCalculation.RecalculatePeakQuantificationAsync` / `PeakRecalculationAsync` / `CollectAlignmentPeaksAsync`。
3. **MSDIAL5 step 3 — 手工护栏**：`GcmsGapFiller.SetAlignmentChromPeakFeature`（或更上层 `UpdateQuantMass`）检查 `AlignmentChromPeakFeature.IsManuallyModifiedForQuant`，为 true 时只更新 SignalToNoise。
4. **MSDIAL5 step 4 — EIC 序列化**：先保持整体覆写，验证语义对；后续再做 in-place patch 优化。
5. **MSDIAL5 step 5 — 最小测试**：在 `tests/` 找最近的 PeakQuantCalculation 测试或在新建的 `MsdialGcMsApi.Tests` 加一个 dirty 集合 → 重算范围的单元测试。
6. **MSDIAL4（可选）**：把 `PeakAlignment.QuantmassUpdate` 的内层 `for j` 改成只对 dirty spot 跑；其他不动。

## 临时绕过（不改代码的 workaround）

在最终修复落地之前：

1. 编辑 QuantMass 之前，先把 `*.arf2` + `*.EIC.aef`（如果是 GC-MS）整个备份。
2. 改完 QuantMass 后，按"Peak curation → Modify aligned peaks"重新做一遍被误覆盖的 spot 的峰边界核对。`IsManuallyModifiedForQuant` 列可以在导出 CSV 里快速筛（`Export/ResultExport.cs:331`）。
3. 或者只在"还没开始手工核对"的早期阶段用 Quant mass manager；手工核对过之后基本就别再碰它。

## 验证用例

- 准备一个 GC-MS alignment，至少 5 个 spot，其中 3 个手工改过 `ChromXsTop/Left/Right` / `PeakHeightTop`（确保 `IsManuallyModifiedForQuant=true`）。
- 在 Quant mass manager 里改其中一个 spot 的 QuantMass，点 Finish。
- 期望：被改的 spot 的 `QuantMass`、`PeakHeightTop`、`PeakAreaAboveZero` 都变了；其他 spot 的 `ChromXsTop/Left/Right`、`PeakHeightTop`、`PeakAreaAboveZero` 完全不变。
- 当前行为：全部 spot 的 `ChromXsTop/Left/Right`、`PeakHeightTop`、`PeakAreaAboveZero` 都会被重算一次（且可能因为 peak picking 的微小差异而漂移）。

## 相关 commit / PR

- `3972ff68 Initial implementation of quant mass manger for gcms project (#657)` —— Quant mass manager 首次落地，里面就用 `UpdateQuantMass` 全 spot 重算的写法，是这个 bug 的源头。
- `684ba02d Set AlignmentChromPeakFeature quant mass in gap filling (#717)` —— 在 gap filling 里也设 `QuantMass`。
- `d06ed9a1 added quant mass property to masscenter (#714)` —— 把 QuantMass 接到 MassCenter。
- `78f3c050 fixed mis-quant mass assignment in gcms peak alignments (#712)`。

没找到直接相关的 issue 编号（搜索能力受限，没直接查 GitHub API 成功）。

## 待办 / 留给接手的人

- [ ] 和用户确认设计决策 1-4。
- [ ] 决定是否上 GitHub issue（fork `QizhiSu/msdial` 还是 upstream `systemsomicslab/MsdialWorkbench`）。
- [ ] 决定是否同时修 MSDIAL4。
- [ ] 看 `ChromatogramSerializer<ChromatogramSpotInfo>` / `ChromatogramSerializer<ChromatogramPeakInfo>` 的序列化格式，决定是否值得做 in-place patch。
- [ ] 写最小单元测试覆盖 "dirty spot 集合 → 重算范围" 的语义。
- [ ] 跑 `MsdialGcMsApi` 现有测试 + 手动跑 GUI 验证。
- [ ] PR / commit 前 `git diff --check` + `git status`，按 `docs/agents/development-workflow.md` handoff 章节出报告。

## 备注

- 这份文档**没有 commit**。写完即停在这里。
- AGENTS.md 要求 "Do not commit, push, change remotes, or publish artifacts unless the user explicitly asks." —— 接手的人继续等用户决定。
- `docs/handoff/` 这个目录是这次新建的，之前不存在；只放本交接文档，没有别的 in-progress 文件。