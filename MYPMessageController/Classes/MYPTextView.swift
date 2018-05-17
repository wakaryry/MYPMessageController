//
//  MYPTextView.swift
//  MYPTextInputVC
//
//  Created by wakary redou on 2018/4/23.
//  Copyright © 2018年 wakary redou. All rights reserved.
//

import UIKit

/** A custom text input view. */
public class MYPTextView: UITextView, MYPTextInput {
    /** The label used as placeholder */
    lazy private var placeholderLabel: UILabel = {
        let label = UILabel()
        label.clipsToBounds = false
        label.font = self.font
        label.numberOfLines = 1
        label.autoresizesSubviews = false
        label.backgroundColor = .clear
        label.textColor = .lightGray
        label.isHidden = true
        label.isAccessibilityElement = false
        
        self.addSubview(label)
        return label
    }()
    
    /** The placeholder text string. Default is nil. */
    var placeholder: String? {
        get {
            return self.placeholderLabel.text
        }
        set {
            self.placeholderLabel.text = newValue
            self.accessibilityLabel = newValue
            
            self.setNeedsLayout()
        }
    }
    
    /** The placeholder color. Default is lightGrayColor. */
    var placeholderColor: UIColor {
        get {
            return self.placeholderLabel.textColor
        }
        set {
            self.placeholderLabel.textColor = newValue
        }
    }
    
    /** The placeholder's number of lines. Default is 1. */
    var placeholderNumberOfLines: Int {
        get {
            return self.placeholderLabel.numberOfLines
        }
        set {
            self.placeholderLabel.numberOfLines = newValue
            
            self.setNeedsLayout()
        }
    }
    
    /** The placeholder's font. Default is the textView's font. */
    var placeholderFont: UIFont {
        get {
            return self.placeholderLabel.font
        }
        set {
            self.placeholderLabel.font = newValue
        }
    }
    
    /** The maximum number of lines before enabling scrolling. Default is 0 wich means limitless.
     If dynamic type is enabled, the maximum number of lines will be calculated proportionally to the user preferred font size. */
    var maxNumberOfLines: Int {
        get {
            var lines = self.maxNumberOfLinesCopy
            if MYP_IS_LANDSPACE {
                if MYP_IS_IPHONE {
                    lines = lines / 2
                }
            }
            
            if self.isDynamicTypeEnabled {
                let contentSizeCategory = UIApplication.shared.preferredContentSizeCategory
                let pointSizeDifference = MYPPointSizeDifferenceForCategory(contentSizeCategory)
                
                var factor = pointSizeDifference / self.initialFontSize!
                
                if fabs(factor) > 0.75 {
                    factor = 0.75
                }
                
                // Calculates a dynamic number of lines depending of the user preferred font size
                lines -= Int(floorf(Float(CGFloat(lines) * factor)))
            }
            
            return lines
        }
        set {
            maxNumberOfLinesCopy = newValue
        }
    }
    
    private var maxNumberOfLinesCopy = 0
    
    /** The current displayed number of lines. read-only*/
    var numberOfLines: Int {
        get {
            var aContentSize = self.contentSize
            
            // TODO: why the contentSize is so big when used only in textbarview
            // when init or first setting, the contentSize is very big. so we should use intrisincContentSize.
            // not to use the appropriate height, since the number of lines may not be correct firstly.
            //print("text view: contentSize: \(self.contentSize)")
            
            var contentHeight = aContentSize.height
            contentHeight = contentHeight - self.textContainerInset.top - self.textContainerInset.bottom
            
            var lines = Int(fabs(contentHeight / self.font!.lineHeight))
            
            // This helps preventing the content's height to be larger that the bounds' height
            // Avoiding this way to have unnecessary scrolling in the text view when there is only 1 line of content
            if lines == 1 && aContentSize.height > self.bounds.size.height {
                aContentSize.height = self.bounds.size.height
                self.contentSize = aContentSize
            }
            
            // Let's fallback to the minimum line count
            if (lines == 0) {
                lines = 1
            }
            
            return lines
        }
    }
    
    /** true if the text view is and can still expand it self, depending if the maximum number of lines are reached. */
    var isExpanding: Bool {
        if self.numberOfLines >= self.maxNumberOfLines {
            return true
        }
        return false
    }
    
    /** true if quickly refreshed the textview without the intension to dismiss the keyboard. @view -disableQuicktypeBar: for more details. */
    var didNotResignFirstResponder = false
    
