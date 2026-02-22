//
//  MDEditorProxy.swift
//  MDEditor
//
//  用于外部与 MDEditorView 进行交互的代理对象
//

import Combine
import Foundation

/// MDEditor 的交互代理
/// 通过此对象可以向编辑器发送指令，如插入文本、查找替换等
public class MDEditorProxy: ObservableObject {

    // MARK: - Actions (Internal use)

    internal var insertTextAction: ((String) -> Void)?
    internal var wrapSelectionAction: ((String, String) -> Void)?
    internal var getSelectedTextAction: (() -> String?)?
    internal var findNextAction: ((String) -> Void)?
    internal var findPreviousAction: ((String) -> Void)?
    internal var replaceAction: ((String, String) -> Void)?
    internal var replaceAllAction: ((String, String) -> Void)?
    internal var printAction: (() -> Void)?
    internal var setHighlighterDarkThemeAction: ((Bool) -> Void)?

    // MARK: - Initializer

    public init() {}

    // MARK: - Public Methods

    public func insert(_ text: String) {
        insertTextAction?(text)
    }

    public func wrapSelection(prefix: String, suffix: String) {
        wrapSelectionAction?(prefix, suffix)
    }

    public func getSelectedText() -> String? {
        getSelectedTextAction?()
    }

    public func findNext(text: String) {
        findNextAction?(text)
    }

    public func findPrevious(text: String) {
        findPreviousAction?(text)
    }

    public func replace(search: String, with replacement: String) {
        replaceAction?(search, replacement)
    }

    public func replaceAll(search: String, with replacement: String) {
        replaceAllAction?(search, replacement)
    }

    public func print() {
        printAction?()
    }

    public func setTheme(isDark: Bool) {
        setHighlighterDarkThemeAction?(isDark)
    }
}
