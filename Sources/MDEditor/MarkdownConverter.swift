//
//  MarkdownConverter.swift
//  MDEditor
//
//  Markdown 辅助工具类
//

import Foundation
import Markdown

public struct MarkdownDocumentHeader: Sendable, Hashable {
    public let level: Int
    public let title: String
    public let lineIndex: Int

    public init(level: Int, title: String, lineIndex: Int) {
        self.level = level
        self.title = title
        self.lineIndex = lineIndex
    }
}

public struct MarkdownDocumentStatistics: Sendable, Hashable {
    public let characters: Int
    public let words: Int
    public let readingTime: Int

    public init(characters: Int, words: Int, readingTime: Int) {
        self.characters = characters
        self.words = words
        self.readingTime = readingTime
    }
}

/// Markdown 解析和转换工具
/// 注意：Ulysses 风格编辑器直接使用 MarkdownHighlighter 处理样式，
/// 此类仅提供辅助功能（如导出 HTML）
public struct MarkdownConverter {

    // MARK: - Markdown → HTML

    /// 将 Markdown 文本转换为 HTML（用于导出或预览）
    /// - Parameter markdown: Markdown 源文本
    /// - Returns: HTML 字符串
    public static func toHTML(_ markdown: String, imageResolver: (@Sendable (String) -> String)? = nil)
        -> String
    {
        let document = Document(parsing: markdown)
        var htmlVisitor = HTMLVisitor(imageResolver: imageResolver)
        return htmlVisitor.visit(document)
    }

    public static func headers(from markdown: String) -> [MarkdownDocumentHeader] {
        let document = Document(parsing: markdown)
        var visitor = HeaderVisitor()
        visitor.visit(document)
        return visitor.headers
    }

    public static func statistics(from markdown: String, readingWordsPerMinute: Int = 300)
        -> MarkdownDocumentStatistics
    {
        let document = Document(parsing: markdown)
        let plainText = plainText(from: document)
        let wordCount = plainText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        let wordsPerMinute = max(1, readingWordsPerMinute)
        let readingTime = max(1, Int(ceil(Double(wordCount) / Double(wordsPerMinute))))
        return MarkdownDocumentStatistics(
            characters: markdown.count,
            words: wordCount,
            readingTime: readingTime
        )
    }

    public static func plainText(from markdown: String) -> String {
        let document = Document(parsing: markdown)
        return plainText(from: document)
    }

    fileprivate static func plainText(from markup: any Markup) -> String {
        var visitor = PlainTextVisitor()
        visitor.visit(markup)
        return visitor.text
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
    let imageResolver: (@Sendable (String) -> String)?

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
        text.string.htmlEscaped()
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
        let href = (link.destination ?? "").htmlAttributeEscaped()
        return "<a href=\"\(href)\">\(defaultVisit(link))</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let source = image.source ?? ""
        let resolvedSource = imageResolver?(source) ?? source
        let title = image.title ?? ""
        let alt = MarkdownConverter.plainText(from: image)
        return """
            <img src="\(resolvedSource.htmlAttributeEscaped())" title="\(title.htmlAttributeEscaped())" alt="\(alt.htmlAttributeEscaped())" />
            """
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
        let langClass = codeBlock.language.map { " class=\"language-\($0.htmlAttributeEscaped())\"" } ?? ""
        return "<pre><code\(langClass)>\(codeBlock.code.htmlEscaped())</code></pre>\n"
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

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        inlineHTML.rawHTML
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) -> String {
        htmlBlock.rawHTML
    }

    mutating func visitTable(_ table: Table) -> String {
        "<table>\(defaultVisit(table))</table>"
    }

    mutating func visitTableHead(_ tableHead: Table.Head) -> String {
        "<thead>\(defaultVisit(tableHead))</thead>"
    }

    mutating func visitTableBody(_ tableBody: Table.Body) -> String {
        "<tbody>\(defaultVisit(tableBody))</tbody>"
    }

    mutating func visitTableRow(_ tableRow: Table.Row) -> String {
        "<tr>\(defaultVisit(tableRow))</tr>"
    }

    mutating func visitTableCell(_ tableCell: Table.Cell) -> String {
        let tag = tableCell.parent is Table.Head ? "th" : "td"
        return "<\(tag)>\(defaultVisit(tableCell))</\(tag)>"
    }
}

private struct HeaderVisitor: MarkupVisitor {
    typealias Result = Void
    var headers: [MarkdownDocumentHeader] = []

    mutating func defaultVisit(_ markup: any Markup) {
        for child in markup.children {
            visit(child)
        }
    }

    mutating func visitHeading(_ heading: Heading) {
        let lineIndex = heading.range?.lowerBound.line ?? 0
        headers.append(
            MarkdownDocumentHeader(
                level: heading.level,
                title: MarkdownConverter.plainText(from: heading),
                lineIndex: max(0, lineIndex - 1)
            )
        )
    }
}

private extension String {
    func htmlEscaped() -> String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    func htmlAttributeEscaped() -> String {
        htmlEscaped()
    }
}

private struct PlainTextVisitor: MarkupVisitor {
    typealias Result = Void
    var text = ""

    mutating func defaultVisit(_ markup: any Markup) {
        for child in markup.children {
            visit(child)
        }
    }

    mutating func visitText(_ text: Text) {
        self.text += text.string
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        text += " "
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        text += "\n"
    }
}
