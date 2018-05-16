//
//  MYPMessageController.swift
//  MYPTextInputVC
//
//  Created by wakary redou on 2018/5/4.
//  Copyright © 2018年 wakary redou. All rights reserved.
//

import UIKit

fileprivate let MYPBottomPanningEnabled = false

open class MYPMessageController: UIViewController, UITextViewDelegate, UIGestureRecognizerDelegate {
    
    /** read-only. The main table view managed by the controller object. Created by default initializing with -init or initWithNibName:bundle: */
    open private(set) var tableView: UITableView?
    
    /** read-only. The main collection view managed by the controller object. Not nil if the controller is initialised with -initWithCollectionViewLayout: */
    open private(set) var collectionView: UICollectionView?
    
    /** read-only. The main scroll view managed by the controller object. Not nil if the controller is initialised with -initWithScrollView: */
    open private(set) var scrollView: UIScrollView?
    
    /** read-only. The inputbar view containing a text view and buttons. */
    open var textInputbar: MYPTextInputbarView {
        // we could use a helper to make it read-only.
        // or use private(set) with no helper to make it read-only
        get {
            return self.textInputbarHelper
        }
    }
    
    lazy private var textInputbarHelper: MYPTextInputbarView = {
        let bar = MYPTextInputbarView(frame: .zero)
        
        bar.leftButton.addTarget(self, action: #selector(didPressLeftButton(sender:)), for: .touchUpInside)
        bar.rightButton.addTarget(self, action: #selector(didPressRightButton(sender:)), for: .touchUpInside)
        bar.rightMoreButton.addTarget(self, action: #selector(didPressRightMoreButton(sender:)), for: .touchUpInside)
        bar.sendButton.addTarget(self, action: #selector(didPressSendButton(sender:)), for: .touchUpInside)
        
        bar.textView.delegate = self
        
        bar.addGestureRecognizer(self.verticalPanGesture)
        
        return bar
    }()
    
    /** read-only. A single tap gesture used to dismiss the keyboard. MYPMessageController is its delegate. */
    lazy private(set) var singleTapGesture: UIGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(myp_didTapScrollView))
        tap.delegate = self
        tap.require(toFail: self.scrollViewProxy!.panGestureRecognizer)
        
        return tap
    }()
    
    /** A vertical pan gesture used for bringing the keyboard from the bottom. MYPMessageController is its delegate. */
    var verticalPanGesture: UIPanGestureRecognizer {
        return self.verticalPanGestureHelper
    }
    
    lazy private var verticalPanGestureHelper: UIPanGestureRecognizer = {
        let vPan = UIPanGestureRecognizer(target: self, action: #selector(myp_didPanTextInputBar(recognizer:)))
        vPan.delegate = self
        
        return vPan
    }()
    
    /** true if animations should have bouncy effects. Default is true. */
    open var bounces = true {
        didSet {
            self.textInputbar.bounces = self.bounces
        }
    }
    
    /** true if text view's content can be cleaned with a shake gesture. Default is false. */
    open var isShakeToClearEnabled = false
    
    /**
     true if keyboard can be dismissed gradually with a vertical panning gesture. Default is true.
     
     This feature doesn't work on iOS 9 due to no legit alternatives to detect the keyboard view.
     Open Radar: http://openradar.appspot.com/radar?id=5021485877952512
     */
    open var isKeyboardPanningEnabled = true
    
    /** true if an external keyboard has been detected (this value updates only when the text view becomes first responder). */
    open private(set) var isExternalKeyboardDetected = false
    
    /** true if the keyboard has been detected as undocked or split (iPad Only). */
    open private(set) var isKeyboardUndocked = false
    
    /** true if after send button press, the text view is cleared out. Default is true. */
    open var shouldClearTextAtSendButtonPress = true
    
    /** true if the scrollView should scroll to bottom when the keyboard is shown. Default is false.*/
    open var shouldScrollToBottomAfterKeyboardShows = false
    
    /**
     true if the main table view is inverted. Default is true.
     This allows the table view to start from the bottom like any typical messaging interface.
     If inverted, you must assign the same transform property to your cells to match the orientation (ie: cell.transform = tableView.transform;)
     Inverting the table view will enable some great features such as content offset corrections automatically when resizing the text input and/or showing autocompletion.
     */
    open var isInverted = true {
        didSet {
            if self.isInverted == oldValue {
                return
            }
            self.myp_updateInsetAdjustmentBehavior()
            
            self.scrollViewProxy!.transform = self.isInverted ? CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0) : CGAffineTransform.identity
        }
    }
    
    /** true if the view controller is presented inside of a popover controller.
     If true, the keyboard won't move the text input bar and tapping on the tableView/collectionView will not cause the keyboard to be dismissed.
     This property is compatible only with iPad. */
    open var isPresentedInPopover: Bool {
        return self.isPresentedInPopoverHepler && MYP_IS_IPAD
    }
    
    private var isPresentedInPopoverHepler = false
    
    /** The current keyboard status (will/did hide, will/did show) */
    open private(set) var keyboardStatus: MYPKeyboardStatus?
    
    /** Convenience accessors (accessed through the text input bar) */
    open var textView: MYPTextView {
        return self.textInputbar.textView
    }
    open var leftButton: UIButton {
        return self.textInputbar.leftButton
    }
    open var rightButton: UIButton {
        return self.textInputbar.rightButton
    }
    open var rightMoreButton: UIButton {
        return self.textInputbar.rightMoreButton
    }
    open var sendButton: UIButton {
        return self.textInputbar.sendButton
    }
    open var text: String {
        return self.textInputbar.textView.text
    }
    open var attributedText: NSAttributedString {
        return self.textInputbar.textView.attributedText
    }
    
    // The shared scrollView pointer, either a tableView or collectionView
    internal weak var scrollViewProxy: UIScrollView?
    
    private var scrollViewOffsetBeforeDragging: CGPoint = CGPoint.zero
    private var keyboardHeightBeforeDragging: CGFloat = 0
    
    // A hairline displayed on top of the auto-completion view, to better separate the content from the control.
    lazy private var autoCompletionHairline: UIView = {
        var rect = CGRect.zero
        rect.size = CGSize(width: self.view.frame.width, height: 0.5)
        let hairline = UIView(frame: rect)
        hairline.autoresizingMask = UIViewAutoresizing.flexibleWidth
        
        return hairline
    }()
    
    // Auto-Layout height constraints used for updating their constants
    internal var scrollViewHeightC: NSLayoutConstraint = NSLayoutConstraint()
    internal var textInputbarHeightC: NSLayoutConstraint = NSLayoutConstraint()
    internal var autoCompletionViewHeightC: NSLayoutConstraint = NSLayoutConstraint()
    internal var keyboardHeightC: NSLayoutConstraint = NSLayoutConstraint()
    
    /** true if the user is moving the keyboard with a gesture */
    private var isMovingKeyboard = false
    
    /** true if the view controller did appear and everything is finished configurating.
       This allows blocking some layout animations among other things. */
    internal var isViewVisible = false
    
    /** true if the view controller's view's size is changing by its parent (i.e. when its window rotates or is resized) */
    internal var isTransitioning = false
    
    override open var modalPresentationStyle: UIModalPresentationStyle {
        get {
            if let x = self.navigationController {
                return x.modalPresentationStyle
            }
            return super.modalPresentationStyle
        }
        set {
            if let x = self.navigationController {
                x.modalPresentationStyle = newValue
                return
            }
            super.modalPresentationStyle = newValue
        }
    }
    
    private func myp_updateInsetAdjustmentBehavior() {
        // Deactivate automatic scrollView adjustment for inverted table view
        if #available(iOS 11.0, *) {
            if self.isInverted {
                self.tableView?.contentInsetAdjustmentBehavior = .never
            }
            else {
                self.tableView?.contentInsetAdjustmentBehavior = .automatic
            }
        }
    }
    
    internal func myp_appropriateKeyboardHeight(from notification: Notification) -> CGFloat {
        // Let's first detect keyboard special states such as external keyboard, undocked or split layouts.
        self.myp_detectKeyboardStates(in: notification)
        
        if self.ignoreTextInputbarAdjustment() {
            return self.myp_appropriateBottomMargin()
        }
        
        let keyboardRect = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue
        
        return self.myp_appropriateKeyboardHeight(from: keyboardRect!)
    }
    
    internal func myp_appropriateKeyboardHeight(from rect: CGRect) -> CGFloat {
        let keyboardRect = self.view.convert(rect, from: nil)
        
        let viewHeight = self.view.bounds.height
        let keyboardMinY = keyboardRect.minY
        
        var keyboardHeight = max(0.0, viewHeight - keyboardMinY)
        let bottomMargin = self.myp_appropriateBottomMargin()
        
        // When the keyboard height is zero, we can assume there is no keyboard visible
        // In that case, let's see if there are any other views outside of the view hiearchy
        // requiring to adjust the text input bottom margin
        if (keyboardHeight < bottomMargin) {
            keyboardHeight = bottomMargin
        }
        
        return keyboardHeight
    }
    
    private func myp_detectKeyboardStates(in notification: Notification) {
        // tear down
        self.isExternalKeyboardDetected = false
        self.isKeyboardUndocked = false
        
        if self.isMovingKeyboard {
            return
        }
        
        // Based on http://stackoverflow.com/a/5760910/287403
        // We can determine if the external keyboard is showing by adding the origin.y of the target finish rect (end when showing, begin when hiding) to the inputAccessoryHeight.
        // If it's greater(or equal) the window height, it's an external keyboard.
        let beginRect = (notification.userInfo![UIKeyboardFrameBeginUserInfoKey] as AnyObject).cgRectValue!
        let endRect = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue!
        
        // Grab the base view for conversions as we don't want window coordinates in < iOS 8
        // iOS 8 fixes the whole coordinate system issue for us, but iOS 7 doesn't rotate the app window coordinate space.
        let baseView = self.view.window?.rootViewController?.view
        
        let screenBounds = UIScreen.main.bounds
        
        // Convert the main screen bounds into the correct coordinate space but ignore the origin.
        var viewBounds = self.view.convert(MYPKeyWindowBounds!, from: nil)
        viewBounds = CGRect(x: 0.0, y: 0.0, width: viewBounds.width, height: viewBounds.height)
        
        // We want these rects in the correct coordinate space as well.
        let convertBegin = baseView?.convert(beginRect, from: nil)
        let convertEnd = baseView?.convert(endRect, from: nil)
        
        if notification.name == .UIKeyboardWillShow {
            if convertEnd!.origin.y >= viewBounds.size.height {
                self.isExternalKeyboardDetected = true
            }
        }
        else if notification.name == .UIKeyboardWillHide {
            // The additional logic check here (== to width) accounts for a glitch (iOS 8 only?) where the window has rotated it's coordinates
            // but the beginRect doesn't yet reflect that. It should never cause a false positive.
            if convertBegin!.origin.y >= viewBounds.size.height || convertBegin!.origin.y == viewBounds.size.height {
                self.isExternalKeyboardDetected = true
            }
        }
        
        if MYP_IS_IPAD && convertEnd!.maxY < screenBounds.maxY {
            // The keyboard is undocked or split (iPad Only)
            self.isKeyboardUndocked = true
            
            self.isExternalKeyboardDetected = false
        }
    }
    
    internal func myp_appropriateBottomMargin() -> CGFloat {
        // A bottom margin is required if the view is extended out of it bounds
        if (self.edgesForExtendedLayout.rawValue & UIRectEdge.bottom.rawValue) > 0 {
            let tabbar = self.tabBarController?.tabBar
            
            if tabbar != nil && !tabbar!.isHidden && !self.hidesBottomBarWhenPushed {
                return tabbar!.frame.height
            }
        }
        
        // A bottom margin is required for iPhone X
        if #available(iOS 11.0, *) {
            if (!self.textInputbar.isHidden) {
                return self.view.safeAreaInsets.bottom
            }
        }
        
        return 0.0
    }
    
