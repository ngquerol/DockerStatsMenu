//
//  PreferencesViewController.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 18/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

class PreferencesViewController: NSViewController {
    @IBOutlet weak var socketPathTextField: CompletableTextField! {
        didSet {
            socketPathTextField.completionDelegate = FilePathCompletionDelegate()
        }
    }

    @IBOutlet weak var socketPathWarningImageView: NSImageView!
    @IBOutlet weak var updateIntervalTextField: NSTextField!
    @IBOutlet weak var updateIntervalSlider: NSSlider!
    @IBOutlet weak var showAllContainersCheckBox: NSButton!

    @IBAction func userDidClickBack(_ sender: NSButton) {
        presenting?.dismissViewController(self)
    }

    @IBAction func userDidChangeSocketPathTextField(_ sender: NSTextField) {
        preferences.dockerSocketPath = socketPathTextField.stringValue
        updateSocketPathWarningImageView()
    }

    @IBAction func userDidChangeUpdateIntervalViaTextField(_ sender: NSTextField) {
        updateIntervalTextField.integerValue = sender.integerValue
        updateIntervalSlider.integerValue = sender.integerValue
        preferences.containersUpdateInterval = sender.integerValue
    }

    @IBAction func userDidChangeUpdateIntervalViaStepper(_ sender: NSSlider) {
        updateIntervalTextField.integerValue = sender.integerValue
        updateIntervalSlider.integerValue = sender.integerValue
        preferences.containersUpdateInterval = sender.integerValue
    }

    @IBAction func userDidChangeShowAllContainers(_ sender: NSButton) {
        preferences.showAllContainers = showAllContainersCheckBox.state == NSOnState
    }

    private var preferences = Preferences.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        socketPathTextField.stringValue = preferences.dockerSocketPath
        updateIntervalTextField.integerValue = preferences.containersUpdateInterval
        updateIntervalSlider.integerValue = preferences.containersUpdateInterval
        showAllContainersCheckBox.state = preferences.showAllContainers ? NSOnState : NSOffState

        updateSocketPathWarningImageView()
    }

    private func isValidDockerSocket(path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let pathExists = FileManager.default.fileExists(atPath: socketPathTextField.stringValue, isDirectory: &isDirectory)

        guard pathExists, !isDirectory.boolValue else {
            return false
        }

        let isReadable = FileManager.default.isReadableFile(atPath: socketPathTextField.stringValue)
        let isWritable = FileManager.default.isWritableFile(atPath: socketPathTextField.stringValue)

        guard isReadable && isWritable else {
            return false
        }

        let testSocket = UnixClientSocket(path: path)

        defer {
            testSocket.close()
        }

        do {
            try testSocket.connect()
            return true
        } catch {
            return false
        }
    }

    private func updateSocketPathWarningImageView() {
        let socketPath = socketPathTextField.stringValue

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25

            socketPathWarningImageView.animator().isHidden = true
        }, completionHandler: {
            if self.isValidDockerSocket(path: socketPath) {
                self.socketPathWarningImageView.image = NSImage(named: "ValidIcon")
                self.socketPathWarningImageView.toolTip = nil
            } else {
                self.socketPathWarningImageView.image = NSImage(named: "InvalidIcon")
                self.socketPathWarningImageView.toolTip = "\"\(socketPath)\" does not point to a valid docker socket"
            }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25

                self.socketPathWarningImageView.animator().isHidden = false
            }, completionHandler: nil)
        })
    }
}
