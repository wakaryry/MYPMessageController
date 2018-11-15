//
//  UIView+MYPAddition.swift
//  MYPTextInputVC
//
//  Created by wakary redou on 2018/5/2.
//  Copyright © 2018年 wakary redou. All rights reserved.
//

import UIKit

/** UIView additional features used for MYPTextViewController. */
extension UIView {
    
    /**
     Animates the view's constraints by calling layoutIfNeeded.
     
     - Parameters:
         - bounce: true if the animation should use spring damping and velocity to give a bouncy effect to animations.
         - options: A mask of options indicating how you want to perform the animations.
         - animations: An additional block for custom animations.
     */
    func myp_animateLayoutIfNeeded(withBounce bounce: Bool, options: UIView.AnimationOptions, animations: (() -> Void)?) {
        self.myp_animateLayoutIfNeeded(withBounce: bounce, options: options, animations: animations, completion: nil)
    }
    
    func myp_animateLayoutIfNeeded(withBounce bounce: Bool, options: UIView.AnimationOptions, animations: (() -> Void)?, completion: ((_ finished: Bool) -> Void)?) {
        let duration: TimeInterval = bounce ? 0.65 : 0.2
        self.myp_animateLayoutIfNeeded(withDuration: duration, bounce: bounce, options: options, animations: animations, completion: completion)
    }
    
    /**
     Animates the view's constraints by calling layoutIfNeeded.
     
     - Parameters:
         - duration: The total duration of the animations, measured in seconds.
         - bounce: true if the animation should use spring damping and velocity to give a bouncy effect to animations.
         - options: A mask of options indicating how you want to perform the animations.
         - animations: An additional block for custom animations.
     */
    func myp_animateLayoutIfNeeded(withDuration duration: TimeInterval, bounce: Bool, options: UIView.AnimationOptions, animations: (() -> Void)?, completion: ((_ finished: Bool) -> Void)?) {
        if bounce {
            UIView.animate(withDuration: duration, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.7, options: options, animations: {
                self.layoutIfNeeded()
                if let a = animations {
                    a()
                }
            }, completion: completion)
        }
        else {
            UIView.animate(withDuration: duration, delay: 0.0, options: options, animations: {
                self.layoutIfNeeded()
                if let a = animations {
                    a()
                }
            }, completion: completion)
        }
    }
    
    /**
     Returns the view constraints matching a specific layout attribute (top, bottom, left, right, leading, trailing, etc.)
     
     - Parameters:
         -attribute: The layout attribute to use for searching.
     - Returns: An array of matching constraints.
     */
    func myp_constraints(for attribute: NSLayoutConstraint.Attribute) -> [NSLayoutConstraint]? {
        return self.constraints.filter({ (constraint) -> Bool in
            return constraint.firstAttribute == attribute
        })
        /*
        // = or ==, the same
        let predicate = NSPredicate(format: "firstAttribute == %d", attribute.rawValue)
        return self.constraints.filter({ (constraint) -> Bool in
            return predicate.evaluate(with: constraint)
        })
        */
    }
    
    /**
     Returns a layout constraint matching a specific layout attribute and relationship between 2 items, first and second items.
     
     - Parameters:
         - attribute: The layout attribute to use for searching.
         - first: The first item in the relationship.
         - second: The second item in the relationship.
     - Returns: A layout constraint.
     */
    func myp_constraint(for attribute: NSLayoutConstraint.Attribute, firstItem first: Any?, secondItem second: Any?) -> NSLayoutConstraint? {
        // as! UIView
        return self.constraints.filter({ (constraint) -> Bool in
            return constraint.firstAttribute == attribute && (constraint.firstItem as? UIView) == (first as? UIView) && (constraint.secondItem as? UIView) == (second as? UIView)
        }).first
    }
}