    internal func myp_appropriateScrollViewHeight() -> CGFloat {
        var scrollHeight = self.view.bounds.height
        scrollHeight -= self.keyboardHeightC.constant
        scrollHeight -= self.textInputbarHeightC.constant
        scrollHeight -= self.autoCompletionViewHeightC.constant
        
        if scrollHeight < 0 {
            return 0.0
        }
        
        return scrollHeight
    }
    
    internal func myp_topBarsHeight() -> CGFloat {
        // No need to adjust if the edge isn't available
        if self.edgesForExtendedLayout.rawValue & UIRectEdge.top.rawValue == 0 {
            return 0.0
        }
        
        var topBarsHeight = self.navigationController?.navigationBar.frame.height ?? 0.0
        
        if (MYP_IS_IPHONE && MYP_IS_LANDSPACE) || (MYP_IS_IPAD && self.modalPresentationStyle == .formSheet) || self.isPresentedInPopover {
            return topBarsHeight
        }
        
        topBarsHeight += UIApplication.shared.statusBarFrame.height
        
        return topBarsHeight
    }
    
    private func myp_keyboardStatus(for notification: Notification) -> MYPKeyboardStatus? {
        
        if notification.name == .UIKeyboardWillShow {
            return .willShow
        }
        if notification.name == .UIKeyboardWillHide {
            return .willHide
        }
        if notification.name == .UIKeyboardDidShow {
            return .didShow
        }
        if notification.name == .UIKeyboardDidHide {
            return .didHide
        }
        
        return nil
    }
    
