//
//  MYPUIConstants.swift
//  MYPTextInputVC
//
//  Created by wakary redou on 2018/4/20.
//  Copyright © 2018年 wakary redou. All rights reserved.
//

import Foundation
import UIKit

enum MYPKeyboardStatus : Int {
    case didHide
    case willShow
    case didShow
    case willHide
}

let MYPOnePixal = 1 / UIScreen.main.scale
// 当线宽为奇数时，需要偏移
let MYPOnePixalOffset = MYPOnePixal / 2

let MYPKeyWindowBounds = UIApplication.shared.keyWindow?.bounds

let MYP_IS_LANDSPACE = UIApplication.shared.statusBarOrientation.rawValue == UIDeviceOrientation.landscapeLeft.rawValue || UIApplication.shared.statusBarOrientation.rawValue == UIDeviceOrientation.landscapeRight.rawValue

let MYP_IS_IPAD = UIDevice.current.userInterfaceIdiom == .pad
let MYP_IS_IPHONE = UIDevice.current.userInterfaceIdiom == .phone

// 6\7\8
let MYP_IS_IPHONE6 = Int((MYPKeyWindowBounds?.size.height)!) == 667
//6p\7p\8p
let MYP_IS_IPHONE6P = Int((MYPKeyWindowBounds?.size.height)!) == 736
let MYP_IS_IPHONEX = Int((MYPKeyWindowBounds?.size.height)!) == 812

func MYP_IS_IOS10() -> Bool {
    if #available(iOS 10, *) {
        if #available(iOS 11, *) {
            return false
        }
        return true
    }
    return false
}

func MYP_IS_IOS11() -> Bool {
    if #available(iOS 11, *) {
        return true
    }
    return false
}

func MYP_IS_IOS10_OR_HIGHER() -> Bool{
    if #available(iOS 10, *) {
        return true
    }
    if #available(iOS 11, *) {
        return true
    }
    return false
}

let MYPTextInputVCDomain = "me.redou.MYPTextInputVC"

func MYPPointSizeDifferenceForCategory(_ category: UIContentSizeCategory) -> CGFloat {
    if category == UIContentSizeCategory.extraSmall {
        return -3.0
    }
    if category == UIContentSizeCategory.small {
        return -2.0
    }
    if category == UIContentSizeCategory.medium {
        return -1.0
    }
    if category == UIContentSizeCategory.large {
        return 0.0
    }
    if category == UIContentSizeCategory.extraLarge {
        return 2.0
    }
    if category == UIContentSizeCategory.extraExtraLarge {
        return 4.0
    }
    if category == UIContentSizeCategory.extraExtraExtraLarge {
        return 6.0
    }
    if category == UIContentSizeCategory.accessibilityMedium {
        return 8.0
    }
    if category == UIContentSizeCategory.accessibilityLarge {
        return 10.0
    }
    if category == UIContentSizeCategory.accessibilityExtraLarge {
        return 11.0
    }
    if category == UIContentSizeCategory.accessibilityExtraExtraLarge {
        return 12.0
    }
    if category == UIContentSizeCategory.accessibilityExtraExtraExtraLarge {
        return 13.0
    }
    return 0.0
}

func MYPRectInvert(rect: CGRect) -> CGRect {
    var invert = CGRect.zero
    invert.origin.x = rect.origin.y
    invert.origin.y = rect.origin.x
    invert.size.width = rect.size.height
    invert.size.height = rect.size.width
    return invert
}

extension Notification.Name {
    public struct MYPTextInputTask {
        public static let MYPTextViewTextWillChangeNotification = Notification.Name(rawValue: "me.redou.notification.name.task.TextViewTextWillChangeNotification")
        public static let MYPTextViewContentSizeDidChangeNotification = Notification.Name(rawValue: "me.redou.notification.name.task.TextViewContentSizeDidChangeNotification")
        public static let MYPTextViewSelectedRangeDidChangeNotification = Notification.Name(rawValue: "me.redou.notification.name.task.TextViewSelectedRangeDidChangeNotification")
        public static let MYPTextViewDidPasteItemNotification = Notification.Name(rawValue: "me.redou.notification.name.task.TextViewDidPasteItemNotification")
        public static let MYPTextViewDidShakeNotification = Notification.Name(rawValue: "me.redou.notification.name.task.TextViewDidShakeNotification")
    }
    
    public struct MYPTextInputbarTask {
        public static let MYPTextInputbarDidMoveNotification = Notification.Name(rawValue: "me.redou.notification.name.task.TextInputbarDidMoveNotification")
    }
}

/** no matter what first responder is, it could resign it.
 This should be more effective than even [self.view.window endEditing:YES].
 https://stackoverflow.com/questions/1823317/get-the-current-first-responder-without-using-a-private-api/27140764#27140764.
 if we want to resign X. X isFirstResponder, then resign it.
 we should not use X becomeFirst and then resign, it's not safe for layout, and a bit dangerous.
 */
func MYPResignFirstResponder() {
    UIApplication.shared.sendAction(#selector(UIView.resignFirstResponder), to: nil, from: nil, for: nil)
}
