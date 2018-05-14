//
//  UIScrollView+MYPAddition.swift
//  MYPTextInputVC
//
//  Created by wakary redou on 2018/5/4.
//  Copyright © 2018年 wakary redou. All rights reserved.
//

import UIKit

/** UIScrollView additional features used for MYPMessageVC. */
extension UIScrollView {
    /** true if the scrollView's offset is at the very top. */
    var myp_isAtTop: Bool {
        return self.myp_visibleRect.minY <= self.bounds.minY
    }
    
    /** true if the scrollView's offset is at the very bottom. */
    var myp_isAtBottom: Bool {
        return self.myp_visibleRect.maxY >= self.myp_bottomRect.maxY
    }
    
    /** The visible area of the content size. */
    var myp_visibleRect: CGRect {
        
        return CGRect(origin: self.contentOffset, size: self.frame.size)
    }
    
    /**
     Sets the content offset to the top.
     
     animated: true to animate the transition at a constant velocity to the new offset, false to make the transition immediate.
     */
    func myp_scrollToTop(animated: Bool) {
        if self.myp_canScroll {
            self.setContentOffset(CGPoint.zero, animated: animated)
        }
    }
    
    /**
     Sets the content offset to the bottom.
     
     animated: true to animate the transition at a constant velocity to the new offset, false to make the transition immediate.
     */
    func myp_scrollToBottom(animated: Bool) {
        if self.myp_canScroll {
            self.setContentOffset(self.myp_bottomRect.origin, animated: animated)
        }
    }
    
    /**
     Stops scrolling, if it was scrolling.
     */
    func myp_stopScrolling() {
        if !self.isDragging {
            return
        }
        var offset = self.contentOffset
        offset.y -= 1.0
        self.contentOffset = offset
        
        offset.y += 1.0
        self.contentOffset = offset
    }
    
    private var myp_canScroll: Bool {
        if self.contentSize.height > self.frame.height {
            return true
        }
        return false
    }
    
    private var myp_bottomRect: CGRect {
        return CGRect(x: 0.0, y: self.contentSize.height - self.bounds.height, width: self.bounds.width, height: self.bounds.height)
    }

}
