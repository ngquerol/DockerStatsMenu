//
//  CompletionsWindowController.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 30/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

class CompletionsWindowController: NSWindowController {
    var target: Any?

    var action: Selector? {
        didSet {
            completionsViewController.completionsTableView.action = action
        }
    }

    var isVisible: Bool {
        return window?.isVisible == true
    }

    var completions: [String] = [] {
        didSet {
            completionsViewController.completions = completions
        }
    }

    private var completionsViewController: CompletionsViewController

    private var parentTextField: NSTextField?

    init(contentRect: NSRect) {
        let window = CompletionsWindow(contentRect: contentRect,
                                       styleMask: NSBorderlessWindowMask,
                                       backing: .buffered,
                                       defer: true)
        completionsViewController = CompletionsViewController(nibName: "CompletionsViewController", bundle: nil)!

        super.init(window: window)

        window.contentViewController = completionsViewController
        window.contentView = completionsViewController.view
    }

    required init?(coder: NSCoder) {
        completionsViewController = CompletionsViewController(nibName: "CompletionsViewController", bundle: nil)!

        super.init(coder: coder)
    }

    override func moveUp(_ sender: Any?) {
        guard let selectedCompletion = completionsViewController.selectedCompletion else {
            return changeCompletionSelectionIndex(with: completions.count - 1)
        }

        guard let selectedRow = completions.index(of: selectedCompletion) else {
            return
        }

        let newSelectedRow = (selectedRow - 1) < 0 ? completions.count - 1 : selectedRow - 1

        changeCompletionSelectionIndex(with: newSelectedRow)
    }

    override func moveDown(_ sender: Any?) {
        guard let selectedCompletion = completionsViewController.selectedCompletion else {
            return changeCompletionSelectionIndex(with: 0)
        }

        guard let selectedRow = completions.index(of: selectedCompletion) else {
            return
        }

        let newSelectedRow = (selectedRow + 1) > (completions.count - 1) ? 0 : selectedRow + 1

        changeCompletionSelectionIndex(with: newSelectedRow)
    }

    func showCompletions(for textField: NSTextField) {
        guard let completionsWindow = window,
            let textFieldWindow = textField.window else {
            return
        }

        var frame = completionsWindow.frame

        frame.size.width = textField.frame.width

        let textFieldInWindowCoords = textField.convert(textField.bounds, to: nil)
        var textFieldInScreen = textFieldWindow.convertToScreen(textFieldInWindowCoords)

        textFieldInScreen.origin.y -= 3.0
        completionsWindow.setFrame(frame, display: false)
        completionsWindow.setFrameTopLeftPoint(textFieldInScreen.origin)
        textFieldWindow.addChildWindow(completionsWindow, ordered: .above)

        parentTextField = textField
    }

    func hideCompletions() {
        guard let completionsWindow = window else { return }

        if completionsWindow.isVisible {
            completionsWindow.parent?.removeChildWindow(completionsWindow)
            completionsWindow.orderOut(nil)
        }
    }

    private func changeCompletionSelectionIndex(with row: Int) {
        completionsViewController.completionsTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        completionsViewController.completionsTableView.scrollRowToVisible(row)

        if let action = action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }
}
