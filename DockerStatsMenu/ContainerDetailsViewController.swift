//
//  ContainerDetailsViewController.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 08/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

class ContainerDetailsViewController: NSViewController {
    @IBOutlet weak var nameTextField: NSTextField!
    @IBOutlet weak var backButton: NSButton!
    @IBOutlet weak var idTextField: NSTextField!
    @IBOutlet weak var imageTextField: NSTextField!
    @IBOutlet weak var commandTextField: NSTextField!
    @IBOutlet weak var createdTextField: NSTextField!
    @IBOutlet weak var statusTextField: NSTextField!
    @IBOutlet weak var startStopButton: NSButton!
    @IBOutlet weak var resumePauseButton: NSButton!
    @IBOutlet weak var deleteButton: NSButton!

    @IBAction func userDidClickBack(_ sender: NSButton) {
        presenting?.dismissViewController(self)
    }

    @IBAction func userDidClickStartStop(_ sender: NSButton) {
        guard let container = container, let apiClient = apiClient else { return }

        if container.state == .running {
            apiClient.stopContainer(withId: container.id, completion: handleAction)
        } else {
            apiClient.startContainer(withId: container.id, completion: handleAction)
        }
    }

    @IBAction func userDidClickResumePause(_ sender: NSButton) {
        guard let container = container, let apiClient = apiClient else { return }

        if container.state == .paused {
            apiClient.resumeContainer(withId: container.id, completion: handleAction)
        } else {
            apiClient.pauseContainer(withId: container.id, completion: handleAction)
        }
    }

    @IBAction func userDidClickDelete(_ sender: NSButton) {
        guard let container = container, let apiClient = apiClient,
            container.state == .exited else { return }

        apiClient.removeContainer(withId: container.id) { response, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    self.presentError(error!)
                }

                return
            }

            DispatchQueue.main.async {
                self.presenting?.dismissViewController(self)
            }
        }
    }

    var containerId: String?

    var apiClient: DockerAPI?

    private var container: ContainerDetails?

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateContainerDetails()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 123 {
            backButton.performClick(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    private func handleAction(response: Response?, error: Error?) {
        guard error == nil else {
            DispatchQueue.main.async {
                self.presentError(error!)
            }

            return
        }

        self.updateContainerDetails()
    }

    private func updateContainerDetails() {
        guard let containerId = containerId, let apiClient = apiClient else { return }

        apiClient.getContainer(withId: containerId) { container, error in
            guard let container = container, error == nil else {
                return
            }

            self.container = container

            DispatchQueue.main.async {
                self.updateViews()
            }
        }
    }

    private func updateViews() {
        guard let container = container else { return }

        self.nameTextField.stringValue = String(container.name.characters.dropFirst())
        self.idTextField.stringValue = String(container.id.characters.prefix(12))
        self.idTextField.toolTip = container.id
        self.imageTextField.stringValue = container.image
        self.commandTextField.stringValue = container.command
        self.createdTextField.objectValue = container.created
        self.statusTextField.stringValue = container.state.rawValue

        self.updateActionButtons(container: container)
    }

    private func updateActionButtons(container: ContainerDetails) {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current().allowsImplicitAnimation = true

        switch container.state {
        case .exited:
            startStopButton.image = NSImage(named: "StartIconTemplate")
            startStopButton.toolTip = "Start this container"
            startStopButton.isHidden = false
            resumePauseButton.isHidden = true
            deleteButton.isHidden = false
            break

        case .running:
            startStopButton.image = NSImage(named: "StopIconTemplate")
            startStopButton.toolTip = "Stop this container"
            startStopButton.isHidden = false
            resumePauseButton.image = NSImage(named: "PauseIconTemplate")
            resumePauseButton.toolTip = "Pause this container"
            resumePauseButton.isHidden = false
            deleteButton.isHidden = true
            break

        case .paused:
            resumePauseButton.image = NSImage(named: "ResumeIconTemplate")
            resumePauseButton.toolTip = "Resume this container"
            resumePauseButton.isHidden = false
            startStopButton.isHidden = true
            deleteButton.isHidden = true
            break

        case .unknown:
            startStopButton.isHidden = true
            resumePauseButton.isHidden = true
            deleteButton.isHidden = true
        }

        NSAnimationContext.endGrouping()
    }
}
