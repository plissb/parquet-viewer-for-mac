import AppKit
import SwiftUI

struct HighlightedSQLEditor: NSViewRepresentable {
    @Binding var text: String
    var fieldNames: [String]
    var selectedField: String?
    var isSingleLine: Bool = false
    var onSelectField: (String) -> Void
    var onSubmit: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SQLEditorScrollView {
        let scroll = SQLEditorScrollView()
        scroll.hasVerticalScroller = !isSingleLine
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.verticalScrollElasticity = .none
        scroll.horizontalScrollElasticity = .none
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.backgroundColor = .clear
        scroll.contentView.drawsBackground = false

        let view = SQLEditorTextView()
        view.delegate = context.coordinator
        view.isRichText = true
        view.isEditable = true
        view.isSelectable = true
        view.importsGraphics = false
        view.allowsUndo = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.smartInsertDeleteEnabled = false
        view.enabledTextCheckingTypes = 0
        view.usesFindBar = !isSingleLine
        view.usesFontPanel = false
        view.typingAttributes = SQLHighlighter.baseAttributes()
        view.insertionPointColor = Palette.nsBrass
        view.backgroundColor = .clear
        view.drawsBackground = false
        view.textContainerInset = NSSize(width: 4, height: isSingleLine ? 0 : 6)
        view.onSubmit = { context.coordinator.onSubmit?() }
        configure(view, isSingleLine: isSingleLine)

        scroll.documentView = view
        context.coordinator.parent = self
        applyHighlight(in: view, coordinator: context.coordinator)
        return scroll
    }

    func updateNSView(_ scroll: SQLEditorScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.onSubmit = onSubmit
        guard let view = scroll.documentView as? SQLEditorTextView else { return }
        view.onSubmit = { context.coordinator.onSubmit?() }
        configure(view, isSingleLine: isSingleLine)
        guard !context.coordinator.applying else { return }
        let fieldsChanged = context.coordinator.fieldNames != fieldNames
            || context.coordinator.selectedField != selectedField
        if view.string != text || fieldsChanged {
            applyHighlight(in: view, coordinator: context.coordinator)
        }
    }

    private func configure(_ view: SQLEditorTextView, isSingleLine: Bool) {
        view.isSingleLine = isSingleLine
        view.minSize = .zero
        view.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        if isSingleLine {
            view.isHorizontallyResizable = false
            view.isVerticallyResizable = false
            view.autoresizingMask = [.width, .height]
            view.textContainer?.widthTracksTextView = true
            view.textContainer?.heightTracksTextView = false
            view.textContainer?.maximumNumberOfLines = 1
            view.textContainer?.lineBreakMode = .byClipping
            view.textContainer?.lineFragmentPadding = 2
            view.textContainerInset = NSSize(width: 4, height: 0)
        } else {
            view.isHorizontallyResizable = false
            view.isVerticallyResizable = true
            view.autoresizingMask = [.width]
            view.textContainer?.widthTracksTextView = true
            view.textContainer?.heightTracksTextView = false
            view.textContainer?.containerSize = NSSize(
                width: 0,
                height: CGFloat.greatestFiniteMagnitude
            )
            view.textContainer?.maximumNumberOfLines = 0
            view.textContainer?.lineBreakMode = .byWordWrapping
        }
    }

