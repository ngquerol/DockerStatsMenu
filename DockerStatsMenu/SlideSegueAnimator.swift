//
//  SlideSegueAnimator
//  DockerStatsMenu
//
//  Created by Nicolas Gaulard-Querol on 10/12/2016.
//  Copyright © 2016 Nicolas Gaulard-Querol. All rights reserved.
//

import Cocoa

class SlideSegueAnimator: NSObject {
    fileprivate let duration: TimeInterval

    fileprivate var originalSize: CGSize?

    init(duration: TimeInterval) {
        self.duration = duration
    }
}

extension SlideSegueAnimator: NSViewControllerPresentationAnimator {
    
    func animatePresentation(of viewController: NSViewController, from fromViewController: NSViewController) {
        guard let popoverViewController = fromViewController.parent as? PopoverViewController else { return }

        fromViewController.view.wantsLayer = true
        viewController.view.wantsLayer = true
        viewController.view.layer?.isOpaque = true

        let fromFrame = fromViewController.view.frame
        let originalFrame = viewController.view.frame
        let startFrame = NSRect(x: fromFrame.width, y: 0, width: originalFrame.width, height: fromFrame.height)
        let destinationFrame = NSRect(x: 0, y: 0, width: originalFrame.width, height: fromFrame.height)

        originalSize = fromFrame.size

        viewController.view.frame = startFrame
        viewController.view.alphaValue = 0.0

        popoverViewController.addChildViewController(viewController)
        popoverViewController.view.addSubview(viewController.view)
        popoverViewController.popover?.contentSize = destinationFrame.size

        NSAnimationContext.runAnimationGroup({ context in
            context.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
            context.duration = duration

            viewController.view.animator().frame = destinationFrame
            viewController.view.animator().alphaValue = 1.0
            fromViewController.view.animator().alphaValue = 0.0
        }, completionHandler: {
            fromViewController.view.isHidden = true
        })
    }

    func animateDismissal(of viewController: NSViewController, from fromViewController: NSViewController) {
        guard let popoverViewController = fromViewController.parent as? PopoverViewController else { return }

        fromViewController.view.wantsLayer = true
        viewController.view.wantsLayer = true
        viewController.view.layer?.isOpaque = true

        let fromFrame = fromViewController.view.frame
        let originalFrame = viewController.view.frame
        let destinationFrame = NSRect(x: fromFrame.width, y: 0, width: originalSize?.width ?? originalFrame.width, height: originalSize?.height ?? fromFrame.height)

        popoverViewController.view.addSubview(fromViewController.view)
        popoverViewController.popover?.contentSize = destinationFrame.size

        fromViewController.view.isHidden = false

        NSAnimationContext.runAnimationGroup({ context in
            context.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
            context.duration = duration

            viewController.view.animator().frame = destinationFrame
            viewController.view.animator().alphaValue = 0.0
            fromViewController.view.animator().alphaValue = 1.0
        }, completionHandler: {
            viewController.view.removeFromSuperview()
            viewController.removeFromParentViewController()
        })
    }
}
