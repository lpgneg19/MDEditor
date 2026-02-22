//
//  MarkdownHighlighter.swift
//  MDEditor
//
//  TextKit 2 语法高亮器 - 实现 Ulysses 风格的 Markdown 渲染
//

import AppKit

/// Markdown 语法高亮器
/// 使用正则表达式匹配 Markdown 语法并应用样式
public final class MarkdownHighlighter: @unchecked Sendable {

    // MARK: - Properties

    /// 基础字体
    public var baseFont: NSFont = NSFont.systemFont(ofSize: 15)

    /// 语法标记字体（淡化显示）
    public var syntaxFont: NSFont {
        NSFont.systemFont(ofSize: baseFont.pointSize * 0.85, weight: .light)
    }

    /// 是否暗色主题
    public var isDarkTheme: Bool = false

    /// 行高倍数
    public var lineHeightMultiple: CGFloat = 1.5

    /// 图片提供者
    public var imageProvider: (@Sendable (String) -> NSImage?)?

    // MARK: - Colors

    private var textColor: NSColor {
        isDarkTheme ? NSColor(white: 0.88, alpha: 1.0) : NSColor(white: 0.15, alpha: 1.0)
    }

    private var headingColor: NSColor {
        isDarkTheme ? .white : .black
    }

    private var syntaxColor: NSColor {
        NSColor(white: 0.5, alpha: 0.6)
    }

    private var linkColor: NSColor { .systemBlue }

