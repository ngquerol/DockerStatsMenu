//
//  CompletionsViewController.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 30/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

// FIXME: Decouple completion type (String, etc.) from presentation (NSTableCellView)

class CompletionsViewController: NSViewController {
    @IBOutlet weak var completionsTableView: NSTableView!

    var completions = [String]() {
        didSet {
            completionsTableView.reloadData()
        }
    }

    var selectedCompletion: String? {
        guard 0 ..< completions.count ~= completionsTableView.selectedRow else {
            return nil
        }

        return completions[completionsTableView.selectedRow]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.cornerRadius = 5.0
        view.layer?.backgroundColor = NSColor.white.cgColor
    }
}

// MARK: - NSTableViewDataSource

extension CompletionsViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return completions.count
    }
}

// MARK: - NSTableViewDelegate
extension CompletionsViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return NSFont.systemFontSize() + 3.0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard 0 ..< completions.count ~= row,
            let cellView = tableView.make(withIdentifier: "CompletionCell", owner: self) as? CompletionCellView else {
            return nil
        }

        let completion = completions[row]

        cellView.completionTextField.preferredMaxLayoutWidth = cellView.frame.width - (cellView.completionLeadingSpaceContraint.constant + cellView.completionTrailingSpaceContraint.constant)
        cellView.completionTextField.stringValue = completion

        return cellView
    }
}
