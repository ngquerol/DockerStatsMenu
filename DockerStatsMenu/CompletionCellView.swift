//
//  CompletionCellView.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 30/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

class CompletionCellView: NSTableCellView {
    @IBOutlet weak var completionTextField: NSTextField!
    @IBOutlet weak var completionLeadingSpaceContraint: NSLayoutConstraint!
    @IBOutlet weak var completionTrailingSpaceContraint: NSLayoutConstraint!

    override var backgroundStyle: NSBackgroundStyle {
        didSet {
            if backgroundStyle == .dark {
                completionTextField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(),
                                                             weight: NSFontWeightMedium)
            } else {
                completionTextField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize())
            }
        }
    }
}