    private var codeColor: NSColor {
        isDarkTheme
            ? NSColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0)
            : NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
    }

    private var codeBackground: NSColor {
        isDarkTheme ? NSColor(white: 0.15, alpha: 1.0) : NSColor(white: 0.95, alpha: 1.0)
    }

    // MARK: - Regex Patterns

    private lazy var patterns: [(regex: NSRegularExpression, style: HighlightStyle)] = {
        var p: [(NSRegularExpression, HighlightStyle)] = []

        if let r = try? NSRegularExpression(pattern: #"(?m)^ *(#{1,6}) *(.*)$"#) {
            p.append((r, .heading))
        }

        if let r = try? NSRegularExpression(pattern: #"\*\*(.*?)\*\*"#) {
            p.append((r, .bold))
        }

        if let r = try? NSRegularExpression(pattern: #"(?<!\*)\*(?!\*)(.*?)(?<!\*)\*(?!\*)"#) {
            p.append((r, .italic))
        }

        if let r = try? NSRegularExpression(pattern: #"`([^`]*)`"#) {
            p.append((r, .inlineCode))
        }

        if let r = try? NSRegularExpression(pattern: #"(?<!!)\[([^\]]*)\]\(([^)]*)\)"#) {
            p.append((r, .link))
        }

        if let r = try? NSRegularExpression(pattern: #"~~(.*?)~~"#) {
            p.append((r, .strikethrough))
        }

        // 引用块 > text
        if let r = try? NSRegularExpression(pattern: #"^>\s(.*)$"#, options: .anchorsMatchLines) {
            p.append((r, .blockquote))
        }

        // 列表标记 - 或 1.
        if let r = try? NSRegularExpression(
            pattern: #"^(\s*)([-*+]|\d+\.)\s"#, options: .anchorsMatchLines)
        {
            p.append((r, .listMarker))
        }

        // 图片 ![]()
        if let r = try? NSRegularExpression(pattern: #"!\[([^\]]*)\]\(([^)]+)\)"#) {
            p.append((r, .image))
        }

        return p
    }()

    private enum HighlightStyle {
        case heading, bold, italic, inlineCode, link, strikethrough, blockquote, listMarker, image
    }

    // MARK: - Initializer

    public init() {}

    // MARK: - Public Methods

    /// 为给定文本应用 Markdown 高亮
    public func highlight(_ textStorage: NSTextStorage, in range: NSRange) {
        let textSnapshot = textStorage.string as NSString
        let fullRange = NSRange(location: 0, length: textSnapshot.length)
        let targetRange = NSIntersectionRange(range, fullRange)

        guard targetRange.length > 0 else { return }

        // 扩展到完整行范围，确保标题、列表等行首语法能被正确捕获
        let lineRange = textSnapshot.lineRange(for: targetRange)

        // 渲染锁：图片替换会改变长度，必须从后往前执行以保持索引有效
        var imageReplacements: [(NSRange, NSAttributedString)] = []

        textStorage.beginEditing()

        // 1. 【终极加固】重置视图基础样式，同时绝对保护图片附件
        let baseStyle = createBaseParagraphStyle()

        // 采用双重备份机制：
        // a. 记录所有附件及其完整属性（包含 MarkdownSource）
        var attachments: [(range: NSRange, attrs: [NSAttributedString.Key: Any])] = []
        textStorage.enumerateAttribute(.attachment, in: lineRange, options: []) { val, range, _ in
            if val != nil {
                attachments.append(
                    (range, textStorage.attributes(at: range.location, effectiveRange: nil)))
            }
        }

        // b. 执行全量重置
        textStorage.setAttributes(
            [
                .font: baseFont,
                .foregroundColor: textColor,
                .paragraphStyle: baseStyle,
            ], range: lineRange)

        // c. 精准还原附件
        for (range, attrs) in attachments {
            textStorage.addAttributes(attrs, range: range)
        }

        // 使用 NSString 的 bridge 以最高效率运行正则（避免 Swift String 重复转换的性能损耗）
        let searchString = textSnapshot as String

        // 2. 第一阶段：扫描所有非破坏性样式（颜色、加粗等）并记录需要破坏性替换的图片
        for (regex, style) in patterns {
            regex.enumerateMatches(in: searchString, options: [], range: lineRange) { match, _, _ in
                guard let match = match else { return }

                if style == .image {
                    // 图片会导致文本长度变化，记录之以便后续逆序处理
                    if let attrString = self.createImageAttachmentString(
                        for: match, in: textSnapshot)
                    {
                        imageReplacements.append((match.range, attrString))
                    }
                } else {
                    // 常规样式即时应用
                    self.applyStyle(style, to: textStorage, match: match, text: textSnapshot)
                }
            }
        }

        // 3. 第二阶段：从后往前替换图片附件
        // 重要：逆序替换是解决“点击文档卡死”的核心技术。
        if !imageReplacements.isEmpty {
            for (replaceRange, attrString) in imageReplacements.reversed() {
                // 【性能拦截】检查指纹：如果目标字符已经是相同的附件且源码一致，则跳过替换。
                // 这彻底杜绝了打字时因重复插入附件导致的布局重算和界面跳动。
                var isAlreadyRendered = false
                if replaceRange.length == 1 {
                    let currentAttrs = textStorage.attributes(
                        at: replaceRange.location, effectiveRange: nil)
                    if let currentSource = currentAttrs[NSAttributedString.Key("MarkdownSource")]
                        as? String,
                        let newSource = attrString.attribute(
                            NSAttributedString.Key("MarkdownSource"), at: 0, effectiveRange: nil)
                            as? String,
                        currentSource == newSource
                    {
                        isAlreadyRendered = true
                    }
                }

                if !isAlreadyRendered {
                    textStorage.replaceCharacters(in: replaceRange, with: attrString)
                }
            }
        }

        textStorage.endEditing()
    }

    // MARK: - Public Helper Methods

    public func createBaseParagraphStyle() -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineHeightMultiple
        style.paragraphSpacing = 8
        return style
    }

    private func applyStyle(
        _ style: HighlightStyle, to storage: NSTextStorage, match: NSTextCheckingResult,
        text: NSString
    ) {
        switch style {
        case .heading:
            applyHeadingStyle(to: storage, match: match, text: text)
        case .bold:
            applyBoldStyle(to: storage, match: match)
        case .italic:
            applyItalicStyle(to: storage, match: match)
        case .inlineCode:
            applyInlineCodeStyle(to: storage, match: match)
        case .link:
            applyLinkStyle(to: storage, match: match)
        case .strikethrough:
            applyStrikethroughStyle(to: storage, match: match)
        case .blockquote:
            applyBlockquoteStyle(to: storage, match: match)
        case .listMarker:
            applyListMarkerStyle(to: storage, match: match)
        case .image:
            // 图片在 highlight 方法的第一阶段已通过 imageReplacements 接管
            break
        }
    }

    private func applyHeadingStyle(
        to storage: NSTextStorage, match: NSTextCheckingResult, text: NSString
    ) {
        let hashRange = match.range(at: 1)
        let level = hashRange.length

        // 标题字体 - 基于用户选择的字体派生
        let multipliers: [CGFloat] = [2.0, 1.7, 1.5, 1.3, 1.2, 1.1]
        let fontSize = baseFont.pointSize * multipliers[min(level - 1, 5)]

        // 尝试使用用户字体的粗体变体，如果没有则使用系统粗体
        let scaledFont =
            NSFont(descriptor: baseFont.fontDescriptor, size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)

        let headingFont: NSFont
        let boldDescriptor = scaledFont.fontDescriptor.withSymbolicTraits(.bold)
        headingFont =
            NSFont(descriptor: boldDescriptor, size: fontSize)
            ?? NSFont.boldSystemFont(ofSize: fontSize)

        // 1. 全量应用标题字体到整行（确保光标继承）
        let lineRange = text.lineRange(for: match.range)
        storage.addAttributes(
            [
                .font: headingFont,
                .foregroundColor: headingColor,
            ], range: lineRange)

        // 2. 仅对符号部分进行染色淡化
        storage.addAttribute(.foregroundColor, value: syntaxColor, range: hashRange)
        storage.addAttribute(.font, value: syntaxFont, range: hashRange)
    }

    private func applyBoldStyle(to storage: NSTextStorage, match: NSTextCheckingResult) {
        let fullRange = match.range

        // 1. 全量应用粗体字体
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        storage.addAttribute(.font, value: boldFont, range: fullRange)

        // 2. 仅对符号进行染色淡化
        let startMarker = NSRange(location: fullRange.location, length: 2)
        let endMarker = NSRange(location: fullRange.location + fullRange.length - 2, length: 2)
        storage.addAttributes([.foregroundColor: syntaxColor], range: startMarker)
        storage.addAttributes([.foregroundColor: syntaxColor], range: endMarker)
    }

    private func applyItalicStyle(to storage: NSTextStorage, match: NSTextCheckingResult) {
        let fullRange = match.range
        let contentRange = match.range(at: 1)

        // 内容斜体
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        storage.addAttribute(.font, value: italicFont, range: contentRange)

        // 语法标记淡化
        let startMarker = NSRange(location: fullRange.location, length: 1)
        let endMarker = NSRange(location: fullRange.location + fullRange.length - 1, length: 1)
        storage.addAttributes(
            [.font: syntaxFont, .foregroundColor: syntaxColor], range: startMarker)
        storage.addAttributes([.font: syntaxFont, .foregroundColor: syntaxColor], range: endMarker)
    }

    private func applyInlineCodeStyle(to storage: NSTextStorage, match: NSTextCheckingResult) {
        let fullRange = match.range
        let contentRange = match.range(at: 1)

        // 代码样式
        let monoFont = NSFont.monospacedSystemFont(
            ofSize: baseFont.pointSize * 0.9, weight: .regular)
        storage.addAttributes(
            [
                .font: monoFont,
                .foregroundColor: codeColor,
                .backgroundColor: codeBackground,
            ], range: contentRange)

        // 反引号淡化
        let startMarker = NSRange(location: fullRange.location, length: 1)
        let endMarker = NSRange(location: fullRange.location + fullRange.length - 1, length: 1)
        storage.addAttributes(
            [.font: syntaxFont, .foregroundColor: syntaxColor], range: startMarker)
        storage.addAttributes([.font: syntaxFont, .foregroundColor: syntaxColor], range: endMarker)
    }

    private func applyLinkStyle(to storage: NSTextStorage, match: NSTextCheckingResult) {
        let textRange = match.range(at: 1)
        let urlRange = match.range(at: 2)

        // 链接文本
        storage.addAttributes(
            [
                .foregroundColor: linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ], range: textRange)

        // URL 和括号淡化
        let bracketStart = NSRange(location: match.range.location, length: 1)
        let bracketEnd = NSRange(location: textRange.location + textRange.length, length: 2)
        let closeParen = NSRange(location: urlRange.location + urlRange.length, length: 1)

        storage.addAttributes(
            [.font: syntaxFont, .foregroundColor: syntaxColor], range: bracketStart)
        storage.addAttributes(
            [.font: syntaxFont, .foregroundColor: syntaxColor], range: bracketEnd)
        storage.addAttributes([.font: syntaxFont, .foregroundColor: syntaxColor], range: urlRange)
        storage.addAttributes(
            [.font: syntaxFont, .foregroundColor: syntaxColor], range: closeParen)
    }

    private func applyStrikethroughStyle(to storage: NSTextStorage, match: NSTextCheckingResult) {
        let fullRange = match.range
        let contentRange = match.range(at: 1)

        // 删除线
        storage.addAttribute(
            .strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)

        // 语法标记淡化
        let startMarker = NSRange(location: fullRange.location, length: 2)
        let endMarker = NSRange(location: fullRange.location + fullRange.length - 2, length: 2)
        storage.addAttributes(
            [.font: syntaxFont, .foregroundColor: syntaxColor], range: startMarker)
        storage.addAttributes([.font: syntaxFont, .foregroundColor: syntaxColor], range: endMarker)
    }

    private func applyBlockquoteStyle(to storage: NSTextStorage, match: NSTextCheckingResult) {
        let fullRange = match.range

        // 引用样式
        let quoteColor =
            isDarkTheme ? NSColor(white: 0.6, alpha: 1.0) : NSColor(white: 0.4, alpha: 1.0)
        storage.addAttribute(.foregroundColor, value: quoteColor, range: fullRange)

        // > 标记淡化
        let markerRange = NSRange(location: fullRange.location, length: 2)
        storage.addAttributes(
            [.font: syntaxFont, .foregroundColor: syntaxColor], range: markerRange)
    }

    private func applyListMarkerStyle(to storage: NSTextStorage, match: NSTextCheckingResult) {
        let markerRange = match.range(at: 2)
        storage.addAttributes([.foregroundColor: syntaxColor], range: markerRange)
    }

    private func createImageAttachmentString(for match: NSTextCheckingResult, in text: NSString)
        -> NSAttributedString?
    {
        let matchRange = match.range
        let linkRange = match.range(at: 2)
        let path = text.substring(with: linkRange)
        let originalMarkdown = text.substring(with: matchRange)

        // 尝试通过宿主提供的 imageProvider 加载
        if let image = imageProvider?(path) {
            let attachment = NSTextAttachment()
            attachment.image = image

            // 智能缩放保持 Ulysses 均衡感
            let maxWidth: CGFloat = 800
            let size = image.size
            if size.width > maxWidth {
                let scale = maxWidth / size.width
                attachment.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: size.height * scale)
            } else {
                attachment.bounds = CGRect(origin: .zero, size: size)
            }

            // 【核心修复】创建带源码备份的附件字符
            let attrString = NSMutableAttributedString(attachment: attachment)
            // 该属性由 MDEditorView.Coordinator.reconstructMarkdown 读取，确保同步时数据完整
            attrString.addAttribute(
                NSAttributedString.Key("MarkdownSource"), value: originalMarkdown,
                range: NSRange(location: 0, length: 1))

            return attrString
        }
        return nil
    }

    private func applyImageStyle(
        to storage: NSTextStorage, match: NSRegularExpression, range: NSRange, text: NSString
    ) {
        // 此方法已由 highlight 中的记录替换逻辑接管，保留仅作兼容性占位
        storage.addAttributes(
            [.font: syntaxFont, .foregroundColor: syntaxColor], range: range)
    }
}
