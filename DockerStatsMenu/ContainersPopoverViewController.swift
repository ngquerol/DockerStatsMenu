//
//  ContainersPopoverViewController.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 05/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

class ContainersPopoverViewController: NSViewController {

    @IBOutlet weak var containersTableView: NSTableView!

    let apiClient: DockerAPI = SocketDockerAPI(socketPath: "/tmp/test.sock")

    let updateTimerSource = DispatchSource.makeTimerSource()

    let updateInterval = DispatchTimeInterval.seconds(1)

    let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    var containers = [Container]()

    var showAllContainers = false

    override func viewDidLoad() {
        super.viewDidLoad()

        connect()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        updateTimerSource.resume()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        updateTimerSource.suspend()
    }

    private func connect() {
        do {
            try apiClient.connect()
        } catch (let error) {
            if let error = error as? ClientSocketError {
            }

            return
        }

        updateTimerSource.scheduleRepeating(deadline: .now(), interval: updateInterval)
        updateTimerSource.setEventHandler {
            self.apiClient.getContainersList(showAll: self.showAllContainers) { containers, error in
                guard error == nil, let containers = containers else {
                    NSLog("Could not get containers list: %@", error?.localizedDescription ?? "unknown")
                    return
                }

                let sortedContainers = containers.sorted()
                let added = sortedContainers.filter { !self.containers.contains($0) }.flatMap { sortedContainers.index(of: $0) }
                let removed = self.containers.filter { !sortedContainers.contains($0) }.flatMap { self.containers.index(of: $0) }

                self.containers = sortedContainers

                DispatchQueue.main.async {
                    self.containersTableView.beginUpdates()
                    self.containersTableView.insertRows(at: IndexSet(added), withAnimation: .slideLeft)
                    self.containersTableView.removeRows(at: IndexSet(removed), withAnimation: .effectFade)
                    self.containersTableView.endUpdates()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.containersTableView.reloadData()
                }
            }
        }
    }
}

extension ContainersPopoverViewController: NSTableViewDelegate {
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
        cellView.imageTextField.stringValue = container.image

        return cellView
    }
}

extension ContainersPopoverViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return containers.count
    }
}
