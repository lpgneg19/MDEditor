//
//  MDEditorMarkdownPreview.swift
//  MDEditor
//

import SwiftUI
import MarkdownView

/// Read-only Markdown renderer backed by SteveShi/MarkdownView.
///
/// MDEditorView keeps owning the TextKit editing path used by MDWriter's
/// WYSIWYG editor. This view is intentionally separate so host apps can opt in
/// to the richer renderer for preview surfaces without changing edit behavior.
@MainActor
public struct MDEditorMarkdownPreview: View {
    private let markdown: String
    private let theme: MarkdownTheme
    private let contentWidth: CGFloat?

    public init(
        _ markdown: String,
        theme: MarkdownTheme,
        contentWidth: CGFloat? = nil
    ) {
        self.markdown = markdown
        self.theme = theme
        self.contentWidth = contentWidth
    }

    public var body: some View {
        MarkdownView(markdown, theme: theme)
            .frame(maxWidth: contentWidth ?? .infinity, alignment: .topLeading)
    }
}

public extension MDEditorMarkdownPreview {
    init(
        text: String,
        configuration: EditorConfiguration,
        theme: MarkdownTheme
    ) {
        var resolvedTheme = theme
        resolvedTheme.align(to: configuration.fontSize)
        self.init(text, theme: resolvedTheme, contentWidth: configuration.contentWidth)
    }
}