    /** true if the keyboard track pad has been recognized. iOS 9 only. */
    private(set) var isTrackpadEnabled = false
    
    /** true if autocorrection and spell checking are enabled. On iOS8, this property also controls the predictive QuickType bar from being visible. Default is true. */
    var isTypingSuggestionEnabled: Bool {
        get {
            return self.autocorrectionType == .no ? false : true
        }
        set {
            if self.isTypingSuggestionEnabled == newValue {
                return
            }
            self.autocorrectionType = newValue ? UITextAutocorrectionType.default : .no
            self.spellCheckingType = newValue ? UITextSpellCheckingType.default : .no
            
            self.refreshFirstResponder()
        }
    }
    
    /** true if the text view supports undoing, either using UIMenuController, or with ctrl+z when using an external keyboard. Default is true. */
    var isUndoManagerEnabled: Bool = true {
        willSet {
            if self.isUndoManagerEnabled == newValue {
                return
            }
            
            self.undoManager?.levelsOfUndo = 10
            self.undoManager?.removeAllActions()
            self.undoManager?.setActionIsDiscardable(true)
        }
    }
    
    // MARK: - dynamic size
    // The initial font point size, used for dynamic type calculations
    private var initialFontSize: CGFloat?
    
    /** true if the font size should dynamically adapt based on the font sizing option preferred by the user. Default is false. */
    var isDynamicTypeEnabled: Bool = false {
        didSet {
            if self.isDynamicTypeEnabled == oldValue {
                return
            }
            
            let category = UIApplication.shared.preferredContentSizeCategory
            self.setFontMame((self.font?.fontName)!, pointSize: self.initialFontSize!, contentSizeCategory: category)
        }
    }
    