    private func applyHighlight(in view: SQLEditorTextView, coordinator: Coordinator) {
        coordinator.applying = true
        let selected = view.selectedRange()
        if view.string != text {
            view.string = text
        }
        if let storage = view.textStorage {
            SQLHighlighter.style(
                storage,
                fields: fieldNames,
                selectedField: selectedField
            )
        }
        view.typingAttributes = SQLHighlighter.baseAttributes()
        view.insertionPointColor = Palette.nsBrass
        let maxLocation = (view.string as NSString).length
        let location = min(selected.location, maxLocation)
        let length = min(selected.length, max(0, maxLocation - location))
        view.setSelectedRange(NSRange(location: location, length: length))
        coordinator.selectedField = selectedField
        coordinator.fieldNames = fieldNames
        coordinator.applying = false
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightedSQLEditor?
        var onSubmit: (() -> Void)?
        var applying = false
        var selectedField: String?
        var fieldNames: [String] = []

        func textDidChange(_ notification: Notification) {
            guard !applying, let view = notification.object as? NSTextView else { return }
            parent?.text = view.string
            rehighlight(view)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !applying, let view = notification.object as? NSTextView, let parent else { return }
            if let name = SQLHighlighter.fieldName(
                in: view.string,
                utf16Range: view.selectedRange(),
                fields: parent.fieldNames
            ) {
                parent.onSelectField(name)
            }
        }

        func rehighlight(_ view: NSTextView) {
            guard let parent, let storage = view.textStorage else { return }
            applying = true
            let selected = view.selectedRange()
            SQLHighlighter.style(
                storage,
                fields: parent.fieldNames,
                selectedField: parent.selectedField
            )
            view.typingAttributes = SQLHighlighter.baseAttributes()
            let maxLocation = (view.string as NSString).length
            let location = min(selected.location, maxLocation)
            let length = min(selected.length, max(0, maxLocation - location))
            view.setSelectedRange(NSRange(location: location, length: length))
            applying = false
        }
    }
}

final class SQLEditorScrollView: NSScrollView {
    override func layout() {
        super.layout()
        guard let view = documentView as? SQLEditorTextView else { return }
        var frame = contentView.bounds
        if view.isSingleLine {
            frame.size.width = max(frame.width, 1)
            frame.size.height = max(frame.height, 1)
            if view.frame != frame {
                view.frame = frame
            }
            view.recenterSingleLine()
        } else if abs(view.frame.width - contentView.bounds.width) > 0.5 {
            var next = view.frame
            next.size.width = contentView.bounds.width
            view.frame = next
        }
    }

    override func mouseDown(with event: NSEvent) {
        if let textView = documentView as? NSTextView {
            window?.makeFirstResponder(textView)
        }
        super.mouseDown(with: event)
    }
}

final class SQLEditorTextView: NSTextView {
    var isSingleLine = false
    var onSubmit: (() -> Void)?

    init() {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: 100, height: 22))
        container.widthTracksTextView = true
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        super.init(frame: NSRect(x: 0, y: 0, width: 100, height: 22), textContainer: container)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var textContainerOrigin: NSPoint {
        guard isSingleLine else { return super.textContainerOrigin }
        return NSPoint(x: textContainerInset.width, y: singleLineTopInset)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        recenterSingleLine()
    }

    override func didChangeText() {
        super.didChangeText()
        recenterSingleLine()
    }

    func recenterSingleLine() {
        guard isSingleLine, let textContainer else { return }
        textContainer.containerSize = NSSize(
            width: max(bounds.width - textContainerInset.width * 2, 1),
            height: max(bounds.height, 18)
        )
        invalidateTextContainerOrigin()
        needsDisplay = true
    }

    private var singleLineTopInset: CGFloat {
        guard let layoutManager, let textContainer else { return 0 }
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer).height
        return max(0, ((bounds.height - used) / 2).rounded(.toNearestOrAwayFromZero))
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command),
              !modifiers.contains(.option),
              !modifiers.contains(.shift),
              !modifiers.contains(.control) else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "v":
            paste(nil)
            return true
        case "c":
            copy(nil)
            return true
        case "a":
            selectAll(nil)
            return true
        case "x":
            cut(nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }

    override var textColor: NSColor? {
        get { typingAttributes[.foregroundColor] as? NSColor ?? Palette.nsInk }
        set {}
    }

    override var font: NSFont? {
        get { typingAttributes[.font] as? NSFont ?? .monospacedSystemFont(ofSize: 12, weight: .regular) }
        set {}
    }

    override func setTextColor(_ color: NSColor?, range: NSRange) {}

    override func insertNewline(_ sender: Any?) {
        if isSingleLine {
            onSubmit?()
            return
        }
        super.insertNewline(sender)
    }

    override func paste(_ sender: Any?) {
        let raw = NSPasteboard.general.string(forType: .string) ?? ""
        let insertion = isSingleLine
            ? raw.replacingOccurrences(of: #"[\r\n]+"#, with: " ", options: .regularExpression)
            : raw
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: insertion) else { return }
        replaceCharacters(in: range, with: insertion)
        didChangeText()
    }
}
