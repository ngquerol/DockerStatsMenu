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
    let popover: NSPopover = NSPopover()
    let themeChangeNotificationName = Notification.Name(rawValue: "AppleInterfaceThemeChangedNotification")

    var darkModeEnabled: Bool {
        return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") != nil
    }

    func togglePopover(_ sender: Any?) {
        popover.isShown ? hidePopover(sender) : showPopover(sender)
    }

    func updatePopoverAppearance(_ notification: Notification) {
        popover.appearance = NSAppearance(named: darkModeEnabled ? NSAppearanceNameVibrantDark : NSAppearanceNameVibrantLight)
    }

    func showPopover(_ sender: Any?) {
        guard let statusButton = statusItem.button else {
            return
        }

        NSRunningApplication.current().activate(options: .activateIgnoringOtherApps)

        popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
    }

    func hidePopover(_ sender: Any?) {
        popover.performClose(sender)
    }
}

extension AppDelegate: NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let popoverViewController = storyboard.instantiateController(withIdentifier: "PopoverViewController") as? PopoverViewController

        popoverViewController?.popover = popover
        popover.behavior = .semitransient
        popover.animates = true
        popover.contentViewController = popoverViewController
        statusItem.image = NSImage(named: "StatusIconTemplate")
        statusItem.action = #selector(togglePopover(_:))

        DistributedNotificationCenter.default().addObserver(self,
                                                            selector: #selector(AppDelegate.updatePopoverAppearance(_:)),
                                                            name: themeChangeNotificationName,
                                                            object: nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        DistributedNotificationCenter.default().removeObserver(self,
                                                               name: themeChangeNotificationName,
                                                               object: nil)
    }
}
