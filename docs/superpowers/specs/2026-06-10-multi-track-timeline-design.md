# Multi-Track Timeline — 多轨道时间线 + 丝滑拖动 + 拼接 + 真实波形

**日期**: 2026-06-10
**项目**: clipclip
**平台**: macOS (SwiftUI + AVFoundation + SwiftData)

---

## 1. 功能范围

| 功能 | 说明 |
|------|------|
| **多轨道管理** | 动态新增/删除视频轨道和音频轨道 |
| **丝滑拖动** | clip 直接拖拽（无长按延迟），实时让位动画，跨轨道拖拽 |
| **拼接合并** | 拖拽相邻同源 clip 自动合并 |
| **真实音频波形** | 使用 AVAudioFile 读取 PCM 数据渲染真实波形 |
| **音频轨道样式优化** | 波形颜色渐变、电平感、选中高亮、Mute 控制 |

---

## 2. 数据模型变更

### 新增：Track (SwiftData Entity)

```swift
@Model
final class Track {
    var id: UUID
    var type: TrackType       // .video / .audio
    var orderIndex: Int
    var isMuted: Bool
    var isExpanded: Bool
    
    var project: Project?
    var clips: [Clip]
    
    init(type: TrackType, orderIndex: Int) {
        self.id = UUID()
        self.type = type
        self.orderIndex = orderIndex
        self.isMuted = false
        self.isExpanded = true
        self.clips = []
    }
}

enum TrackType: String, Codable {
    case video
    case audio
}
```

### 变更：Project

```swift
@Model
final class Project {
    // ... existing fields ...
    
    // REMOVE: var clips: [Clip]  (removed direct relationship)
    // ADD:
    var tracks: [Track]
}
```

### 变更：Clip

```swift
@Model
final class Clip {
    // ... existing fields ...
    
    // REMOVE: var project: Project?  (moved to track level)
    // REMOVE: var orderIndex: Int     (position determined by track + sortIndex)
    // ADD:
    var track: Track?
    var sortIndex: Int      // position within the track
}
```

### 状态快照更新

```swift
struct ProjectSnapshot {
    var tracks: [TrackSnapshot]
}

struct TrackSnapshot {
    var id: UUID
    var type: TrackType
    var orderIndex: Int
    var isMuted: Bool
    var clips: [ClipSnapshot]
}

struct ClipSnapshot {
    var id: UUID
    var assetLocalIdentifier: String
    var startTime: Double
    var endTime: Double
    var sortIndex: Int
    var trackID: UUID         // which track the clip belongs to
}
```

---

## 3. UI 布局设计

### 多轨道时间线结构

```
┌──────────────────────────────────────────────────────┐
│ TimelineRuler (时间刻度尺)                              │
├──────────────────────────────────────────────────────┤
│ TrackHeader (视频轨道 1)  [Mute] [-]                  │ ← 轨道头
│ ┌──────────┬──────────┬──────────┬────┐              │
│ │ Clip A   │ Clip B   │ Clip C   │    │ ← 视频 clip  │
│ └──────────┴──────────┴──────────┴────┘              │
├──────────────────────────────────────────────────────┤
│ TrackHeader (音频轨道 1)  [Mute] [-]                  │
│ ┌────────────────────────────────────────────┐        │
│ │ ╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲  (真实波形)              │        │
│ └────────────────────────────────────────────┘        │
├──────────────────────────────────────────────────────┤
│ TrackHeader (音频轨道 2 - 背景音乐)  [Mute] [-]        │
│ ┌────────────────────────────────────────────┐        │
│ │ ╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲                         │        │
│ └────────────────────────────────────────────┘        │
├──────────────────────────────────────────────────────┤
│ [+ 添加视频轨道] [+ 添加音频轨道]                       │ ← 底部工具栏
└──────────────────────────────────────────────────────┘
```

### 轨道头 (TrackHeaderView)

每个轨道左侧有固定宽度的轨道头区域：
- 轨道类型图标 (video.circle / music.note)
- 轨道名称（可双击编辑）
- Mute 按钮（小喇叭图标，点按切换）
- 删除轨道按钮（hover 显示）

### 时间线轨道布局

```
TrackRow
├── TrackHeader (固定宽度 120)
│   ├── TypeIcon
│   ├── TrackName
│   ├── MuteButton
│   └── DeleteButton (hover)
└── TrackContent (ScrollView .horizontal)
    ├── ClipView (多个)
    │   ├── ThumbnailStrip (视频) / Waveform (音频)
    │   ├── TrimHandle (左右)
    │   └── DurationLabel
    ├── DropZoneIndicator (拖拽时的占位提示)
    └── PlayheadView (覆盖所有轨道)
```

---

## 4. 关键交互设计

### 4.1 丝滑拖动

| 阶段 | 行为 |
|------|------|
| **初始** | clip 处于正常位置，normal scale (1.0) |
| **Drag 开始** | clip 放大至 1.05x，添加阴影，zIndex 提升 |
| **Drag 进行中** | clip 跟随鼠标/手指移动 |
| | 其他同轨道 clip 实时计算让位（弹簧动画） |
| | 到达其他轨道区域时自动切换轨道 |
| | 如果附近有同源 clip（来自同一资产），高亮显示「拼接」提示 |
| **Drag 结束** | clip 吸附到目标位置，或以 0.3 弹簧动画归位 |
| | 如果是同源相邻 clip，触发合并 |

