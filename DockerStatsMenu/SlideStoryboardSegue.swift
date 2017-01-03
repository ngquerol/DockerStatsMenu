//
//  SlideStoryboardSegue.swift
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 08/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

class SlideStoryBoardSegue: NSStoryboardSegue {
    
    override func perform() {
        guard let sourceViewController = sourceController as? NSViewController,
            sourceViewController.parent != nil,
            let destinationViewController = destinationController as? NSViewController else {
            return
        }

        sourceViewController.view.window?.makeFirstResponder(destinationViewController)
        sourceViewController.presentViewController(destinationViewController, animator: SlideSegueAnimator(duration: 0.3))
    }
}