    //MARK: - External Keyboard Support
    override public var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand]? = nil
        if self.registeredKeyCommands.count > 0 {
            for command in self.registeredKeyCommands.values {
                commands?.append(command)
            }
        }
        return commands
    }
    
    // The keyboard commands available for external keyboards
    private var registeredKeyCommands = [String: UIKeyCommand]()
    private var registeredKeyCallbacks = [String: (UIKeyCommand)->()]()
    
    // Used for moving the caret up/down
    private var verticalMoveDirection: UITextLayoutDirection?
    private var verticalMoveStartCaretRect: CGRect?
    private var verticalMoveLastCaretRect: CGRect?
    
    // Used for detecting if the scroll indicator was previously flashed
    private var didFlashScrollIndicators: Bool = false
    
    //MARK: - Initialization
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        
        self.myp_commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.myp_commonInit()
    }
    
    init() {
        super.init(frame: .zero, textContainer: nil)
        
        self.myp_commonInit()
    }
    
    private func myp_commonInit() {
        self.isEditable = true
        self.isSelectable = true
        self.isScrollEnabled = true
        self.scrollsToTop = false
        self.isDirectionalLockEnabled = true
        // there has no UIDataDetectorTypeNone in swift
        self.dataDetectorTypes = UIDataDetectorTypes(rawValue: 0)
        
        self.myp_registerNotifications()
        
        self.addObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: contentSize)), options: NSKeyValueObservingOptions.new, context: nil)
    }
    
    //MARK: - UIView Overrides
    // read-only
    override public var intrinsicContentSize: CGSize {
        var height = self.font!.lineHeight
        height += self.textContainerInset.top + self.textContainerInset.bottom
        
        return CGSize(width: UIViewNoIntrinsicMetric, height: height)
    }
    
    /** used for dynamic height. changed when text line changed*/
    func myp_appropriateHeight() -> CGFloat {
        var height = self.textContainerInset.top + self.textContainerInset.bottom
        
        if self.maxNumberOfLines == 0 {
            // we should not use this height when `maxNumberOfLines == 0`
            height += self.font!.lineHeight * CGFloat(self.numberOfLines)
        }
        else {
            if self.maxNumberOfLines > self.numberOfLines {
                height += self.font!.lineHeight * CGFloat(self.numberOfLines)
            }
            else {
                height += self.font!.lineHeight * CGFloat(self.maxNumberOfLines)
            }
        }
        
        return height
    }
    
    override public class var requiresConstraintBasedLayout: Bool {
        return true
    }
    
    override public var contentOffset: CGPoint {
        get {
            return super.contentOffset
        }
        set {
            // At times during a layout pass, the content offset's x value may change.
            // Since we only care about vertical offset, let's override its horizontal value to avoid other layout issues.
            super.contentOffset = CGPoint(x: 0.0, y: newValue.y)
        }
    }
    
    override public func layoutIfNeeded() {
        if self.window == nil {
            return
        }
        super.layoutIfNeeded()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        self.placeholderLabel.isHidden = self.myp_shouldHidePlaceholder()
        
        if !self.placeholderLabel.isHidden {
            UIView.performWithoutAnimation {
                self.placeholderLabel.frame = self.myp_placeholderRectThatFits(self.bounds)
                self.sendSubview(toBack: self.placeholderLabel)
            }
        }
    }
    
    private func myp_shouldHidePlaceholder() -> Bool {
        if (self.placeholder?.count ?? 0) == 0 || self.text.count > 0 {
            return true
        }
        return false
    }
    
    private func myp_placeholderRectThatFits(_ rect: CGRect) -> CGRect {
        let padding = self.textContainer.lineFragmentPadding
        
        var aRect = CGRect.zero
        aRect.size.height = self.placeholderLabel.sizeThatFits(rect.size).height
        aRect.size.width = self.textContainer.size.width - padding * 2.0
        aRect.origin = UIEdgeInsetsInsetRect(rect, self.textContainerInset).origin
        aRect.origin.x += padding
        
        return aRect
    }
    
    //MARK: - UITextView Overrides
    override public var selectedRange: NSRange {
        get {
            return super.selectedRange
        }
        set {
            super.selectedRange = newValue
            
            NotificationCenter.default.post(name: Notification.Name.MYPTextInputTask.MYPTextViewSelectedRangeDidChangeNotification, object: self, userInfo: nil)
        }
    }
    
    override public var selectedTextRange: UITextRange? {
        get {
            return super.selectedTextRange
        }
        set {
            super.selectedTextRange = newValue
            
            NotificationCenter.default.post(name: Notification.Name.MYPTextInputTask.MYPTextViewSelectedRangeDidChangeNotification, object: self, userInfo: nil)
        }
    }
    
    override public var text: String! {
        get {
            return self.attributedText.string
        }
        set {
            // Registers for undo management
            self.myp_prepareForUndo(description: "Text Set")
            
            self.attributedText = self.myp_defaultAttributedString(for: newValue)
            
            NotificationCenter.default.post(name: NSNotification.Name.UITextViewTextDidChange, object: self)
        }
    }
    
    override public var attributedText: NSAttributedString! {
        get {
            return super.attributedText
        }
        set {
            self.myp_prepareForUndo(description: "Attributed Text Set")
            
            super.attributedText = newValue
            
            NotificationCenter.default.post(name: Notification.Name.UITextViewTextDidChange, object: self)
        }
    }
    
    override public var textAlignment: NSTextAlignment {
        get {
            return super.textAlignment
        }
        set {
            super.textAlignment = newValue
            
            // Updates the placeholder text alignment too
            self.placeholderLabel.textAlignment = newValue
        }
    }
    
    override public var font: UIFont? {
        get {
            return super.font
        }
        set {
            let category = UIApplication.shared.preferredContentSizeCategory
            self.setFontMame((newValue?.fontName)!, pointSize: (newValue?.pointSize)!, contentSizeCategory: category)
            self.initialFontSize = font?.pointSize
        }
    }
    
    private func setFontMame(_ fontName: String, pointSize: CGFloat, contentSizeCategory: UIContentSizeCategory) {
        var aPointSize = pointSize
        if self.isDynamicTypeEnabled {
            aPointSize += MYPPointSizeDifferenceForCategory(contentSizeCategory)
        }
        let dynamicFont = UIFont(name: fontName, size: aPointSize)
        super.font = dynamicFont
        // Updates the placeholder font too
        self.placeholderLabel.font = dynamicFont
    }
    
    //MARK: - UITextInput Overrides
    override public func beginFloatingCursor(at point: CGPoint) {
        super.beginFloatingCursor(at: point)
        self.isTrackpadEnabled = true
    }
    
    override public func updateFloatingCursor(at point: CGPoint) {
        super.updateFloatingCursor(at: point)
    }
    
    override public func endFloatingCursor() {
        super.endFloatingCursor()
        self.isTrackpadEnabled = false
        
        // We still need to notify a selection change in the textview after the trackpad is disabled
        if let xDelegate = self.delegate {
            if xDelegate.responds(to: #selector(UITextViewDelegate.textViewDidChangeSelection(_:))) {
                xDelegate.textViewDidChangeSelection!(self)
            }
        }
        
        NotificationCenter.default.post(name: Notification.Name.MYPTextInputTask.MYPTextViewSelectedRangeDidChangeNotification, object: self, userInfo: nil)
    }
    
    //MARK: - refresh inputView
    /**
     Some text view properties don't update when it's already firstResponder (auto-correction, spelling-check, etc.)
     To be able to update the text view while still being first responder, requieres to switch quickly from -resignFirstResponder to -becomeFirstResponder.
     When doing so, the flag 'didNotResignFirstResponder' is momentarly set to true before it goes back to -isFirstResponder, to be able to prevent some tasks to be excuted because of UIKeyboard notifications.
     
     You can also use this method to confirm an auto-correction programatically, before the text view resigns first responder.
     */
    func refreshFirstResponder() {
        if !self.isFirstResponder {
            return
        }
        
        self.didNotResignFirstResponder = true
        let _ = self.resignFirstResponder()
        
        self.didNotResignFirstResponder = false
        let _ = self.becomeFirstResponder()
    }
    
    func refreshInputViews() {
        self.didNotResignFirstResponder = true
        super.reloadInputViews()
        self.didNotResignFirstResponder = false
    }
    
    internal var becomeFirstResponderCallback: (() -> Void)?
    internal var resignFirstResponderCallback: (() -> Void)?
    
    //MARK: - UIResponder Overrides
    override public var canBecomeFirstResponder: Bool {
        self.myp_addCustomMenuControllerItems()
        return super.canBecomeFirstResponder
    }
    
    override public func becomeFirstResponder() -> Bool {
        if let x = becomeFirstResponderCallback {
            x()
        }
        return super.becomeFirstResponder()
    }
    
    override public var canResignFirstResponder: Bool {
        // Removes undo/redo items
        if self.isUndoManagerEnabled {
            self.undoManager?.removeAllActions()
        }
        return super.canResignFirstResponder
    }
    
    override public func resignFirstResponder() -> Bool {
        if let x = resignFirstResponderCallback {
            x()
        }
        return super.resignFirstResponder()
    }
    
    // MARK: - MenuController
    override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(delete(_:)) {
            return false
        }
        if action == #selector(paste(_:)) && self.myp_pastedItem() != nil {
            return true
        }
        
        if self.isUndoManagerEnabled {
            if action == #selector(myp_undo(_:)) {
                if self.undoManager!.undoActionIsDiscardable {
                    return false
                }
                return self.undoManager!.canUndo
            }
            if action == #selector(myp_redo(_:)) {
                if self.undoManager!.redoActionIsDiscardable {
                    return false
                }
                return self.undoManager!.canRedo
            }
        }
        
        return super.canPerformAction(action, withSender: sender)
    }
    
    override public func paste(_ sender: Any?) {
        let pastedItem = self.myp_pastedItem()
        
        if let s = pastedItem {
            if let x = self.delegate {
                if x.responds(to: #selector(UITextViewDelegate.textView(_:shouldChangeTextIn:replacementText:))) {
                    if !x.textView!(self, shouldChangeTextIn: self.selectedRange, replacementText: s) {
                        return
                    }
                }
            }
            // Inserting the text fixes a UITextView bug whitch automatically scrolls to the bottom
            // and beyond scroll content size sometimes when the text is too long
            self.myp_insertTextAtCaretRange(text: s)
        }
    }
    
    private func myp_pastedItem() -> String? {
        if UIPasteboard.general.hasURLs {
            return UIPasteboard.general.url?.absoluteString
        }
        
        if UIPasteboard.general.hasStrings {
            return UIPasteboard.general.string
        }
        return nil
    }
    
    private func myp_addCustomMenuControllerItems() {
        let undo = UIMenuItem(title: NSLocalizedString("undo", comment: "撤销") , action: #selector(myp_undo(_:)))
        let redo = UIMenuItem(title: NSLocalizedString("redo", comment: "重做"), action: #selector(myp_redo(_:)))
        
        let items = [undo, redo]
        
        UIMenuController.shared.menuItems = items
    }
    
    @objc private func myp_undo(_ sender: Any) {
        self.undoManager?.undo()
    }
    
    @objc private func myp_redo(_ sender: Any) {
        self.undoManager?.redo()
    }
    
    private func myp_flashScrollIndicatorsIfNeeded() {
        if self.numberOfLines == self.maxNumberOfLines + 1 {
            if !self.didFlashScrollIndicators {
                self.didFlashScrollIndicators = true
                super.flashScrollIndicators()
            }
        } else if self.didFlashScrollIndicators {
            self.didFlashScrollIndicators = false
        }
    }
    
    /**
     Registers and observes key commands' updates, when the text view is first responder.
     Instead of typically overriding UIResponder's -keyCommands method, it is better to use this API for easier and safer implementation of key input detection.
     
     @param input The keys that must be pressed by the user. Required.
     @param modifiers The bit mask of modifier keys that must be pressed. Use 0 if none.
     @param title The title to display to the user. Optional.
     @param completion A completion block called whenever the key combination is detected. Required.
     */
    func observe(keyInput input: String, modifiers: UIKeyModifierFlags, title: String?, completion: @escaping (_ keyCommand: UIKeyCommand) -> Void) {
        let keyCommand = UIKeyCommand(input: input, modifierFlags: modifiers, action: #selector(didDetectKeyCommand(_:)))
        
        keyCommand.discoverabilityTitle = title
        let key = self.key(forKeyCommand: keyCommand)
        self.registeredKeyCommands[key] = keyCommand
        self.registeredKeyCallbacks[key] = completion
    }
    
    @objc
    private func didDetectKeyCommand(_ keyCommand: UIKeyCommand) {
        let key = self.key(forKeyCommand: keyCommand)
        let completion = self.registeredKeyCallbacks[key]
        if completion != nil {
            completion!(keyCommand)
        }
    }
    
    private func key(forKeyCommand keyCommand: UIKeyCommand) -> String {
        return "\(keyCommand.input!)_\(keyCommand.modifierFlags)"
    }
    
    //MARK: - Up/Down Cursor Movement
    /**
     Notifies the text view that the user pressed any arrow key. This is used to move the cursor up and down while having multiple lines.
     */
    func didPressArrowKey(_ keyCommand: UIKeyCommand) {
        if self.text.count == 0 || self.numberOfLines < 2 {
            return
        }
        
        if keyCommand.input == UIKeyInputUpArrow {
            self.myp_moveCursorToDirection(UITextLayoutDirection.up)
        }
        else if (keyCommand.input == UIKeyInputDownArrow) {
            self.myp_moveCursorToDirection(.down)
        }
    }
    
    private func myp_moveCursorToDirection(_ direction: UITextLayoutDirection) {
        let start = direction == UITextLayoutDirection.up ? self.selectedTextRange?.start : self.selectedTextRange?.end
        
        if self.myp_isNewVerticalMovement(ForPosition: start!, in: direction) {
            self.verticalMoveDirection = direction
            self.verticalMoveStartCaretRect = self.caretRect(for: start!)
        }
        
        if start != nil {
            let end = self.myp_closestPositionTo(position: start!, in: direction)
            if let x = end {
                self.verticalMoveLastCaretRect = self.caretRect(for: x)
                self.selectedTextRange = self.textRange(from: x, to: x)
                self.myp_scrollToCaretPosition(animated: false)
            }
        }
    }
    
    private func myp_isNewVerticalMovement(ForPosition position: UITextPosition, in direction: UITextLayoutDirection) -> Bool {
        let caretRect = self.caretRect(for: position)
        let noPreviousStartPosition = self.verticalMoveStartCaretRect == CGRect.zero
        let caretMovedSinceLastPosition = !(caretRect == self.verticalMoveLastCaretRect)
        let directionChanged = self.verticalMoveDirection != direction
        let newMovement = noPreviousStartPosition || caretMovedSinceLastPosition || directionChanged
        return newMovement
    }
    
    private func myp_closestPositionTo(position: UITextPosition, in direction: UITextLayoutDirection) -> UITextPosition? {
        // Only up/down are implemented. No real need for left/right since that is native to UITextInput.
        assert(direction == .up || direction == .down, "only up and down direction")
        
        // Translate the vertical direction to a horizontal direction.
        let lookupDirection = direction == .up ? UITextLayoutDirection.left : UITextLayoutDirection.right
        
        // Walk one character at a time in `lookupDirection` until the next line is reached.
        var checkPosition = position
        var closestPosition = position
        let startingCaretRect = self.caretRect(for: position)
        var nextLineCaretRect = CGRect.zero
        var isInNextLine = false
        
        while true {
            let nextPosition = self.position(from: checkPosition, in: lookupDirection, offset: 1)
            if nextPosition == nil || self.compare(checkPosition, to: nextPosition!) == ComparisonResult.orderedSame {
                break
            }
            
            checkPosition = nextPosition!
            let checkRect = self.caretRect(for: checkPosition)
            if startingCaretRect.midY != checkRect.midY {
                // While on the next line stop just above/below the starting position.
                if lookupDirection == UITextLayoutDirection.left && checkRect.midX <= self.verticalMoveStartCaretRect!.midX {
                    closestPosition = checkPosition
                    break
                }
                if lookupDirection == .right && checkRect.midX >= self.verticalMoveStartCaretRect!.midX {
                    closestPosition = checkPosition
                    break
                }
                if isInNextLine && checkRect.midY != nextLineCaretRect.midY {
                    break
                }
                
                isInNextLine = true
                nextLineCaretRect = checkRect
                closestPosition = checkPosition
            }
        }
        
        return closestPosition
    }
    
    //MARK: - KVO Listener
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if object is MYPTextView {
            if (object as! MYPTextView) == self && keyPath == NSStringFromSelector(#selector(getter: contentSize)) {
                NotificationCenter.default.post(name: Notification.Name.MYPTextInputTask.MYPTextViewContentSizeDidChangeNotification, object: self, userInfo: nil)
                return
            }
        }
        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
    
    //MARK: - Motion Events
    override public func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if event?.type == UIEventType.motion && event?.subtype == UIEventSubtype.motionShake {
            NotificationCenter.default.post(name: Notification.Name.MYPTextInputTask.MYPTextViewDidShakeNotification, object: self)
        }
    }
    
    //MARK: - Notification regist
    private func myp_registerNotifications() {
        self.myp_unregisterNotifications()
        
        NotificationCenter.default.addObserver(self, selector: #selector(myp_didBeginEditing(notification:)), name: Notification.Name.UITextViewTextDidBeginEditing, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(myp_didChangeText(notification:)), name: Notification.Name.UITextViewTextDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(myp_didEndEditing(notification:)), name: Notification.Name.UITextViewTextDidEndEditing, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(myp_didChangeTextInputMode(notification:)), name: Notification.Name.UITextInputCurrentInputModeDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(myp_didChangeContentSizeCategory(notification:)), name: Notification.Name.UIContentSizeCategoryDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(myp_willShowMenuController(notification:)), name: Notification.Name.UIMenuControllerWillShowMenu, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(myp_didHideMenuController(notification:)), name: Notification.Name.UIMenuControllerDidHideMenu, object: nil)
    }
    
    private func myp_unregisterNotifications() {
        NotificationCenter.default.removeObserver(self, name: .UITextViewTextDidBeginEditing, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UITextViewTextDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UITextViewTextDidEndEditing, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UITextInputCurrentInputModeDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIContentSizeCategoryDidChange, object: nil)
    }
    
    //MARK: - Notification Events
    @objc private func myp_didBeginEditing(notification: Notification) {
        if !self.isNotificationObjectSelf(notification) {
            return
        }
        // do something
    }
    
    @objc private func myp_didChangeText(notification: Notification) {
        if !self.isNotificationObjectSelf(notification) {
            return
        }
        
        if self.placeholderLabel.isHidden != self.myp_shouldHidePlaceholder() {
            self.setNeedsLayout()
        }
        
        self.myp_flashScrollIndicatorsIfNeeded()
    }
    
    @objc private func myp_didEndEditing(notification: Notification) {
        if !self.isNotificationObjectSelf(notification) {
            return
        }
        // do some
    }
    
    @objc private func myp_didChangeTextInputMode(notification: Notification) {
        // do some
    }
    
    @objc private func myp_didChangeContentSizeCategory(notification: Notification) {
        if !self.isDynamicTypeEnabled {
            return
        }
        let category = notification.userInfo![UIContentSizeCategoryNewValueKey]
        self.setFontMame((self.font?.fontName)!, pointSize: self.initialFontSize!, contentSizeCategory: category as! UIContentSizeCategory)
        
        let aText = self.text
        self.text = ""
        self.text = aText
    }
    
    @objc private func myp_willShowMenuController(notification: Notification) {
        // do some
    }
    
    @objc private func myp_didHideMenuController(notification: Notification) {
        self.myp_addCustomMenuControllerItems()
    }
    
    private func isNotificationObjectSelf(_ notification: Notification) -> Bool {
        if notification.object is MYPTextView {
            if (notification.object as! MYPTextView) == self {
                return true
            }
        }
        return false
    }
    
    //MARK: - deinit
    deinit {
        self.myp_unregisterNotifications()
        self.removeObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: contentSize)))
    }
    
}