**数据流**:
```
onDragChanged: (clipID, position) →
    editorVM.moveClip(clipID, toTrack: trackID, toIndex: sortIndex) →
    reorder animations →
    rebuild composition lazily

onDragEnded: (clipID) →
    checkJoinCandidate(clipID) →
    if joinable: joinClips(clipA, clipB) →
    refreshPlayer()
```

### 4.2 拼接合并

**触发条件**:
- 两个 clip 在**同一条轨道**上
- 来自**同一个源文件**（相同 assetLocalIdentifier）
- 一个 clip 的 endTime 恰好等于另一个的 startTime（无缝相邻）

**行为**:
- 拖拽时，clip 靠近同源 clip 时出现「拼接高亮」效果
- 松手时自动合并为单个 clip
- Clip A.startTime = 原起点, Clip A.endTime = Clip B.endTime
- 删除 Clip B

### 4.3 跨轨道拖拽

- 视频 clip 只能拖到视频轨道
- 音频 clip 只能拖到音频轨道
- 在轨道间拖拽时，目标轨道显示蓝色插入指示线
- 如果目标轨道为空，自动居中放置

### 4.4 新建轨道

- 底部工具栏有 [+ 视频轨道] [+ 音频轨道] 按钮
- 点击后在当前轨道列表末尾追加
- 新建轨道默认命名为「视频轨道 N」/「音频轨道 N」
- 最大轨道数：视频 8 条，音频 8 条（可配置）

### 4.5 删除轨道

- 删除轨道时弹出确认（防止误删）
- 轨道内有 clip 时警告「此轨道包含 N 个 clip，确认删除？」
- 删除轨道同时删除其所有 clip

---

## 5. 实时波形渲染

### 实现方案

```swift
class WaveformGenerator {
    /// 读取音频文件生成波形数据
    static func generateWaveform(url: URL, samplesPerSecond: Int = 20) async -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: ...)
        try audioFile.read(into: buffer)
        
        // 提取 PCM 数据，按 samplesPerSecond 降采样
        // 返回振幅数组 [0...1]
    }
}
```

- 波形数据按 clip 的 asset 缓存（NSCache）
- 渲染时每个 clip 根据 timeScale 决定显示精度
- 使用 Canvas API 或 Shape 绘制平滑波形曲线
- 波形颜色：轨道主题色 + 选中时高亮

### 缓存策略

```
WaveformCache.shared
    .get(for: assetIdentifier) -> [Float]?
    .set(data, for: assetIdentifier)

// 在 asset 第一次显示时异步生成
// Cache 上限 50 个文件，LRU 淘汰
```

### 渲染细节

- 波形高度：轨道高度的 60-70%
- 波形颜色：线性渐变（从主色到半透明）
- 选中态：波形填充纯色 + 背景高亮
- 静音态：波形变灰 + 透明度降低

---

## 6. 动画系统

| 场景 | 动画类型 | 时长 |
|------|---------|------|
| clip 被拖起 | scale + shadow + spring | 0.2s |
| 其他 clip 让位 | position spring | 0.3s |
| clip 归位 | spring (damping 0.7) | 0.3s |
| 合并拼接 | scale + fade out (clipB) | 0.2s |
| 新建轨道 | slide down | 0.25s |
| 删除轨道 | slide up + fade | 0.25s |

---

## 7. 文件变更清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `Models/Track.swift` | **新建** | Track SwiftData entity |
| `Models/Track.swift` | + WaveformCache | 波形数据管理器 |
| `Models/Clip.swift` | 修改 | 移除 project 引用，添加 track/sortIndex |
| `Models/Project.swift` | 修改 | 添加 tracks，移除 clips |
| `ViewModels/EditorViewModel.swift` | 重写 | track-based 操作，多轨道管理 |
| `Views/VideoEditor/TimelineView.swift` | 重写 | 动态轨道循环，拖拽逻辑重写 |
| `Views/VideoEditor/TimelineClipView.swift` | 修改 | 支持真实波形，新样式 |
| `Views/VideoEditor/TrackHeaderView.swift` | **新建** | 轨道头控件 |
| `Views/VideoEditor/TrackRowView.swift` | **新建** | 单轨道行 |
| `Views/VideoEditor/WaveformView.swift` | **新建** | 波形渲染视图 |
| `Views/VideoEditor/VideoEditorView.swift` | 修改 | 工具栏添加轨道控制 |
| `Utils/UndoManager.swift` | 修改 | 支持 Track 状态快照 |
| `Engines/VideoComposer.swift` | 修改 | 支持多轨道 AVComposition |

---

## 8. 迁移策略

由于 SwiftData model 变更，需要处理数据迁移：

1. **轻量迁移**: SwiftData 支持轻量 Schema 迁移（添加/删除属性）
2. **手动迁移**: Project.clips → Project.tracks 关系变更需要手动处理
3. **降级策略**: 如果已有用户数据，提供一次性迁移脚本

实际项目中如果尚无生产数据，直接删除 app 重装即可。开发阶段可直接重置 Schema。

---

## 9. 排除范围（此版本不做）

- 视频轨道间转场特效
- 关键帧动画
- 轨道锁定
- 轨道 Solo 模式
- 编组 (Group) 轨道
- 音轨效果器 (EQ, Reverb)
