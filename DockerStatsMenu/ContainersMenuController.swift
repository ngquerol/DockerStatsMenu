//
//  ContainersMenuController.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 04/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

class ContainersMenuController: NSViewController {

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var containersTitleMenuItem: NSMenuItem!
    @IBOutlet weak var showAllMenuItem: NSMenuItem!
    @IBOutlet weak var errorMenuItem: NSMenuItem! {
        didSet {
            errorMenuItem.isHidden = true
        }
    }
    @IBOutlet weak var reconnectMenuItem: NSMenuItem!
    @IBOutlet weak var containersSeparatorMenuItem: NSMenuItem!

    @IBAction func userDidClickShowAll(_ sender: NSMenuItem) {
        sender.state = sender.state == NSOnState ? NSOffState : NSOnState
        showAllContainers = sender.state == NSOnState
    }

    @IBAction func userDidClickReconnect(_ sender: NSMenuItem) {
        connect()
    }

    @IBAction func userDidClickQuit(_ sender: NSMenuItem) {
        NSApplication.shared().terminate(sender)
    }

    let apiClient: DockerAPI = SocketDockerAPI(socketPath: "/tmp/test.sock")

    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)

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

    var showAllContainers = false

    override func awakeFromNib() {
        statusItem.menu = statusMenu

        connect()
    }

    private func connect() {
        do {
            try apiClient.connect()
        } catch (let error) {
            statusItem.image = NSImage(named: "WarnStatusIconTemplate")
            containersTitleMenuItem.title = "Could not connect to Docker daemon"
            reconnectMenuItem.isHidden = false
            showAllMenuItem.isHidden = true

            if let error = error as? ClientSocketError {
                containersTitleMenuItem.toolTip = error.localizedDescription
            }

            return
        }

        statusItem.image = NSImage(named: "StatusIconTemplate")
        containersTitleMenuItem.title = "Containers"
        containersTitleMenuItem.toolTip = nil
        reconnectMenuItem.isHidden = true
        showAllMenuItem.isHidden = false

        updateTimerSource.scheduleRepeating(deadline: .now(), interval: updateInterval)
        updateTimerSource.setEventHandler {
            self.apiClient.getContainersList(showAll: self.showAllContainers) { containers, error in
                guard error == nil, let containers = containers else {
                    NSLog("Could not get containers list: %@", error?.localizedDescription ?? "unknown")
                    return
                }

                DispatchQueue.main.async {
                    self.clearContainersMenu()
                    self.buildContainersMenu(containers: containers)
                }
            }
        }
    }

    private func clearContainersMenu() {
        let start = statusMenu.index(of: containersTitleMenuItem).advanced(by: 1)
        let end = statusMenu.index(of: showAllMenuItem)

        guard start != end else { return }

        for _ in start ..< end {
            statusMenu.removeItem(at: start)
        }
    }

    private func buildContainersMenu(containers: [Container]) {
        containers.enumerated().forEach { index, container in
            let containerMenu = NSMenu(title: "")
            let containerMenuItem = NSMenuItem(title: String(container.names[0].characters.dropFirst()), action: nil, keyEquivalent: "")

            switch container.state {
            case .running:
                containerMenuItem.image = NSImage(named: "NSStatusAvailable")
                break
            case .paused:
                containerMenuItem.image = NSImage(named: "NSStatusPartiallyAvailable")
                break
            case .exited:
                containerMenuItem.image = NSImage(named: "NSStatusUnavailable")
                break
            case .unknown:
                containerMenuItem.image = NSImage(named: "NSStatusNone")
                break
            }

            let id = NSMenuItem(title: "Id: \(container.id.substring(to: container.id.index(container.id.startIndex, offsetBy: 12)))", action: nil, keyEquivalent: "")
            let image = NSMenuItem(title: "Image: \(container.image)", action: nil, keyEquivalent: "")
            let created = NSMenuItem(title: "Created: \(formatter.string(from: container.created))", action: nil, keyEquivalent: "")
            let status = NSMenuItem(title: "Status: \(container.status)", action: nil, keyEquivalent: "")

            [id, image, created, status].forEach { containerMenu.addItem($0) }

            self.statusMenu.insertItem(containerMenuItem, at: self.statusMenu.index(of: self.containersTitleMenuItem) + (1 + index))
            self.statusMenu.setSubmenu(containerMenu, for: containerMenuItem)
        }
    }
}

extension ContainersMenuController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateTimerSource.resume()
    }

    func menuDidClose(_ menu: NSMenu) {
        updateTimerSource.suspend()
    }
}
