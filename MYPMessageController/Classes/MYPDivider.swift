//
//  MYPDivider.swift
//  MYPMessageController
//
//  Created by wakary redou on 2018/5/17.
//

import UIKit

@objc(DividerAlignment)
public enum DividerAlignment: Int {
    case top
    case left
    case bottom
    case right
}

public struct Divider {
    /// A reference to the UIView.
    internal weak var view: UIView?
    
    /// A reference to the divider UIView.
    internal var line: UIView?
    
    /// A reference to the height.
    public var thickness: CGFloat {
        didSet {
            reload()
        }
    }
    
    /// A preset wrapper around contentEdgeInsets.
    public var contentEdgeInsetsPreset = EdgeInsetsPreset.none {
        didSet {
            contentEdgeInsets = EdgeInsetsPresetToValue(preset: contentEdgeInsetsPreset)
        }
    }
    
    /// A reference to EdgeInsets.
    public var contentEdgeInsets = EdgeInsets.zero {
        didSet {
            reload()
        }
    }
    
    /// A UIColor.
    public var color: UIColor? {
        get {
            return line?.backgroundColor
        }
        set(value) {
            guard let v = value else {
                line?.removeFromSuperview()
                line = nil
                return
            }
            if nil == line {
                line = UIView()
                line?.layer.zPosition = 5000
                view?.addSubview(line!)
                reload()
            }
            line?.backgroundColor = v
        }
    }
    
    /// A reference to the dividerAlignment.
    public var alignment = DividerAlignment.bottom {
        didSet {
            reload()
        }
    }
    
    /**
     Initializer that takes in a UIView.
     - Parameter view: A UIView reference.
     - Parameter thickness: A CGFloat value.
     */
    internal init(view: UIView?, thickness: CGFloat = 1) {
        self.view = view
        self.thickness = thickness
    }
    
    /**
     Hides the divier line.
     */
    internal var isHidden = false {
        didSet {
            line?.isHidden = isHidden
        }
    }
    
    /// Lays out the divider.
    public func reload() {
        guard let l = line, let v = view else {
            return
        }
        
        let c = contentEdgeInsets
        
        switch alignment {
        case .top:
            l.frame = CGRect(x: c.left, y: c.top, width: v.bounds.width - c.left - c.right, height: thickness)
        case .bottom:
            l.frame = CGRect(x: c.left, y: v.bounds.height - thickness - c.bottom, width: v.bounds.width - c.left - c.right, height: thickness)
        case .left:
            l.frame = CGRect(x: c.left, y: c.top, width: thickness, height: v.bounds.height - c.top - c.bottom)
        case .right:
            l.frame = CGRect(x: v.bounds.width - thickness - c.right, y: c.top, width: thickness, height: v.bounds.height - c.top - c.bottom)
        }
    }
}

/// A memory reference to the Divider instance.
fileprivate var DividerKey: UInt8 = 0

extension UIView {
    /// TabBarItem reference.
    public private(set) var divider: Divider {
        get {
            return AssociatedObject.get(base: self, key: &DividerKey) {
                return Divider(view: self)
            }
        }
        set(value) {
            AssociatedObject.set(base: self, key: &DividerKey, value: value)
        }
    }
    
    /// A preset wrapper around divider.contentEdgeInsets.
    open var dividerContentEdgeInsetsPreset: EdgeInsetsPreset {
        get {
            return divider.contentEdgeInsetsPreset
        }
        set(value) {
            divider.contentEdgeInsetsPreset = value
        }
    }
    
    /// A reference to divider.contentEdgeInsets.
    open var dividerContentEdgeInsets: EdgeInsets {
        get {
            return divider.contentEdgeInsets
        }
        set(value) {
            divider.contentEdgeInsets = value
        }
    }
    
    /// Divider color.
    @IBInspectable
    open var dividerColor: UIColor? {
        get {
            return divider.color
        }
        set(value) {
            divider.color = value
        }
    }
    
    /// Divider visibility.
    @IBInspectable
    open var isDividerHidden: Bool {
        get {
            return divider.isHidden
        }
        set(value) {
            divider.isHidden = value
        }
    }
    
    /// Divider animation.
    open var dividerAlignment: DividerAlignment {
        get {
            return divider.alignment
        }
        set(value) {
            divider.alignment = value
        }
    }
    
    /// Divider thickness.
    @IBInspectable
    open var dividerThickness: CGFloat {
        get {
            return divider.thickness
        }
        set(value) {
            divider.thickness = value
        }
    }
    
    /// Sets the divider frame.
    open func layoutDivider() {
        divider.reload()
    }
}
