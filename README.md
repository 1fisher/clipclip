# ClipClip

一款 **macOS 原生多轨道视频编辑器**，使用 SwiftUI + SwiftData + AVFoundation 构建。

## 功能特性

- 🎬 多轨道时间线（视频轨 + 音频轨）
- ✂️ 视频裁剪、分割、拼接
- 🎥 多机位切换
- 🔊 音频波形可视化
- ↩️ 撤销/重做（快照式，最多 50 步）
- 📤 导出为 MP4
- 🖱️ 拖拽排列素材、跨轨道移动
- ⏩ 变速播放、音量调节

## 系统要求

- macOS 14.0+
- Xcode 16+
- Swift 5.9+

## 构建与运行

```bash
# 克隆仓库
git clone https://github.com/0fisher/clipclip.git
cd clipclip

# 用 Xcode 打开
open clipclip/clipclip.xcodeproj

# 或使用命令行构建
xcodebuild -project clipclip/clipclip.xcodeproj -scheme clipclip build
```

## 项目结构

```
clipclip/
├── clipclip/
│   ├── clipclip/                    # 主应用源码
│   │   ├── clipclipApp.swift        # 应用入口
│   │   ├── ContentView.swift        # 根视图
│   │   ├── Models/                  # 数据模型 (SwiftData)
│   │   │   ├── Project.swift        # 项目模型
│   │   │   ├── Track.swift          # 轨道模型
│   │   │   ├── Clip.swift           # 素材片段模型
│   │   │   └── WaveformCache.swift  # 波形缓存
│   │   ├── ViewModels/              # 视图模型 (@Observable)
│   │   │   ├── EditorViewModel.swift    # 编辑器核心逻辑
│   │   │   ├── ExportViewModel.swift    # 导出逻辑
│   │   │   └── ProjectListViewModel.swift
│   │   ├── Views/
│   │   │   ├── VideoEditor/         # 编辑器视图
│   │   │   │   ├── VideoEditorView.swift
│   │   │   │   ├── TimelineView.swift
│   │   │   │   ├── MaterialImportView.swift
│   │   │   │   ├── PreviewPlayerView.swift
│   │   │   │   └── ...
│   │   │   └── ProjectListView.swift
│   │   ├── Engines/                 # 核心引擎
│   │   │   ├── VideoComposer.swift  # AVComposition 构建
│   │   │   ├── VideoExporter.swift  # 视频导出
│   │   │   └── ThumbnailGenerator.swift
│   │   └── Utils/
│   │       ├── UndoManager.swift    # 撤销/重做
│   │       └── CMTime+Extensions.swift
│   ├── clipclipTests/               # 单元测试
│   └── clipclipUITests/             # UI 测试
├── docs/                            # 设计文档
├── AGENTS.md                        # 开发者参考
└── README.md
```

## 架构概览

### 数据层

使用 SwiftData `@Model` 持久化，关系链为：

```
Project ──(cascade)──▶ Track ──(cascade)──▶ Clip
```

### 导航流程

```
clipclipApp → ContentView → ProjectListView → VideoEditorView
```

### 编辑器布局

三栏 + 底部时间线的响应式布局：

| 区域 | 视图 | 功能 |
|------|------|------|
| 左侧 | `MaterialImportView` | 素材导入与列表 |
| 中央 | `PreviewPlayerView` | 视频预览 |
| 右侧 | `CameraControlView` | 机位控制 |
| 底部 | `TimelineView` | 多轨道时间线 |

## 技术栈

| 技术 | 用途 |
|------|------|
| SwiftUI | UI 框架 |
| SwiftData | 数据持久化 |
| AVFoundation | 视频播放、合成、导出 |
| @Observable | 响应式状态管理 |

## License

Private — All rights reserved.
