//
//  ContainersViewController.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 05/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

class ContainersViewController: NSViewController {
    @IBOutlet weak var containersTableView: NSTableView!
    @IBOutlet weak var containersStatusSeparator: NSBox!
    @IBOutlet weak var statusBarView: NSVisualEffectView!
    @IBOutlet weak var dockerVersionTextField: NSTextField!

    @IBAction func userDidClickQuit(_ sender: NSMenuItem) {
        NSApp.terminate(sender)
    }

    fileprivate var containers = [Container]()

    private let updateTimer = DispatchSource.makeTimerSource()

    private var updateInterval = DispatchTimeInterval.seconds(Preferences.shared.containersUpdateInterval)

    private var apiClient: DockerAPI = SocketDockerAPI(socketPath: Preferences.shared.dockerSocketPath)

    private var showAllContainers = Preferences.shared.showAllContainers

    private var preferencesListeners = [NSObjectProtocol]()

    override func viewDidLoad() {
        super.viewDidLoad()

        connect()

        updateTimer.setEventHandler { self.updateContainersList() }
        updateTimer.scheduleRepeating(deadline: .now(), interval: updateInterval)

        updateVersionInfo()

        preferencesListeners.append(contentsOf: [
            NotificationCenter.default.addObserver(forName: Preferences.DockerSocketPathChangedNotification,
                                                   object: nil,
                                                   queue: nil) { _ in
                self.apiClient = SocketDockerAPI(socketPath: Preferences.shared.dockerSocketPath)
                self.connect()
                self.updateVersionInfo()
            },
            NotificationCenter.default.addObserver(forName: Preferences.ContainersUpdateIntervalChangedNotification,
                                                   object: nil,
                                                   queue: nil) { _ in
                self.updateInterval = DispatchTimeInterval.seconds(Preferences.shared.containersUpdateInterval)
                self.updateTimer.scheduleRepeating(deadline: .now(), interval: self.updateInterval)
            },
            NotificationCenter.default.addObserver(forName: Preferences.ShowAllContainersChangedNotification,
                                                   object: nil,
                                                   queue: nil) { _ in
                self.showAllContainers = Preferences.shared.showAllContainers
            },
        ])
    }

    deinit {
        updateTimer.cancel()

        preferencesListeners.forEach {
            NotificationCenter.default.removeObserver($0)
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        view.window?.makeFirstResponder(containersTableView)
        updateTimer.resume()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        updateTimer.suspend()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 124 {
            performSegue(withIdentifier: "ShowContainerDetailsSegue", sender: nil)
        } else {
            super.keyDown(with: event)
        }
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "ShowContainerDetailsSegue" {
            return 0 ..< containersTableView.numberOfRows ~= containersTableView.selectedRow
        }

        if identifier == "ShowPreferencesSegue" {
            return true
        }

        if identifier == "ShowAboutSegue" {
            return true
        }

        return false
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowContainerDetailsSegue" {
            guard let detailsViewController = segue.destinationController as? ContainerDetailsViewController else {
                return
            }

            detailsViewController.apiClient = apiClient
            detailsViewController.containerId = containers[containersTableView.selectedRow].id
        }
    }

    private func connect() {
        do {
            try apiClient.connect()
        } catch let error as ClientSocketError {
            NSLog(error.localizedDescription)
        } catch {
            NSLog(error.localizedDescription)
        }
    }

    private func updateVersionInfo() {
        apiClient.getVersionInfo { versionInfo, error in
            guard error == nil, let versionInfo = versionInfo else {
                self.dockerVersionTextField.isHidden = true
                return
            }

            self.dockerVersionTextField.isHidden = false
            self.dockerVersionTextField.stringValue = "Docker v\(versionInfo.version)"
        }
    }

    private func updateContainersList() {
        apiClient.getContainersList(showAll: self.showAllContainers) { containers, error in
            guard error == nil, let containers = containers else {
                NSLog("Could not get containers list: %@", error?.localizedDescription ?? "unknown")
                return
            }

            let sortedContainers = containers.sorted()
            let added = sortedContainers.filter { !self.containers.contains($0) }.flatMap { sortedContainers.index(of: $0) }
            let removed = self.containers.filter { !sortedContainers.contains($0) }.flatMap { self.containers.index(of: $0) }

            self.containers = sortedContainers

            DispatchQueue.main.async {
                let selectedIndexPaths = self.containersTableView.selectedRowIndexes

                self.containersTableView.beginUpdates()
                self.containersTableView.insertRows(at: IndexSet(added), withAnimation: .slideLeft)
                self.containersTableView.removeRows(at: IndexSet(removed), withAnimation: .effectFade)
                self.containersTableView.endUpdates()

                self.containersTableView.reloadData()
                self.containersTableView.selectRowIndexes(selectedIndexPaths, byExtendingSelection: false)
                self.updatePopoverHeight()
            }
        }
    }

    private func updatePopoverHeight() {
        guard let popoverViewController = parent as? PopoverViewController,
            let popover = popoverViewController.popover else {
            return
        }

        let maxHeight = view.frame.width * 2.0
        let minHeight: CGFloat = 200.0
        let newHeight = containersTableView.intrinsicContentSize.height +
            (containersTableView.intercellSpacing.height * CGFloat(containersTableView.numberOfRows + 1)) +
            containersStatusSeparator.intrinsicContentSize.height +
            statusBarView.intrinsicContentSize.height

        popover.contentSize.height = (newHeight < maxHeight) ? ((newHeight > minHeight) ? newHeight : minHeight) : maxHeight
    }
}

extension ContainersViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 25.0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cellView = tableView.make(withIdentifier: "ContainerCell", owner: self) as? ContainerTableCellView else { return nil }

        let container = containers[row]

        switch container.state {
        case .running:
            cellView.statusImageView.image = NSImage(named: "NSStatusAvailable")
            break
        case .exited:
            cellView.statusImageView.image = NSImage(named: "NSStatusUnavailable")
            break
        case .paused:
            cellView.statusImageView.image = NSImage(named: "NSStatusPartiallyAvailable")
            break
        case .unknown:
            cellView.statusImageView.image = NSImage(named: "NSStatusNone")
            break
        }

        cellView.statusImageView.toolTip = container.state.rawValue
        cellView.nameTextField.stringValue = String(container.names[0].characters.dropFirst())

        return cellView
    }
}

extension ContainersViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return containers.count
    }
}
