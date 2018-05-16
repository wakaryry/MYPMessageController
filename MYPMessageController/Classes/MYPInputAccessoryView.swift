//
//  MYPInputAccessoryView.swift
//  MYPTextInputVC
//
//  Created by wakary redou on 2018/4/23.
//  Copyright © 2018年 wakary redou. All rights reserved.
//

import UIKit

public class MYPInputAccessoryView: UIView {
    /* The system keyboard view used as reference. */
    weak var keyboardViewProxy: UIView? {
        return keyboardViewProxyHelper
    }
    
    lazy private var keyboardViewProxyHelper: UIView? = {
        let winds = UIApplication.shared.windows
        
        for w in winds.reversed() {
            let boardView = self.findKeyboard(in: w)
            if boardView != nil {
                return boardView
            }
        }
        return nil
    }()
    
    private func findKeyboard(in view: UIView) -> UIView? {
        for sub in view.subviews {
            if (strstr(object_getClassName(sub), "UIKeyboard") != nil) {
                return sub
            }
            else {
                let temp = self.findKeyboard(in: sub)
                if temp != nil {
                    return temp
                }
            }
        }
        return nil
    }
}
