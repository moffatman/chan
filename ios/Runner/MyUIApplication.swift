//
//  MyUIApplication.swift
//  Runner
//
//  Created by Callum Moffat on 2026-03-13.
//

class MyUIApplication : UIApplication {
    var secondaryTouches: Set<UITouch> = []
    override func sendEvent(_ event: UIEvent) {
        if #available(iOS 13.4, *) {
            if Utils.isOnMac && event.type == UIEvent.EventType.touches {
                if let window = self.delegate?.window ?? nil, let vc = window.rootViewController, let touches = event.touches(for: window) {
                    var began: Set<UITouch> = []
                    var moved: Set<UITouch> = []
                    var ended: Set<UITouch> = []
                    var cancelled: Set<UITouch> = []
                    
                    for touch in touches {
                        let isSecondary = event.buttonMask.contains(UIEvent.ButtonMask.secondary)
                        if isSecondary && touch.phase == .began {
                            began.insert(touch);
                            secondaryTouches.insert(touch);
                        }
                        else if isSecondary && touch.phase == .moved {
                            moved.insert(touch);
                        }
                        else if touch.phase == .ended && secondaryTouches.contains(touch) {
                            ended.insert(touch);
                            secondaryTouches.remove(touch);
                        }
                        else if touch.phase == .cancelled && secondaryTouches.contains(touch) {
                            cancelled.insert(touch);
                            secondaryTouches.remove(touch);
                        }
                    }
                    
                    if !began.isEmpty {
                        vc.touchesBegan(began, with: event)
                    }
                    if !moved.isEmpty {
                        vc.touchesMoved(moved, with: event)
                    }
                    if !ended.isEmpty {
                        vc.touchesEnded(ended, with: event)
                    }
                    if !cancelled.isEmpty {
                        vc.touchesCancelled(cancelled, with: event)
                    }
                }
            }
        }
        super.sendEvent(event)
    }
}

