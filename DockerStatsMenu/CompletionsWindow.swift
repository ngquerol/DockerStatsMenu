//
//  CompletionsWindow.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 29/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

class CompletionsWindow: NSWindow {

    override init(contentRect: NSRect, styleMask style: NSWindowStyleMask, backing bufferingType: NSBackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: bufferingType, defer: flag)
        
        self.hasShadow = true
        self.backgroundColor = .clear
        self.isOpaque = false
    }
}
