//
//  CompletableTextField.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 29/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

protocol CompletableTextFieldDelegate {

    func getCompletions(for text: String) -> [String]
}

class CompletableTextField: NSTextField {
    var completionDelegate: CompletableTextFieldDelegate?

    fileprivate lazy var completionsWindowController: CompletionsWindowController = {
        let completionsWindowController = CompletionsWindowController(contentRect:
            NSRect(x: 0.0, y: 0.0, width: 200.0, height: 200.0) // TODO: configurable
        )
        completionsWindowController.target = self
        completionsWindowController.action = #selector(CompletableTextField.updateWithSelectedCompletion(_:))
        return completionsWindowController
    }()

    fileprivate var shouldComplete = true

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.isEditable = true
        self.delegate = self
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.isEditable = true
        self.delegate = self
    }

    override func controlTextDidBeginEditing(_ notification: Notification) {
        updateCompletionsFromControl(notification.object)
    }

    override func controlTextDidChange(_ notification: Notification) {
        updateCompletionsFromControl(notification.object)
    }

    override func controlTextDidEndEditing(_ notification: Notification) {
        completionsWindowController.hideCompletions()
    }

    func updateCompletionsFromControl(_ control: Any?) {
        guard let fieldEditor = window?.fieldEditor(false, for: control) else {
            return
        }

        let selection = fieldEditor.selectedRange

        guard let stringValue = fieldEditor.string,
            let text = fieldEditor.string?.substring(to: stringValue.characters.index(stringValue.startIndex,
                                                                                      offsetBy: selection.location)),
            let completions = completionDelegate?.getCompletions(for: text),
            completions.count > 0 else {
            completionsWindowController.hideCompletions()
            return
        }

        if shouldComplete && completions.count == 1 {
            updateFieldEditor(fieldEditor, completion: completions[0])
        } else {
            shouldComplete = true
        }

        completionsWindowController.completions = completions

        if let window = completionsWindowController.window, !window.isVisible {
            completionsWindowController.showCompletions(for: self)
        }
    }

    func updateWithSelectedCompletion(_ sender: Any) {
        guard let completionsWindowController = sender as? CompletionsWindowController,
            let completionsViewController = completionsWindowController.contentViewController as? CompletionsViewController,
            let fieldEditor = window?.fieldEditor(false, for: self),
            let selectedCompletion = completionsViewController.selectedCompletion else {
            return
        }

        updateFieldEditor(fieldEditor, completion: selectedCompletion)
    }

    func updateFieldEditor(_ fieldEditor: NSText, completion: String) {
        let selection = NSMakeRange(fieldEditor.selectedRange.location, completion.characters.count)
        fieldEditor.string = completion
        fieldEditor.selectedRange = selection
    }
}

// MARK: NSTextFieldDelegate

extension CompletableTextField: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {

        case #selector(NSResponder.moveDown(_:)):
            completionsWindowController.moveDown(textView)
            return true

        case #selector(NSResponder.moveUp(_:)):
            completionsWindowController.moveUp(textView)
            return true

        case #selector(NSResponder.deleteForward(_:)),
             #selector(NSResponder.deleteBackward(_:)):
            shouldComplete = false
            return false

        case #selector(NSResponder.insertTab(_:)),
             #selector(NSResponder.complete(_:)):
            if completionsWindowController.isVisible {
                completionsWindowController.hideCompletions()
            } else {
                updateCompletionsFromControl(control)
            }

            return true

        case #selector(NSResponder.insertNewline(_:)),
             #selector(NSResponder.moveRight(_:)):
            if completionsWindowController.isVisible {
                completionsWindowController.hideCompletions()
            }

            if let fieldEditor = window?.fieldEditor(false, for: self),
                let string = fieldEditor.string {
                fieldEditor.selectedRange = NSMakeRange(string.characters.count, 0)
            }

            return false

        case #selector(NSResponder.cancelOperation(_:)):
            if completionsWindowController.isVisible {
                completionsWindowController.hideCompletions()
                return true
            }

            return false

        default: return false
        }
    }
}
