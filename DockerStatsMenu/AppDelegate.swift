//
//  AppDelegate.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 14/11/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject {

    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)

    let popover: NSPopover = {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let popover = NSPopover()

        popover.behavior = .transient
        popover.appearance = NSAppearance.current()

        guard let popoverViewController = storyboard.instantiateController(withIdentifier: "ContainersPopoverViewController") as? ContainersPopoverViewController else {
            return popover
        }

        popover.contentViewController = popoverViewController

        return popover
    }()

    func togglePopover(_ sender: Any?) {
        popover.isShown ? hidePopover(sender) : showPopover(sender)
    }

    func showPopover(_ sender: Any?) {
        guard let statusButton = statusItem.button else {
            return
        }

        popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
    }

    func hidePopover(_ sender: Any?) {
        popover.performClose(sender)
    }
}

extension AppDelegate: NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem.image = NSImage(named: "StatusIconTemplate")
        statusItem.action = #selector(togglePopover(_:))
    }

    func applicationWillTerminate(_ aNotification: Notification) {}
}
