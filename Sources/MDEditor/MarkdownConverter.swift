//
//  MarkdownConverter.swift
//  MDEditor
//
//  Markdown 辅助工具类
//

import Foundation
import Markdown

/// Markdown 解析和转换工具
/// 注意：Ulysses 风格编辑器直接使用 MarkdownHighlighter 处理样式，
/// 此类仅提供辅助功能（如导出 HTML）
public struct MarkdownConverter {

    // MARK: - Markdown → HTML

    /// 将 Markdown 文本转换为 HTML（用于导出或预览）
    /// - Parameter markdown: Markdown 源文本
    /// - Returns: HTML 字符串
    public static func toHTML(_ markdown: String) -> String {
        let document = Document(parsing: markdown)
        var htmlVisitor = HTMLVisitor()
        return htmlVisitor.visit(document)
    }

    // MARK: - Validate

    /// 验证 Markdown 语法
    /// - Parameter markdown: Markdown 文本
    /// - Returns: 是否有效
    public static func isValid(_ markdown: String) -> Bool {
        // swift-markdown 库总是能解析，这里只是占位
        return true
    }
}

// MARK: - HTML Visitor

private struct HTMLVisitor: MarkupVisitor {
    typealias Result = String

    mutating func defaultVisit(_ markup: any Markup) -> String {
        var result = ""
        for child in markup.children {
            result += visit(child)
        }
        return result
    }

    mutating func visitDocument(_ document: Document) -> String {
        defaultVisit(document)
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        "<p>\(defaultVisit(paragraph))</p>\n"
    }

    mutating func visitText(_ text: Text) -> String {
        text.string
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        "<strong>\(defaultVisit(strong))</strong>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        "<em>\(defaultVisit(emphasis))</em>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(inlineCode.code)</code>"
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = heading.level
        return "<h\(level)>\(defaultVisit(heading))</h\(level)>\n"
    }

    mutating func visitLink(_ link: Link) -> String {
        let href = link.destination ?? ""
        return "<a href=\"\(href)\">\(defaultVisit(link))</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let src = image.source ?? ""
        let alt = image.title ?? ""
        return "<img src=\"\(src)\" alt=\"\(alt)\" />"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        "<ul>\n\(defaultVisit(unorderedList))</ul>\n"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        "<ol>\n\(defaultVisit(orderedList))</ol>\n"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        "<li>\(defaultVisit(listItem))</li>\n"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        "<blockquote>\(defaultVisit(blockQuote))</blockquote>\n"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let lang = codeBlock.language ?? ""
        return "<pre><code class=\"language-\(lang)\">\(codeBlock.code)</code></pre>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr />\n"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br />\n"
    }
}
