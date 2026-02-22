# MDEditor

MDEditor 是一个基于 TextKit 2 开发的 macOS/iOS Markdown 编辑器组件，旨在提供类似 Ulysses 的“所见即所得”编辑体验。

## 特色

- **TextKit 2 架构**：利用苹果最新的文本处理引擎，性能强劲且高度可定制。
- **实时高亮**：支持完整的 Markdown 语法高亮，包括粗体、斜体、代码块、链接等。
- **图片预览**：支持在编辑器内直接渲染本地和远程图片。
- **打字机模式**：支持光标始终保持在屏幕中央的录入体验。
- **模块化设计**：可以轻松集成到任何基于 SwiftUI 或 AppKit 的 Swift 项目中。

## 安装

### Swift Package Manager

在你的项目中添加依赖：

```swift
.package(url: "https://github.com/lpgneg19/MDEditor.git", branch: "main")
```

## 许可证

本项目采用 [Mozilla Public License 2.0 (MPL-2.0)](LICENSE) 许可证。
