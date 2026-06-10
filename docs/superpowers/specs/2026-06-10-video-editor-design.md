# Video Editor — iMovie-like 视频剪辑功能设计

**日期**: 2026-06-10
**项目**: clipclip
**平台**: iOS Universal (iPad + iPhone)
**技术栈**: SwiftUI + AVFoundation + SwiftData

---

## 1. 功能范围 (MVP)

| 功能 | 说明 |
|------|------|
| **视频导入** | 从系统相册选取视频（PHPickerViewController） |
| **时间线编辑** | 横向滚动时间线，clip 缩略图排列，支持拖拽调整顺序 |
| **视频裁剪 (Trim)** | 每个 clip 左右边缘拖拽手柄，调整起止时间 |
| **分割 (Split)** | 播放头位置一键切开视频 |
| **预览播放器** | AVPlayer 嵌入 SwiftUI，播放/暂停、进度跳转 |
| **撤销/重做** | 基于 UndoStack 的简单撤销重做 |
| **导出** | AVMutableComposition + AVAssetExportSession 合成保存到相册 |

**已排除**: 多音轨、画中画、特效滤镜、转场动画（留待后续版本）

---

## 2. 系统架构

```
┌────────────────────────────────────────────────┐
│  UI Layer (SwiftUI Views)                       │
│  VideoEditorView / TimelineView / PreviewView   │
│  TrimHandle / ClipThumbnail / Playhead          │
├────────────────────────────────────────────────┤
│  ViewModel Layer (ObservableObject)             │
│  EditorViewModel                                │
│  ExportViewModel                                │
├────────────────────────────────────────────────┤
│  Engine Layer (AVFoundation)                    │
│  VideoComposer / ThumbnailGenerator / Exporter  │
├────────────────────────────────────────────────┤
│  Model Layer (SwiftData)                        │
│  Project / Clip                                 │
└────────────────────────────────────────────────┘
```

### 架构原则

- **单向数据流**: 用户操作 → ViewModel → 更新 Model → View 响应
- **ViewModel 驱动**: View 仅做布局和事件转发，所有逻辑在 ViewModel
- **懒重建**: AVComposition 仅在操作完成后重建，操作进行中仅做 UI 预览
- **SwiftData 持久化**: 项目 + clip 数据通过 SwiftData 持久化

---

## 3. 数据模型

### Project

```swift
@Model
final class Project {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var clips: [Clip]           // 有序关系
    @Attribute(.externalStorage) var thumbnailData: Data?
    
    init(title: String) { ... }
}
```

### Clip

```swift
@Model
final class Clip {
    var id: UUID
    @Relationship(inverse: \Project.clips) var project: Project?
    
    var assetLocalIdentifier: String   // PHAsset localIdentifier
    var startTime: Double              // CMTime 转为 seconds Double
    var endTime: Double
    var duration: Double               { endTime - startTime }
    var orderIndex: Int                // 排序索引
    var speed: Double                  // 播放速度 (默认 1.0)
    var volume: Float                  // 音量 (默认 1.0)
    
    var timelineWidth: Double { duration * timeScale }
    
    init(assetIdentifier: String, startTime: Double, endTime: Double, orderIndex: Int) { ... }
}
```

### 状态快照 (用于撤销)

```swift
struct ProjectSnapshot {
    var clips: [ClipSnapshot]
}

struct ClipSnapshot {
    var id: UUID
    var assetLocalIdentifier: String
    var startTime: Double
    var endTime: Double
    var orderIndex: Int
}
```

---

## 4. UI 布局

### iPad 横屏主布局

```
┌──────────────────────────────────────────────────────────┐
│  [← 项目列表]  项目名称              [撤销] [导出]  ⋮     │  ← 顶部栏
├───────────────────────┬──────────────────────────────────┤
│                       │                                  │
│   预览播放器           │   时间线编辑区                    │
│                       │   ┌───┬───┬───┬───┬───┬───┐      │
│   ▶ 预览              │   │ C │ C │ C │ C │ C │ C │      │
│                       │   │ l │ l │ l │ l │ l │ l │      │
│   ───●──────── 进度    │   │ i │ i │ i │ i │ i │ i │      │
│                       │   │ p │ p │ p │ p │ p │ p │      │
│                       │   │ 1 │ 2 │ 3 │ 4 │ 5 │ 6 │      │
│   🔊 音量              │   └───┴───┴───┴───┴───┴───┘      │
│                       │   ◀═══════●══════════▶ 播放头     │
│                       │   [➕添加] [✂️分割] [🗑删除]       │
├───────────────────────┴──────────────────────────────────┤
│  底部工具条: 添加到项目 + 时间线缩放滑块                     │
└──────────────────────────────────────────────────────────┘
```

### UI 组件树

```
VideoEditorView
├── TopBar
│   ├── BackButton
│   ├── TitleText
│   ├── UndoButton / RedoButton
│   └── ExportButton
├── HSplitView (iPad) / VStack (iPhone)
│   ├── PreviewPanel
│   │   ├── PlayerView (AVPlayer via AVPlayerViewController)
│   │   ├── PlaybackControls (Play/Pause, TimeLabel, SeekBar)
│   │   └── VolumeSlider
│   └── TimelinePanel
│       ├── TimelineRuler (时间刻度尺)
│       ├── ScrollView(.horizontal)
│       │   └── TimelineContent
│       │       ├── ClipRow (每个 clip 的缩略条)
│       │       │   ├── TrimHandle (leading)
│       │       │   ├── ThumbnailStrip (缩略图序列)
│       │       │   └── TrimHandle (trailing)
│       │       └── PlayheadView (红色竖线)
│       └── TimelineToolbar
│           ├── AddClipButton
│           ├── SplitButton
│           └── DeleteButton
└── BottomBar (iPhone)
    └── 精简版工具条
```

