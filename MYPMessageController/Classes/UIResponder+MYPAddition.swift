//
//  UIResponder+MYPAddition.swift
//  MYPTextInputVC
//
//  Created by wakary redou on 2018/5/4.
//  Copyright © 2018年 wakary redou. All rights reserved.
//

import UIKit

/** @name UIResponder additional features used for MYPMessageVC.
 https://stackoverflow.com/questions/1823317/get-the-current-first-responder-without-using-a-private-api/27140764#27140764
 */
extension UIResponder {
    /**
     Returns the current first responder object.
     */
    private weak static var __currentFirstResponder: UIResponder? = nil
    
    /**
     Returns the current first responder object.
     [help link](https://stackoverflow.com/questions/1823317/get-the-current-first-responder-without-using-a-private-api/27140764#2714076)
     ``` swift
     extension UIView {
     func firstResponder() -> UIView? {
         if self.isFirstResponder() {
             return self
         }
         for subview in self.subviews {
             if let firstResponder = subview.firstResponder() {
                 return firstResponder
             }
         }
         return nil
     }
     }
     ```
     */
    public static var current: UIResponder? {
        UIResponder.__currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(myp_findFirstResponder(sender:)), to: nil, from: nil, for: nil)
        return UIResponder.__currentFirstResponder
    }
    
    @objc internal func myp_findFirstResponder(sender: AnyObject) {
        UIResponder.__currentFirstResponder = self
    }
}
