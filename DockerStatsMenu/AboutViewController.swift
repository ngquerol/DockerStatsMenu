//
//  AboutViewController.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 31/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

class AboutViewController: NSViewController {
    @IBOutlet weak var nameTextField: NSTextField!
    @IBOutlet weak var versionTextField: NSTextField!
    @IBOutlet var creditsTextView: NSTextView!
    @IBOutlet weak var copyrightTextField: NSTextField!

    @IBAction func userDidClickBack(_ sender: NSButton) {
        presenting?.dismissViewController(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        loadBundleInfo()
        loadCredits()
    }

    private func loadBundleInfo() {
        guard let info = Bundle.main.infoDictionary else { return }

        let bundleName = info["CFBundleName"] as? String ?? "Diurna",
            bundleVersion = info["CFBundleShortVersionString"] as? String ?? "?",
            bundleBuild = info["CFBundleVersion"] as? String ?? "?",
            copyright = info["NSHumanReadableCopyright"] as? String ?? "© 2016 Nicolas Gaulard-Querol, all rights reserved"

        nameTextField.stringValue = bundleName
        versionTextField.stringValue = "Version \(bundleVersion) (\(bundleBuild))"
        copyrightTextField.stringValue = copyright
    }

    private func loadCredits() {
        guard let creditsFileURL = Bundle.main.url(forResource: "Credits", withExtension: "rtf") else {
            creditsTextView.isHidden = true
            return
        }

        if let creditsText = try? NSAttributedString(
            url: creditsFileURL,
            options: [NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType],
            documentAttributes: nil
        ) {
            creditsTextView?.textStorage?.setAttributedString(creditsText)
        }
    }
}
