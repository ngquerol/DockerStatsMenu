//
//  StatusBarView.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 03/01/2017.
//  Copyright © 2017 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

class StatusBarView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        let gradient = NSGradient(colors: [ NSColor.quaternaryLabelColor,
                                            NSColor.tertiaryLabelColor ])

        gradient?.draw(in: dirtyRect, angle: 270.0)

        NSColor.gridColor.setStroke()
        let path = NSBezierPath()
        path.lineWidth = 2.0
        path.move(to: NSPoint(x: 0.0, y: NSMaxY(dirtyRect)))
        path.line(to: NSPoint(x: NSMaxX(dirtyRect), y: NSMaxY(dirtyRect)))
        path.stroke()
    }
}