    private func myp_isIllogicalKeyboardStatus(_ newStatus: MYPKeyboardStatus) -> Bool {
        if self.keyboardStatus == .didHide && newStatus == .willShow {
            return false
        }
        if self.keyboardStatus == .willShow && newStatus == .didShow {
            return false
        }
        if self.keyboardStatus == .didShow && newStatus == .willHide {
            return false
        }
        if self.keyboardStatus == .willHide && newStatus == .didHide {
            return false
        }
        return true
    }
    
    private func myp_updateKeyboardStatus(_ status: MYPKeyboardStatus) -> Bool {
        // Skips if trying to update the same status
        if self.keyboardStatus == status {
            return false
        }
        
        // Skips illogical conditions
        // Forces the keyboard status when didHide to avoid any inconsistency.
        if status != .didHide && self.myp_isIllogicalKeyboardStatus(status) {
            return false
        }
        
        self.keyboardStatus = status
        
        self.keyboardDidChange(status: status)
        
        return true
    }
    
    override open var edgesForExtendedLayout: UIRectEdge {
        get {
            return super.edgesForExtendedLayout
        }
        set {
            if self.edgesForExtendedLayout == newValue {
                return
            }
            super.edgesForExtendedLayout = newValue
            
            self.myp_updateViewConstraints()
        }
    }
    
    //MARK: init
    /**
     Initializes a text view controller to manage a table view of a given style.
     If you use the standard -init method, a table view with plain style will be created.
     
     - Parameters:
     - style: A constant that specifies the style of main table view that the controller object is to manage (UITableViewStylePlain or UITableViewStyleGrouped).
     */
    public init(tableViewStyle style: UITableViewStyle) {
        super.init(nibName: nil, bundle: nil)
        
        self.tableView = self.tableView(with: style)
        self.scrollViewProxy = self.tableView!
        
        commonSetting()
    }
    