---

## 5. 关键交互设计

### 5.1 时间线 Clip 拖拽重排

```
1. 用户长按 clip 0.3s → 触发 DragGesture
2. clip 浮动放大, 带阴影
3. 横向拖动 → 实时计算插入位置
4. 其他 clip 让位动画
5. 松手 → 确认新排序 → 更新 orderIndex
```

### 5.2 裁剪手柄

```
1. 选中 clip → 显示左右裁剪手柄
2. 拖拽左手柄 → Clip.startTime 跟随变化
   - 实时更新预览裁剪范围
   - 限制: startTime >= 0, endTime - startTime >= 0.5s
3. 拖拽右手柄 → Clip.endTime 跟随变化
   - 限制: endTime <= assetDuration, endTime - startTime >= 0.5s
4. 拖拽结束 → 持久化新 startTime/endTime
```

### 5.3 分割操作

```
1. 用户拖拽播放头到分割位置 (或直接点击时间线位置)
2. 点击 [分割] 按钮
3. 当前 clip 一切为二：
   Clip A: endTime = 播放头时间
   Clip B: startTime = 播放头时间, endTime = 原 endTime
4. Clip B 插入到 Clip A 之后
5. 重建 AVComposition
```

### 5.4 播放器同步

```
1. 播放开始时: 记录 player.currentTime() 驱动 UI
2. 播放中: 
   - 播放头沿时间线平滑移动
   - 时间线自动滚动保持播放头可见
3. 播放到时间线末尾: 自动停止
4. 拖动播放头: player.seek(to:)
```

---

## 6. 手势系统

| 手势 | 触发 | 作用对象 |
|------|------|---------|
| Tap | 点击 | 选中 clip / 定位播放头 |
| LongPress (0.3s) + Drag | 长按拖拽 | clip 重排 |
| Drag (边缘) | 水平拖拽 | 裁剪手柄 |
| Pan (播放头) | 水平拖拽 | 移动播放头 |
| Magnification | 双指缩放 | 时间线缩放比例 |
| Tap (播放按钮) | 点击 | 播放/暂停 |

---

## 7. 视频合成与导出 (AVFoundation)

### 合成流程

```swift
func buildComposition() -> AVPlayerItem {
    let composition = AVMutableComposition()
    let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
    
    var currentTime = CMTime.zero
    
    for clip in sortedClips {
        let asset = AVURLAsset(url: clip.assetURL)
        let assetVideoTrack = asset.tracks(withMediaType: .video).first!
        let assetAudioTrack = asset.tracks(withMediaType: .audio).first
        
        let timeRange = CMTimeRange(start: clip.startCMTime, duration: clip.durationCMTime)
        
        try videoTrack?.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
        try audioTrack?.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
        
        currentTime = CMTimeAdd(currentTime, clip.durationCMTime)
    }
    
    let playerItem = AVPlayerItem(asset: composition)
    return playerItem
}
```

### 导出流程

```swift
func export(composition: AVMutableComposition, preset: String = AVAssetExportPresetHighestQuality) {
    let exportSession = AVAssetExportSession(asset: composition, presetName: preset)
    exportSession?.outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
    exportSession?.outputFileType = .mp4
    
    // 进度回调 → @Published var exportProgress: Double
    // 完成 → PHPhotoLibrary.shared().performChanges { ... }
}
```

---

## 8. 错误处理

| 场景 | 处理 |
|------|------|
| 相册权限拒绝 | 弹窗引导用户去设置开启 |
| 视频加载失败 | 显示错误提示，clip 显示为占位符 |
| 导出失败 | 显示错误信息 + 重试按钮 |
| 存储空间不足 | 导出前检查可用空间 |
| 不支持的视频格式 | 导入时检测，提示不支持的格式 |

---

## 9. 项目文件结构

```
clipclip/
├── Models/
│   ├── Project.swift
│   └── Clip.swift
├── ViewModels/
│   ├── EditorViewModel.swift
│   ├── ProjectListViewModel.swift
│   └── ExportViewModel.swift
├── Views/
│   ├── ProjectListView.swift
│   ├── VideoEditor/
│   │   ├── VideoEditorView.swift
│   │   ├── TimelineView.swift
│   │   ├── TimelineClipView.swift
│   │   ├── TrimHandleView.swift
│   │   ├── PlayheadView.swift
│   │   ├── TimelineRulerView.swift
│   │   └── PreviewPlayerView.swift
│   └── Shared/
│       ├── PlayerView.swift
│       └── LoadingIndicator.swift
├── Engines/
│   ├── VideoComposer.swift
│   ├── ThumbnailGenerator.swift
│   └── VideoExporter.swift
├── Utils/
│   ├── CMTime+Extensions.swift
│   ├── PHAsset+Extensions.swift
│   └── UndoManager.swift
├── clipclipApp.swift
└── ContentView.swift
```