    private func tableView(with style: UITableViewStyle) -> UITableView {
        let table = UITableView(frame: .zero, style: style)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.scrollsToTop = true
        table.dataSource = self
        table.delegate = self
        table.clipsToBounds = false
        
        self.myp_updateInsetAdjustmentBehavior()
        
        return table
    }
    
    private func collectionView(with layout: UICollectionViewLayout) -> UICollectionView {
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .white
        collection.translatesAutoresizingMaskIntoConstraints = false
        collection.scrollsToTop = true
        collection.dataSource = self
        collection.delegate = self
        
        return collection
    }
    
    /**
     Initializes a collection view controller and configures the collection view with the provided layout.
     If you use the standard -init method, a table view with plain style will be created.
     
     - Parameters:
     - layout: The layout object to associate with the collection view. The layout controls how the collection view presents its cells and supplementary views.
     */
    public init(collectionViewLayout layout: UICollectionViewLayout) {
        super.init(nibName: nil, bundle: nil)
        
        self.collectionView = self.collectionView(with: layout)
        self.scrollViewProxy = self.collectionView!
        
        commonSetting()
    }
    
    /**
     Initializes a text view controller to manage an arbitraty scroll view. The caller is responsible for configuration of the scroll view, including wiring the delegate.
     
     - Parameters:
     - scrollView: UISCrollView to be used as the main content area.
     */
    public init(scrollView: UIScrollView) {
        super.init(nibName: nil, bundle: nil)
        
        self.scrollView = scrollView
        // Makes sure the scrollView plays nice with auto-layout
        self.scrollView?.translatesAutoresizingMaskIntoConstraints = false
        
        self.scrollViewProxy = self.scrollView!
        
        commonSetting()
    }
    
    override convenience init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.init(tableViewStyle: .plain)
    }
    
    convenience public init() {
        self.init(tableViewStyle: .plain)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        /**
         Initializes either a table or collection view controller.
         You must override either +tableViewStyleForCoder: or +collectionViewLayoutForCoder: to define witch view to be layed out.
         */
        super.init(coder: aDecoder)
        
        let tableStyle = MYPMessageController.tableViewStyle(for: aDecoder)
        let collectionLayout = MYPMessageController.collectionViewLayout(for: aDecoder)
        
        if let x = collectionLayout {
            self.collectionView = self.collectionView(with: x)
            self.scrollViewProxy = self.collectionView
        }
        else {
            self.tableView = self.tableView(with: tableStyle)
            self.scrollViewProxy = self.tableView
        }
        
        self.commonSetting()
    }
    
    /**
     Returns the tableView style to be configured when using Interface Builder. Default is UITableViewStyle.plain.
     You must override this method if you want to configure a tableView.
     */
    open class func tableViewStyle(for decoder: NSCoder?) -> UITableViewStyle {
        return .plain
    }
    
    /**
     Returns the collectionViewLayout to be configured when using Interface Builder. Default is nil.
     You must override this method if you want to configure a collectionView.
     
     - Parameters:
     - decoder: An unarchiver object.
     - Returns: The collectionView style to be used in the new instantiated collectionView.
     */
    open class func collectionViewLayout(for decoder: NSCoder?) -> UICollectionViewLayout? {
        return nil
    }
    
    private func commonSetting() {
        self.myp_registerNotifications()
        
        self.automaticallyAdjustsScrollViewInsets = true
        self.extendedLayoutIncludesOpaqueBars = true
        
        self.scrollViewProxy!.addGestureRecognizer(self.singleTapGesture)
        self.scrollViewProxy!.panGestureRecognizer.addTarget(self, action: #selector(myp_didPanTextInputBar(recognizer:)))
        
        // set inverted transform
        self.myp_updateInsetAdjustmentBehavior()
        self.scrollViewProxy!.transform = self.isInverted ? CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0) : CGAffineTransform.identity
    }
    
    @objc private func myp_didPanTextInputBar(recognizer: UIPanGestureRecognizer) {
        
        // Textinput dragging isn't supported when
        if self.view.window == nil || !self.isKeyboardPanningEnabled || self.ignoreTextInputbarAdjustment() || self.isPresentedInPopover {
            return
        }
        
        DispatchQueue.main.async {
            self.myp_handlePanGestureRecognizer(recognizer)
        }
    }
    
    @objc private func myp_didTapScrollView(recognizer: UIPanGestureRecognizer) {
        if !self.isPresentedInPopover && !self.ignoreTextInputbarAdjustment() {
            self.dismissKeyboard(animated: true)
        }
    }
    
    private var startPoint = CGPoint.zero
    private var originFrame = CGRect.zero
    private var isDragging = false
    private var isPresenting = false
    private var keyboardView: UIView? {
        return UIView() //self.textInputbar.inputAccessoryView.keyboardViewProxy
    }
    
    private func myp_handlePanGestureRecognizer(_ recognizer: UIPanGestureRecognizer) {
        
        if keyboardView == nil {
            return
        }
        print("Message Controller: Have keyboardView")
        let gestureLocation = recognizer.location(in: self.view)
        let gestureVelocity = recognizer.velocity(in: self.view)
        
        let keyboardMaxY = MYPKeyWindowBounds!.height
        let keyboardMinY = keyboardMaxY - keyboardView!.frame.height
        
        // Skips this if it's not the expected textView.
        // Checking the keyboard height constant helps to disable the view constraints update on iPad when the keyboard is undocked.
        // Checking the keyboard status allows to keep the inputAccessoryView valid when still reaching the bottom of the screen.
        let bottomMargin = self.myp_appropriateBottomMargin()
        
        if !self.textView.isFirstResponder || (self.keyboardHeightC.constant == bottomMargin && self.keyboardStatus == .didHide) {
            if MYPBottomPanningEnabled {
                if recognizer.view == self.scrollViewProxy {
                    if gestureVelocity.y > 0 {
                        return
                    }
                    else if (self.isInverted && !self.scrollViewProxy!.myp_isAtTop) || (!self.isInverted && !self.scrollViewProxy!.myp_isAtBottom) {
                        return
                    }
                }
                
                isPresenting = true
            }
            else {
                if recognizer.view == self.textInputbar && gestureVelocity.y < 0 {
                    print("Present")
                    self.presentKeyboard(animated: true)
                }
                return
            }
        }
        
        switch recognizer.state {
        case .began:
            startPoint = .zero
            isDragging = false
            if isPresenting {
                // Let's first present the keyboard without animation
                self.presentKeyboard(animated: false)
                
                // So we can capture the keyboard's view
                originFrame = keyboardView!.frame
                originFrame.origin.y = self.view.frame.maxY
                
                // And move the keyboard to the bottom edge
                // TODO: Fix an occasional layout glitch when the keyboard appears for the first time.
                keyboardView?.frame = originFrame
            }
            break
        case .changed:
            if self.textInputbar.frame.contains(gestureLocation) || isDragging || isPresenting {
                if startPoint == .zero {
                    startPoint = gestureLocation
                    isDragging = true
                    
                    if !isPresenting {
                        originFrame = keyboardView!.frame
                    }
                }
                
                self.isMovingKeyboard = true
                
                let transition = CGPoint(x: gestureLocation.x - startPoint.x, y: gestureLocation.y - startPoint.y)
                var keyboardFrame = originFrame
                
                if isPresenting {
                    keyboardFrame.origin.y += transition.y
                }
                else {
                    keyboardFrame.origin.y += max(transition.y, 0.0)
                }
                
                // Makes sure they keyboard is always anchored to the bottom
                if keyboardFrame.minY < keyboardMinY {
                    keyboardFrame.origin.y = keyboardMinY
                }
                
                keyboardView?.frame = keyboardFrame
                
                self.keyboardHeightC.constant = self.myp_appropriateKeyboardHeight(from: keyboardFrame)
                self.scrollViewHeightC.constant = self.myp_appropriateScrollViewHeight()
                
                // layoutIfNeeded must be called before any further scrollView internal adjustments (content offset and size)
                self.view.layoutIfNeeded()
                
                // Overrides the scrollView's contentOffset to allow following the same position when dragging the keyboard
                var offset = self.scrollViewOffsetBeforeDragging
                
                if self.isInverted {
                    if !self.scrollViewProxy!.isDecelerating && self.scrollViewProxy!.isTracking {
                        self.scrollViewProxy!.contentOffset = self.scrollViewOffsetBeforeDragging
                    }
                }
                else {
                    let heightDelta = self.keyboardHeightBeforeDragging - self.keyboardHeightC.constant
                    offset.y -= heightDelta
                    
                    self.scrollViewProxy?.contentOffset = offset
                }
            }
            break
        case .possible, .cancelled, .ended, .failed:
            if !isDragging {
                break
            }
            
            let transition = CGPoint(x: 0.0, y: fabs(gestureLocation.y - startPoint.y))
            var keyboardFrame = originFrame
            
            if isPresenting {
                keyboardFrame.origin.y = keyboardMinY
            }
            
            // The velocity can be changed to hide or show the keyboard based on the gesture
            let minVelocity: CGFloat = 20.0
            let minDistance = keyboardFrame.height / 2.0
            
            let hide = (gestureVelocity.y > minVelocity) || (isPresenting && transition.y < minDistance) || (!isPresenting && transition.y > minDistance)
            
            if hide {
                keyboardFrame.origin.y = keyboardMaxY
                
                self.keyboardHeightC.constant = self.myp_appropriateKeyboardHeight(from: keyboardFrame)
                self.scrollViewHeightC.constant = self.myp_appropriateScrollViewHeight()
                
                UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseInOut, .beginFromCurrentState], animations: {
                    self.view.layoutIfNeeded()
                    self.keyboardView?.frame = keyboardFrame
                }) { (finished) in
                    if hide {
                        self.dismissKeyboard(animated: false)
                    }
                    
                    // Tear down
                    self.startPoint = .zero
                    self.originFrame = .zero
                    self.isDragging = false
                    self.isPresenting = false
                    
                    self.isMovingKeyboard = false
                }
            }
            break
        }
    }
    
    //MARK: text input bar adjustment
    /** true if the text inputbar is hidden. Default is false. */
    open var textInputbarHidden: Bool {
        get {
            return self.textInputbar.isHidden
        }
        set {
            self.setTextInputbarHidden(newValue, animated: false)
        }
    }
    
    private func myp_dismissTextInputbarIfNeeded() {
        let bottomMargin = self.myp_appropriateBottomMargin()
        
        if self.keyboardHeightC.constant == bottomMargin {
            return
        }
        
        self.keyboardHeightC.constant = bottomMargin
        self.scrollViewHeightC.constant = self.myp_appropriateScrollViewHeight()
        
        self.myp_hideAutoCompletionViewIfNeeded()
        
        self.view.layoutIfNeeded()
    }
    
    //MARK: text auto-completion
    
    /** read-only. The table view used to display autocompletion results. */
    open var autoCompletionView: UITableView {
        return self.autoCompletionViewHelper
    }
    
    lazy private var autoCompletionViewHelper: UITableView = {
        let aView = UITableView(frame: .zero, style: .plain)
        aView.translatesAutoresizingMaskIntoConstraints = false
        aView.backgroundColor = UIColor(white: 0.97, alpha: 1.0)
        aView.scrollsToTop = false
        aView.dataSource = self
        aView.delegate = self
        
        aView.cellLayoutMarginsFollowReadableWidth = false
        
        self.autoCompletionHairline.backgroundColor = aView.backgroundColor
        aView.addSubview(self.autoCompletionHairline)
        
        return aView
    }()
    
    /** true if the autocompletion mode is active. */
    var isAutoCompleting = false {
        didSet {
            if self.isAutoCompleting == oldValue {
                return
            }
            self.scrollViewProxy!.isScrollEnabled = !self.isAutoCompleting
        }
    }
    
    /** The recently found prefix symbol used as prefix for autocompletion mode. */
    var foundPrefix: String?
    
    /** The range of the found prefix in the text view content. */
    var foundPrefixRange = NSRange()
    
    /** The recently found word at the text view's caret position. */
    var foundWord: String?
    
    /** An array containing all the registered prefix strings for autocompletion. */
    var registeredPrefixes: Set<String>?
    
    /** UIScrollViewDelegate */
    open func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        if !self.scrollViewProxy!.scrollsToTop || self.keyboardStatus == .willShow {
            return false
        }
        
        if self.isInverted {
            self.scrollViewProxy!.myp_scrollToBottom(animated: true)
            return false
        }
        
        return true
    }
    
    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.isMovingKeyboard = false
    }
    
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.isMovingKeyboard = false
    }
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView == self.autoCompletionView {
            var frame = self.autoCompletionHairline.frame
            frame.origin.y = scrollView.contentOffset.y
            self.autoCompletionHairline.frame = frame
        }
        else {
            if !self.isMovingKeyboard {
                self.scrollViewOffsetBeforeDragging = scrollView.contentOffset
                self.keyboardHeightBeforeDragging = self.keyboardHeightC.constant
            }
        }
    }
    
    /** UIGestureRecognizerDelegate */
    open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == self.singleTapGesture {
            return self.textView.isFirstResponder && !self.ignoreTextInputbarAdjustment()
        }
        else if gestureRecognizer == self.verticalPanGesture {
            return self.isKeyboardPanningEnabled && !self.ignoreTextInputbarAdjustment()
        }
        
        return false
    }
    
    //MARK: Notifications
    private func myp_registerNotifications() {
        self.myp_unregisterNotifications()
        
        let center = NotificationCenter.default
        
        // keyboard notifications
        center.addObserver(self, selector: #selector(myp_willShowOrHideKeyboard(notification:)), name: .UIKeyboardWillShow, object: nil)
        center.addObserver(self, selector: #selector(myp_willShowOrHideKeyboard(notification:)), name: .UIKeyboardWillHide, object: nil)
        center.addObserver(self, selector: #selector(myp_didShowOrHideKeyboard(notification:)), name: .UIKeyboardDidShow, object: nil)
        center.addObserver(self, selector: #selector(myp_didShowOrHideKeyboard(notification:)), name: .UIKeyboardDidHide, object: nil)
        
        // textView notifications
        center.addObserver(self, selector: #selector(myp_willChangeTextViewText(notification:)), name: Notification.Name.MYPTextInputTask.MYPTextViewTextWillChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(myp_didChangeTextViewText(notification:)), name: .UITextViewTextDidChange, object: nil)
        center.addObserver(self, selector: #selector(myp_didChangeTextViewContentSize(notification:)), name: Notification.Name.MYPTextInputTask.MYPTextViewContentSizeDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(myp_didChangeTextViewSelectedRange(notification:)), name: Notification.Name.MYPTextInputTask.MYPTextViewSelectedRangeDidChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(myp_didChangeTextViewPasteboard(notification:)), name: Notification.Name.MYPTextInputTask.MYPTextViewDidPasteItemNotification, object: nil)
        center.addObserver(self, selector: #selector(myp_didShakeTextView(notification:)), name: Notification.Name.MYPTextInputTask.MYPTextViewDidShakeNotification, object: nil)
        
        // application notifications
        center.addObserver(self, selector: #selector(cacheTextView), name: .UIApplicationWillTerminate, object: nil)
        center.addObserver(self, selector: #selector(cacheTextView), name: .UIApplicationDidEnterBackground, object: nil)
        center.addObserver(self, selector: #selector(cacheTextView), name: .UIApplicationDidReceiveMemoryWarning, object: nil)
    }
    
    private func myp_unregisterNotifications() {
        let center = NotificationCenter.default
        
        center.removeObserver(self, name: .UIKeyboardWillShow, object: nil)
        center.removeObserver(self, name: .UIKeyboardWillHide, object: nil)
        center.removeObserver(self, name: .UIKeyboardDidShow, object: nil)
        center.removeObserver(self, name: .UIKeyboardDidHide, object: nil)
        
        center.removeObserver(self, name: .UITextViewTextDidBeginEditing, object: nil)
        center.removeObserver(self, name: .UITextViewTextDidEndEditing, object: nil)
        center.removeObserver(self, name: .UITextViewTextDidChange, object: nil)
        center.removeObserver(self, name: Notification.Name.MYPTextInputTask.MYPTextViewTextWillChangeNotification, object: nil)
        center.removeObserver(self, name: Notification.Name.MYPTextInputTask.MYPTextViewContentSizeDidChangeNotification, object: nil)
        center.removeObserver(self, name: Notification.Name.MYPTextInputTask.MYPTextViewSelectedRangeDidChangeNotification, object: nil)
        center.removeObserver(self, name: Notification.Name.MYPTextInputTask.MYPTextViewDidPasteItemNotification, object: nil)
        center.removeObserver(self, name: Notification.Name.MYPTextInputTask.MYPTextViewDidShakeNotification, object: nil)
        
        center.removeObserver(self, name: .UIApplicationWillTerminate, object: nil)
        center.removeObserver(self, name: .UIApplicationDidEnterBackground, object: nil)
        center.removeObserver(self, name: .UIApplicationDidReceiveMemoryWarning, object: nil)
    }
    
    //MARK: Keyboard Observer
    @objc private func myp_willShowOrHideKeyboard(notification: Notification) {
        let status = self.myp_keyboardStatus(for: notification)
        
        if !self.isViewVisible {
            return
        }
        
        if self.isPresentedInPopover {
            return
        }
        
        // Skips if textview did refresh only.
        if self.textView.didNotResignFirstResponder {
            return
        }
        
        let currentResponder = UIResponder.current
        
        // Skips if it's not the expected textView and shouldn't force adjustment of the text input bar.
        // This will also dismiss the text input bar if it's visible, and exit auto-completion mode if enabled.
        if currentResponder != nil && currentResponder != self.textView && !self.forceTextInputbarAdjustment(for: currentResponder) {
            self.myp_dismissTextInputbarIfNeeded()
            return
        }
        
        // Skips if it's the current status
        if self.keyboardStatus == status {
            return
        }
        
        // Programatically stops scrolling before updating the view constraints (to avoid scrolling glitch).
        if status == .willShow {
            self.scrollViewProxy?.myp_stopScrolling()
        }
        
        // Stores the previous keyboard height
        let previousKeyboardHeight = self.keyboardHeightC.constant
        
        // Updates the height constraints' constants
        self.keyboardHeightC.constant = self.myp_appropriateKeyboardHeight(from: notification)
        self.scrollViewHeightC.constant = self.myp_appropriateScrollViewHeight()
        
        // Updates and notifies about the keyboard status update
        if self.myp_updateKeyboardStatus(status!) {
            // Posts custom keyboard notification, if logical conditions apply
            
        }
        
        // Hides the auto-completion view if the keyboard is being dismissed.
        if !self.textView.isFirstResponder || status == .willHide {
            self.myp_hideAutoCompletionViewIfNeeded()
        }
        
        let scroll = self.scrollViewProxy!
        
        let curve = Int((notification.userInfo![UIKeyboardAnimationCurveUserInfoKey] as AnyObject).doubleValue)
        let duration = (notification.userInfo![UIKeyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue
        
        let beginFrame = (notification.userInfo![UIKeyboardFrameBeginUserInfoKey] as AnyObject).cgRectValue
        let endFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue
        
        let animations: (() -> Void) = {() -> Void in
            // Scrolls to bottom only if the keyboard is about to show.
            if self.shouldScrollToBottomAfterKeyboardShows && self.keyboardStatus == .willShow {
                if self.isInverted {
                    scroll.myp_scrollToTop(animated: true)
                } else {
                    scroll.myp_scrollToBottom(animated: true)
                }
            }
        }
        
        // Begin and end frames are the same when the keyboard is shown during navigation controller's push animation.
        // The animation happens in window coordinates (slides from right to left) but doesn't in the view controller's view coordinates.
        // Second condition: check if the height of the keyboard changed.
        if beginFrame != endFrame || fabs(previousKeyboardHeight - self.keyboardHeightC.constant) > 0.0 {
            // Content Offset correction if not inverted and not auto-completing.
            if !self.isInverted && !self.isAutoCompleting {
                let scrollHeight = self.scrollViewHeightC.constant
                let keyboardHeight = self.keyboardHeightC.constant
                let contentSize = scroll.contentSize
                let contentOffset = scroll.contentOffset
                
                let newOffset = min(contentSize.height - scrollHeight, contentOffset.y + keyboardHeight - previousKeyboardHeight)
                
                scroll.contentOffset = CGPoint(x: contentOffset.x, y: newOffset)
            }
            // Only for this animation, we set bo to bounce since we want to give the impression that the text input is glued to the keyboard.
            self.view.myp_animateLayoutIfNeeded(withDuration: duration!, bounce: false, options: [UIViewAnimationOptions(rawValue: UInt(curve<<16)), .layoutSubviews, .beginFromCurrentState], animations: animations, completion: nil)
        }
        else {
            animations()
        }
    }
    
    @objc private func myp_didShowOrHideKeyboard(notification: Notification) {
        let status = self.myp_keyboardStatus(for: notification)
        
        if !self.isViewVisible {
            if status == .didHide && self.keyboardStatus == .willHide {
                // Even if the view isn't visible anymore, let's still continue to update all states.
            }
            else {
                return
            }
        }
        
        if self.isPresentedInPopover {
            return
        }
        
        if self.textView.didNotResignFirstResponder {
            return
        }
        
        if self.keyboardStatus == status {
            return
        }
        
        // Updates and notifies about the keyboard status update
        if self.myp_updateKeyboardStatus(status!) {
            // Posts custom keyboard notification, if logical conditions apply
        }
        
        // After showing keyboard, check if the current cursor position could diplay autocompletion
        if self.textView.isFirstResponder && status == .didShow && !self.isAutoCompleting {
            // Wait till the end of the current run loop
            DispatchQueue.main.async {
                self.myp_processtextForAutoCompletion()
            }
        }
        
        // Very important to invalidate this flag after the keyboard is dismissed or presented, to start with a clean state next time.
        self.isMovingKeyboard = false
    }
    
    //MARK: textView observer
    @objc private func myp_willChangeTextViewText(notification: Notification) {
        if !self.isNotificationObjectSelf(notification) {
            return
        }
        
        self.textWillUpdate()
    }
    
    @objc private func myp_didChangeTextViewText(notification: Notification) {
        if !self.isNotificationObjectSelf(notification) {
            return
        }
        
        // Animated only if the view already appeared.
        self.textDidUpdate(animated: self.isViewVisible)
        
        // Process the text at every change, when the view is visible
        if self.isViewVisible {
            self.myp_processtextForAutoCompletion()
        }
    }
    
    @objc private func myp_didChangeTextViewContentSize(notification: Notification) {
        if !self.isNotificationObjectSelf(notification) {
            return
        }
        
        // Animated only if the view already appeared.
        self.textDidUpdate(animated: self.isViewVisible)
    }
    
    @objc private func myp_didChangeTextViewSelectedRange(notification: Notification) {
        if !self.isNotificationObjectSelf(notification) {
            return
        }
        
        self.textSelectionDidChange()
    }
    
    @objc private func myp_didChangeTextViewPasteboard(notification: Notification) {
        if !self.isNotificationObjectSelf(notification) {
            return
        }
        
        // Notifies only if the pasted item is nested in a dictionary.
        if notification.userInfo != nil {
            self.didPasteMediaContent(userInfo: notification.userInfo! as! [String : Any])
        }
    }
    
    @objc private func myp_didShakeTextView(notification: Notification) {
        if !self.isNotificationObjectSelf(notification) {
            return
        }
        
        // Notifies of the shake gesture if undo mode is on and the text view is not empty
        if self.isShakeToClearEnabled && self.textView.text.count > 0 {
            self.willRequestUndo()
        }
    }
    
    private func isNotificationObjectSelf(_ notification: Notification) -> Bool {
        if notification.object is MYPTextView {
            if (notification.object as! MYPTextView) == self.textView {
                return true
            }
        }
        return false
    }
    
    //MARK: auto-rotation
    override open func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.myp_prepareForInterfaceTransition(with: coordinator.transitionDuration)
        super.viewWillTransition(to: size, with: coordinator)
    }
    
    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    override open var shouldAutorotate: Bool {
        return true
    }
    
    private func myp_prepareForInterfaceTransition(with duration: TimeInterval) {
        self.isTransitioning = true
        
        self.view.layoutIfNeeded()
        
        if self.textView.isFirstResponder {
            self.textView.myp_scrollToCaretPosition(animated: false)
        }
        else {
            self.textView.myp_scrollToBottom(animated: false)
        }
        
        // Disables the flag after the rotation animation is finished
        // Hacky but works.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + duration) {
            self.isTransitioning = false
        }
    }
    
    //MARK: lifetime
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        self.myp_unregisterNotifications()
    }
    
}
