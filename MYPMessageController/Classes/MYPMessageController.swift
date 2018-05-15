//
//  MYPMessageController.swift
//  MYPTextInputVC
//
//  Created by wakary redou on 2018/5/4.
//  Copyright © 2018年 wakary redou. All rights reserved.
//

import UIKit

fileprivate let MYPBottomPanningEnabled = false
fileprivate let MYPAutoCompletionViewDefaultHeight: CGFloat = 140.0

open class MYPMessageController: UIViewController, UITextViewDelegate, UIGestureRecognizerDelegate {
    
    /** read-only. The main table view managed by the controller object. Created by default initializing with -init or initWithNibName:bundle: */
    private(set) var tableView: UITableView?
    
    /** read-only. The main collection view managed by the controller object. Not nil if the controller is initialised with -initWithCollectionViewLayout: */
    private(set) var collectionView: UICollectionView?
    
    /** read-only. The main scroll view managed by the controller object. Not nil if the controller is initialised with -initWithScrollView: */
    private(set) var scrollView: UIScrollView?
    
    /** read-only. The inputbar view containing a text view and buttons. */
    var textInputbar: MYPTextInputbarView {
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
    var bounces = true {
        didSet {
            self.textInputbar.bounces = self.bounces
        }
    }
    
    /** true if text view's content can be cleaned with a shake gesture. Default is false. */
    var isShakeToClearEnabled = false
    
    /**
     true if keyboard can be dismissed gradually with a vertical panning gesture. Default is true.
     
     This feature doesn't work on iOS 9 due to no legit alternatives to detect the keyboard view.
     Open Radar: http://openradar.appspot.com/radar?id=5021485877952512
     */
    var isKeyboardPanningEnabled = true
    
    /** true if an external keyboard has been detected (this value updates only when the text view becomes first responder). */
    private(set) var isExternalKeyboardDetected = false
    
    /** true if the keyboard has been detected as undocked or split (iPad Only). */
    private(set) var isKeyboardUndocked = false
    
    /** true if after send button press, the text view is cleared out. Default is true. */
    var shouldClearTextAtSendButtonPress = true
    
    /** true if the scrollView should scroll to bottom when the keyboard is shown. Default is false.*/
    var shouldScrollToBottomAfterKeyboardShows = false
    
    /**
     true if the main table view is inverted. Default is true.
     This allows the table view to start from the bottom like any typical messaging interface.
     If inverted, you must assign the same transform property to your cells to match the orientation (ie: cell.transform = tableView.transform;)
     Inverting the table view will enable some great features such as content offset corrections automatically when resizing the text input and/or showing autocompletion.
     */
    var isInverted = true {
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
    var isPresentedInPopover: Bool {
        return self.isPresentedInPopoverHepler && MYP_IS_IPAD
    }
    
    private var isPresentedInPopoverHepler = false
    
    /** The current keyboard status (will/did hide, will/did show) */
    private(set) var keyboardStatus: MYPKeyboardStatus?
    
    /** Convenience accessors (accessed through the text input bar) */
    var textView: MYPTextView {
        return self.textInputbar.textView
    }
    var leftButton: UIButton {
        return self.textInputbar.leftButton
    }
    var rightButton: UIButton {
        return self.textInputbar.rightButton
    }
    var rightMoreButton: UIButton {
        return self.textInputbar.rightMoreButton
    }
    var sendButton: UIButton {
        return self.textInputbar.sendButton
    }
    
    // The shared scrollView pointer, either a tableView or collectionView
    private weak var scrollViewProxy: UIScrollView?
    
    private var scrollViewOffsetBeforeDragging: CGPoint?
    private var keyboardHeightBeforeDragging: CGFloat?
    
    // A hairline displayed on top of the auto-completion view, to better separate the content from the control.
    lazy private var autoCompletionHairline: UIView = {
        var rect = CGRect.zero
        rect.size = CGSize(width: self.view.frame.width, height: 0.5)
        let hairline = UIView(frame: rect)
        hairline.autoresizingMask = UIViewAutoresizing.flexibleWidth
        
        return hairline
    }()
    
    // Auto-Layout height constraints used for updating their constants
    private var scrollViewHeightC: NSLayoutConstraint = NSLayoutConstraint()
    private var textInputbarHeightC: NSLayoutConstraint = NSLayoutConstraint()
    private var autoCompletionViewHeightC: NSLayoutConstraint = NSLayoutConstraint()
    private var keyboardHeightC: NSLayoutConstraint = NSLayoutConstraint()
    
    /** true if the user is moving the keyboard with a gesture */
    private var isMovingKeyboard = false
    
    /** true if the view controller did appear and everything is finished configurating.
       This allows blocking some layout animations among other things. */
    private var isViewVisible = false
    
    /** true if the view controller's view's size is changing by its parent (i.e. when its window rotates or is resized) */
    private var isTransitioning = false
    
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
    
    private func myp_appropriateKeyboardHeight(from notification: Notification) -> CGFloat {
        // Let's first detect keyboard special states such as external keyboard, undocked or split layouts.
        self.myp_detectKeyboardStates(in: notification)
        
        if self.ignoreTextInputbarAdjustment() {
            return self.myp_appropriateBottomMargin()
        }
        
        let keyboardRect = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue
        
        return self.myp_appropriateKeyboardHeight(from: keyboardRect!)
    }
    
    private func myp_appropriateKeyboardHeight(from rect: CGRect) -> CGFloat {
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
    
    private func myp_appropriateBottomMargin() -> CGFloat {
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
    
    private func myp_appropriateScrollViewHeight() -> CGFloat {
        var scrollHeight = self.view.bounds.height
        scrollHeight -= self.keyboardHeightC.constant
        scrollHeight -= self.textInputbarHeightC.constant
        scrollHeight -= self.autoCompletionViewHeightC.constant
        
        if scrollHeight < 0 {
            return 0.0
        }
        
        return scrollHeight
    }
    
    private func myp_topBarsHeight() -> CGFloat {
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
    
    private func myp_enableTypingSuggestionIfNeeded() {
        if !self.textView.isFirstResponder {
            return
        }
        
        let enable = !self.isAutoCompleting
        
        let inputPrimaryLanguage = self.textView.textInputMode?.primaryLanguage
        
        // Toggling autocorrect on Japanese keyboards breaks autocompletion by replacing the autocompletion prefix by an empty string.
        // So for now, let's not disable autocorrection for Japanese.
        if inputPrimaryLanguage == "ja-JP" {
            return
        }
        
        // Let's avoid refreshing the text view while dictation mode is enabled.
        // This solves a crash some users were experiencing when auto-completing with the dictation input mode.
        if inputPrimaryLanguage == "dictation" {
            return
        }
        
        if enable == false && !self.shouldDisableTypingSuggestionForAutoCompletion() {
            return
        }
        
        self.textView.isTypingSuggestionEnabled = enable
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

    //MARK: view life cycle
    override open func loadView() {
        super.loadView()
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.view.addSubview(self.scrollViewProxy!)
        self.view.addSubview(self.autoCompletionView)
        self.view.addSubview(self.textInputbar)
        
        self.myp_setupViewConstraints()
        
        self.myp_registerKeyCommands()
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Invalidates this flag when the view appears
        self.textView.didNotResignFirstResponder = false
        
        // Forces laying out the recently added subviews and update their constraints
        self.view.layoutIfNeeded()
        
        UIView.performWithoutAnimation {
            // Reloads any cached text
            self.myp_reloadTextView()
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.scrollViewProxy!.flashScrollIndicators()
        
        self.isViewVisible = true
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Stops the keyboard from being dismissed during the navigation controller's "swipe-to-pop"
        self.textView.didNotResignFirstResponder = self.isMovingFromParentViewController
        
        self.isViewVisible = false
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Caches the text before it's too late!
        self.cacheTextView()
    }
    
    override open func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        self.myp_adjustContentConfigurationIfNeeded()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    @available(iOS 11.0, *)
    override open func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        self.myp_updateViewConstraints()
    }
    
    private func myp_setupViewConstraints() {
        
        let views = ["scrollView": scrollViewProxy!, "autoCompletionView": autoCompletionView, "textInputbar": textInputbar]
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[scrollView(0@750)]-0@999-[textInputbar(>=0)]|", options: [], metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=0)-[autoCompletionView(0@750)]-0@999-[textInputbar]", options: [], metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[scrollView]|", options: [], metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[autoCompletionView]|", options: [], metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[textInputbar]|", options: [], metrics: nil, views: views))
        
        scrollViewHeightC = view.myp_constraint(for: .height, firstItem: scrollViewProxy, secondItem: nil)!
        autoCompletionViewHeightC = view.myp_constraint(for: .height, firstItem: autoCompletionView, secondItem: nil)!
        textInputbarHeightC = view.myp_constraint(for: .height, firstItem: textInputbar, secondItem: nil)!
        keyboardHeightC = view.myp_constraint(for: .bottom, firstItem: view, secondItem: textInputbar)!
        
        self.myp_updateViewConstraints()

    }
    
    private func myp_updateViewConstraints() {
        self.textInputbarHeightC.constant = self.textInputbar.minimumInputbarHeight
        self.scrollViewHeightC.constant = self.myp_appropriateScrollViewHeight()
        self.keyboardHeightC.constant = self.myp_appropriateKeyboardHeight(from: .null)
        
        super.updateViewConstraints()
    }
    
    private func myp_adjustContentConfigurationIfNeeded() {
        var contentInset = self.scrollViewProxy!.contentInset
        
        // When inverted, we need to substract the top bars height (generally status bar + navigation bar's) to align the top of the
        // scrollView correctly to its top edge.
        if self.isInverted {
            contentInset.bottom = self.myp_topBarsHeight()
            contentInset.top = contentInset.bottom > 0.0 ? 0.0 : contentInset.top
        }
        else {
            contentInset.bottom = 0.0
        }
        
        self.scrollViewProxy?.contentInset = contentInset
        self.scrollViewProxy?.scrollIndicatorInsets = contentInset
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
    
    private func myp_reloadTextView() {
        let key = self.myp_keyForPersistency()
        
        if key == nil {
            return
        }
        
        var cachedAttributedText = NSAttributedString(string: "")
        
        let obj = UserDefaults.standard.object(forKey: key!)
        
        if obj != nil {
            if obj is String {
                cachedAttributedText = NSAttributedString(string: obj as! String)
            }
            else if obj is Data {
                cachedAttributedText = NSKeyedUnarchiver.unarchiveObject(with: obj as! Data) as! NSAttributedString
            }
        }
        
        if self.textView.attributedText.length == 0 || cachedAttributedText.length > 0 {
            self.textView.attributedText = cachedAttributedText
        }
    }
    
    //MARK: init
    /**
     Initializes a text view controller to manage a table view of a given style.
     If you use the standard -init method, a table view with plain style will be created.
     
     - Parameters:
         - style: A constant that specifies the style of main table view that the controller object is to manage (UITableViewStylePlain or UITableViewStyleGrouped).
     */
    init(tableViewStyle style: UITableViewStyle) {
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
    init(collectionViewLayout layout: UICollectionViewLayout) {
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
    init(scrollView: UIScrollView) {
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
    
    convenience init() {
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
    class func tableViewStyle(for decoder: NSCoder?) -> UITableViewStyle {
        return .plain
    }
    
    /**
     Returns the collectionViewLayout to be configured when using Interface Builder. Default is nil.
     You must override this method if you want to configure a collectionView.
     
     - Parameters:
         - decoder: An unarchiver object.
     - Returns: The collectionView style to be used in the new instantiated collectionView.
     */
    class func collectionViewLayout(for decoder: NSCoder?) -> UICollectionViewLayout? {
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
    
    //MARK: keyboard handling
    /**
     Presents the keyboard, if not already, animated.
     You can override this method to perform additional tasks associated with presenting the keyboard.
     You SHOULD call super to inherit some conditionals.
     */
    func presentKeyboard(animated: Bool) {
        // Skips if already first responder
        if self.textView.isFirstResponder {
            return
        }
        
        if !animated {
            UIView.performWithoutAnimation {
                _ = self.textView.becomeFirstResponder()
            }
        }
        else {
            _ = self.textView.becomeFirstResponder()
        }
    }
    
    /**
     Dimisses the keyboard, if not already, animated.
     You can override this method to perform additional tasks associated with dismissing the keyboard.
     You SHOULD call super to inherit some conditionals.
     */
    func dismissKeyboard(animated: Bool) {
        if !self.textView.isFirstResponder && self.keyboardHeightC.constant > 0 {
            self.view.window?.endEditing(false)
        }
        
        if !animated {
            UIView.performWithoutAnimation {
                _ = self.textView.resignFirstResponder()
            }
        }
        else {
            _ = self.textView.resignFirstResponder()
        }
    }
    
    /**
     Verifies if the text input bar should still move up/down even if it is NOT first responder.
     Default is false.
     You can override this method to perform additional tasks associated with presenting the view.
     You don't need call super since this method doesn't do anything.
     
     - Parameters:
         - responder: The current first responder object.
     - Returns: true so the text input bar still move up/down.
     */
    func forceTextInputbarAdjustment(for responder: UIResponder?) -> Bool {
        return false
    }
    
    /**
     Verifies if the text input bar should still move up/down when the text view is first responder.
     This is very useful when presenting the view controller in a custom modal presentation, when there keyboard events are being handled externally to reframe the presented view.
     You SHOULD call super to inherit some conditionals.
     
     - Returns: true so the text input bar still move up/down.
     */
    func ignoreTextInputbarAdjustment() -> Bool {
        if self.isExternalKeyboardDetected || self.isKeyboardUndocked {
            return true
        }
        
        return false
    }
    
    /**
     Notifies the view controller that the keyboard changed status.
     You can override this method to perform additional tasks associated with presenting the view.
     You don't need call super since this method doesn't do anything.
     */
    func keyboardDidChange(status: MYPKeyboardStatus) {
        // do nothing here. override it in subclass
    }
    
    //MARK: Interaction Notifications
    /**
     Notifies the view controller that the text will update.
     You can override this method to perform additional tasks associated with text changes.
     You MUST call super at some point in your implementation.
     */
    func textWillUpdate() {
        // do nothing here. override it in subclass
    }
    
    /**
     Notifies the view controller that the text did update.
     You can override this method to perform additional tasks associated with text changes.
     You MUST call super at some point in your implementation.
     
     - Parameters:
         - animated: If true, the text input bar will be resized using an animation.
     */
    func textDidUpdate(animated: Bool) {
        
        if self.textInputbarHidden {
            return
        }
        
        let inputBarHeight = self.textInputbar.appropriateHeight
        
        // update input bar height here
        if inputBarHeight != self.textInputbarHeightC.constant {
            
            let heightDelta = inputBarHeight - self.textInputbarHeightC.constant
            let newOffset = CGPoint(x: 0, y: self.scrollViewProxy!.contentOffset.y + heightDelta)
            self.textInputbarHeightC.constant = inputBarHeight
            self.scrollViewHeightC.constant = self.myp_appropriateScrollViewHeight()
            
            if animated {
                let shouldBounces = self.bounces && self.textView.isFirstResponder
                
                self.view.myp_animateLayoutIfNeeded(withBounce: shouldBounces, options: [UIViewAnimationOptions.curveEaseInOut, .layoutSubviews, .beginFromCurrentState], animations: {
                    if !self.isInverted {
                        self.scrollViewProxy?.contentOffset = newOffset
                    }
                })
            }
            else {
                self.view.layoutIfNeeded()
            }
        }
        
        // Toggles auto-correction if requiered
        self.myp_enableTypingSuggestionIfNeeded()
    }
    
    /**
     Notifies the view controller that the text selection did change.
     Use this method a replacement of UITextViewDelegate's -textViewDidChangeSelection: which is not reliable enough when using third-party keyboards (they don't forward events properly sometimes).
     
     You can override this method to perform additional tasks associated with text changes.
     You MUST call super at some point in your implementation.
     */
    func textSelectionDidChange() {
        // The text view must be first responder
        if !self.textView.isFirstResponder || self.keyboardStatus != .didShow {
            return
        }
        
        // Skips there is a real text selection
        if self.textView.isTrackpadEnabled {
            return
        }
        
        if self.textView.selectedRange.length > 0 {
            if self.isAutoCompleting && self.shouldProcessTextForAutoCompletion() {
                self.cancelAutoCompletion()
            }
            return
        }
        
        // Process the text at every caret movement
        self.myp_processtextForAutoCompletion()
    }
    
    /**
     Notifies the view controller when the left button's action has been triggered, manually.
     You can override this method to perform additional tasks associated with the left button.
     You don't need call super since this method doesn't do anything.
     */
    @objc func didPressLeftButton(sender: UIButton) {
        // do nothing here. override it in subclass
    }
    
    @objc func didPressRightButton(sender: UIButton) {
        // do nothing here. override it in subclass
    }
    
    @objc func didPressRightMoreButton(sender: UIButton) {
        // do nothing here. override it in subclass
    }
    
    /**
     Notifies the view controller when the send button's action has been triggered, manually or by using the keyboard return key.
     You can override this method to perform additional tasks associated with the send button.
     You MUST call super at some point in your implementation.
     */
    @objc func didPressSendButton(sender: UIButton) {
        if self.shouldClearTextAtSendButtonPress {
            self.textView.myp_clearText(shouldClearUndo: true)
        }
        
        // Clears cache
        self.clearCachedText()
        
    }
    
    /**
     Verifies if the right button can be pressed. If false, the button is disabled.
     You can override this method to perform additional tasks. You SHOULD call super to inherit some conditionals.
     We do not use it here. we use shouldEnableSendButton in MYPTextInputbarView.
     we could open this api to enable/disable outside MYPTextInputbarView, and remove the inside control.
     
     - Returns: true if the right button can be pressed.
     */
    func canPressSendButton() -> Bool {
        let text = self.textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if text.count > 0 && !self.textInputbar.isLimitExceeded {
            return true
        }
        return false
    }
    
    private func myp_performSendAction() {
        let actions = self.sendButton.actions(forTarget: self, forControlEvent: .touchUpInside)
        
        if actions?.count ?? 0 > 0 && self.canPressSendButton() {
            self.sendButton.sendActions(for: .touchUpInside)
        }
    }
    
    /**
     Notifies the view controller when the user has pasted a supported media content (images and/or videos).
     Not supported yet now.
     You can override this method to perform additional tasks associated with image/video pasting.
     You don't need to call super since this method doesn't do anything.
     Only supported pastable medias configured in MYPTextView will be forwarded (take a look at MYPPastableMediaType).
     
     - Parameters:
         - userInfo: The payload containing the media data, content and media types.
     */
    func didPasteMediaContent(userInfo: [String: Any]) {
        // not supported yet now
    }
    
    /**
     Notifies the view controller when the user has shaked the device for undoing text typing.
     You can override this method to perform additional tasks associated with the shake gesture.
     Calling super will prompt a system alert view with undo option. This will not be called if 'undoShakingEnabled' is set to false and/or if the text view's content is empty.
     */
    func willRequestUndo() {
        let aTitle = NSLocalizedString("Undo Typing", comment: "")
        let acceptTitle = NSLocalizedString("Undo", comment: "")
        let cancelTitle = NSLocalizedString("Cancel", comment: "")
        
        let alertController = UIAlertController(title: aTitle, message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: acceptTitle, style: .default, handler: {(_ action: UIAlertAction?) -> Void in
            // Clears the text but doesn't clear the undo manager
            if self.isShakeToClearEnabled {
                self.textView.myp_clearText(shouldClearUndo: false)
            }
        }))
        alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel, handler: nil))
        present(alertController, animated: true) {() -> Void in }
    }
    
    //MARK: Keyboard Events
    
    /**
     Notifies the view controller when the user has pressed the Return key (↵) with an external keyboard.
     You can override this method to perform additional tasks.
     You MUST call super at some point in your implementation.
     
     - Parameters:
         - keyCommand: The UIKeyCommand object being recognized.
     */
    func didPressReturnKey(_ keyCommand: UIKeyCommand?) {
        // TODO: we need to change it into insert "\n", not a send action
        self.myp_performSendAction()
    }
    
    /**
     Notifies the view controller when the user has pressed the Escape key (Esc) with an external keyboard.
     You can override this method to perform additional tasks.
     You MUST call super at some point in your implementation.
     
     - Parameters:
         - keyCommand: The UIKeyCommand object being recognized.
     */
    func didPressEscapeKey(_ keyCommand: UIKeyCommand?) {
        if self.isAutoCompleting {
            self.cancelAutoCompletion()
        }
        
        let bottomMargin = self.myp_appropriateBottomMargin()
        
        if self.ignoreTextInputbarAdjustment() || (self.textView.isFirstResponder && self.keyboardHeightC.constant == bottomMargin) {
            return
        }
        
        self.dismissKeyboard(animated: true)
    }
    
    /**
     Notifies the view controller when the user has pressed the arrow key with an external keyboard.
     You can override this method to perform additional tasks.
     You MUST call super at some point in your implementation.
     
     - Parameters:
         - keyCommand: The UIKeyCommand object being recognized.
     */
    func didPressArrowKey(_ keyCommand: UIKeyCommand?) {
        if keyCommand == nil {
            return
        }
        self.textView.didPressArrowKey(keyCommand!)
    }
    
    private func myp_registerKeyCommands() {
        weak var weakSelf = self
        
        // Enter Key
        self.textView.observe(keyInput: "\r", modifiers: UIKeyModifierFlags(rawValue: 0), title: NSLocalizedString("Send/Accept", comment: "Send")) { (keyCommand) in
            weakSelf?.didPressReturnKey(keyCommand)
        }
        
        // Esc Key
        self.textView.observe(keyInput: UIKeyInputEscape, modifiers: UIKeyModifierFlags(rawValue: 0), title: NSLocalizedString("Dismiss", comment: "Dismiss")) { (keyCommand) in
            weakSelf?.didPressEscapeKey(keyCommand)
        }
        
        // Up Arrow
        self.textView.observe(keyInput: UIKeyInputUpArrow, modifiers: UIKeyModifierFlags(rawValue: 0), title: nil) { (keyCommand) in
            weakSelf?.didPressArrowKey(keyCommand)
        }
        
        // Down Arrow
        self.textView.observe(keyInput: UIKeyInputDownArrow, modifiers: UIKeyModifierFlags(rawValue: 0), title: nil) { (keyCommand) in
            weakSelf?.didPressArrowKey(keyCommand)
        }
    }
    
    @objc private func myp_didPanTextInputBar(recognizer: UIPanGestureRecognizer) {
        print("Message Controller: didPanTextInputBar")
        // Textinput dragging isn't supported when
        if self.view.window == nil || !self.isKeyboardPanningEnabled || self.ignoreTextInputbarAdjustment() || self.isPresentedInPopover {
            return
        }
        print("Message Controller: handlePanGestureRecognizer")
        DispatchQueue.main.async {
            self.myp_handlePanGestureRecognizer(recognizer)
        }
    }
    
    @objc private func myp_didTapScrollView(recognizer: UIPanGestureRecognizer) {
        if !self.isPresentedInPopover && !self.ignoreTextInputbarAdjustment() {
            self.dismissKeyboard(animated: true)
        }
    }
    // TODO: didPanScrollView!!!
    /** This is not used?!
    @objc private func myp_didPanTextView(recognizer: UIPanGestureRecognizer) {
        print("Message Controller: didPanTextView")
        self.presentKeyboard(animated: true)
    }
    */
    private var startPoint = CGPoint.zero
    private var originFrame = CGRect.zero
    private var isDragging = false
    private var isPresenting = false
    private var keyboardView: UIView? {
        return self.textInputbar.inputAccessoryView.keyboardViewProxy
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
                var offset = self.scrollViewOffsetBeforeDragging!
                
                if self.isInverted {
                    if !self.scrollViewProxy!.isDecelerating && self.scrollViewProxy!.isTracking {
                        self.scrollViewProxy!.contentOffset = self.scrollViewOffsetBeforeDragging!
                    }
                }
                else {
                    let heightDelta = self.keyboardHeightBeforeDragging! - self.keyboardHeightC.constant
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
    var textInputbarHidden: Bool {
        get {
            return self.textInputbar.isHidden
        }
        set {
            self.setTextInputbarHidden(newValue, animated: false)
        }
    }
    
    /**
     Changes the visibility of the text input bar.
     Calling this method with the animated parameter set to NO is equivalent to setting the value of the toolbarHidden property directly.
     
     - Parameters:
         - hidden: Specify true to hide the toolbar or false to show it.
         - animated: Specify true if you want the toolbar to be animated on or off the screen.
     */
    func setTextInputbarHidden(_ hidden: Bool, animated: Bool) {
        if self.textInputbarHidden == hidden {
            return
        }
        
        self.textInputbar.isHidden = hidden
        
        if #available(iOS 11.0, *) {
            self.viewSafeAreaInsetsDidChange()
        }
        
        weak var weakSelf = self
        
        if animated {
            UIView.animate(withDuration: 0.25, animations: {
                weakSelf!.textInputbarHeightC.constant = hidden ? 0.0 : weakSelf!.textInputbar.appropriateHeight
                weakSelf!.view.layoutIfNeeded()
            }) { (finished) in
                if hidden {
                    self.dismissKeyboard(animated: true)
                }
            }
        }
        else {
            self.textInputbarHeightC.constant = hidden ? 0.0 : self.textInputbar.appropriateHeight
            self.view.layoutIfNeeded()
            
            if hidden {
                self.dismissKeyboard(animated: false)
            }
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
    var autoCompletionView: UITableView {
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
    private(set) var isAutoCompleting = false {
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
    private(set) var registeredPrefixes: Set<String>?
    
    /**
     Registers any string prefix for autocompletion detection, like for user mentions or hashtags autocompletion.
     The prefix must be valid string (i.e: '@', '#', '\', and so on).
     Prefixes can be of any length.
     */
    func registerPrefixesForAutoCompletion(with prefixes: [String]?) {
        if prefixes?.count ?? 0 == 0 {
            return
        }
        
        var aSet = self.registeredPrefixes ?? Set<String>()
        if let x = prefixes {
            let otherSet = Set(x)
            for a in otherSet {
                aSet.insert(a)
            }
        }
        
        self.registeredPrefixes = aSet
    }
    
    /**
     Verifies that controller is allowed to process the textView's text for auto-completion.
     You can override this method to disable momentarily the auto-completion feature, or to let it visible for longer time.
     You SHOULD call super to inherit some conditionals.
     
     - Returns: true if the controller is allowed to process the text for auto-completion.
     */
    func shouldProcessTextForAutoCompletion() -> Bool {
        if self.registeredPrefixes == nil || (self.registeredPrefixes?.count ?? 0) == 0 {
            return false
        }
        return true
    }
    
    /**
     During text autocompletion, by default, auto-correction and spell checking are disabled.
     Doing so, refreshes the text input to get rid of the Quick Type bar.
     You can override this method to avoid disabling in some cases.
     
     - Returns: true if the controller should not hide the quick type bar.
     */
    func shouldDisableTypingSuggestionForAutoCompletion() -> Bool {
        if self.registeredPrefixes == nil || (self.registeredPrefixes?.count ?? 0) == 0 {
            return false
        }
        
        return true
    }
    
    /**
     Notifies the view controller either the autocompletion prefix or word have changed.
     Use this method to modify your data source or fetch data asynchronously from an HTTP resource.
     Once your data source is ready, make sure to call -showAutoCompletionView: to display the view accordingly.
     You don't need call super since this method doesn't do anything.
     You SHOULD call super to inherit some conditionals.
     
     - Parameters:
         - prefix: The detected prefix.
         - word: The detected word.
     */
    func didChangeAutoCompletionPrefix(_ prefix: String?, andWord word: String?) {
        // override in subclass
    }
    
    /**
     Use this method to programatically show/hide the autocompletion view.
     Right before the view is shown, -reloadData is called. So avoid calling it manually.
     
     - Parameters:
         - show: true if the autocompletion view should be shown.
     */
    func showAutoCompletionView(_ show: Bool) {
        // Reloads the tableview before showing/hiding
        if show {
            self.autoCompletionView.reloadData()
        }
        
        self.isAutoCompleting = show
        
        // Toggles auto-correction if requiered
        self.myp_enableTypingSuggestionIfNeeded()
        
        var viewHeight = show ? self.heightForAutoCompletionView() : 0.0
        
        if self.autoCompletionViewHeightC.constant == viewHeight {
            return
        }
        
        // If the auto-completion view height is bigger than the maximum height allows, it is reduce to that size. Default 140 pts.
        let maxHeight = self.maximumHeightForAutoCompletionView()
        
        if viewHeight > maxHeight {
            viewHeight = maxHeight
        }
        
        let contentViewHeight = self.scrollViewHeightC.constant + self.autoCompletionViewHeightC.constant
        
        // On iPhone, the auto-completion view can't extend beyond the content view height
        if MYP_IS_IPHONE && viewHeight > contentViewHeight {
            viewHeight = contentViewHeight
        }
        
        self.autoCompletionViewHeightC.constant = viewHeight
        
        self.view.myp_animateLayoutIfNeeded(withBounce: self.bounces, options: [.curveEaseInOut, .layoutSubviews, .beginFromCurrentState, .allowUserInteraction], animations: nil)
    }
    
    /**
     Use this method to programatically show the autocompletion view, with provided prefix and word to search.
     Right before the view is shown, -reloadData is called. So avoid calling it manually.
     
     - Parameters:
         - prefix: A prefix that is used to trigger autocompletion
         - word: A word to search for autocompletion
         - prefixRange: The range in which prefix spans.
     */
    func showAutoCompletionView(withPrefix prefix: String, word: String, prefixRange: NSRange) {
        if self.registeredPrefixes?.contains(prefix) ?? false {
            self.foundPrefix = prefix
            self.foundWord = word
            self.foundPrefixRange = prefixRange
            
            self.didChangeAutoCompletionPrefix(self.foundPrefix, andWord: self.foundWord)
            
            self.showAutoCompletionView(true)
        }
    }
    
    /**
     Returns a custom height for the autocompletion view. Default is 0.0.
     You can override this method to return a custom height.
     
     - Returns: The autocompletion view's height.
     */
    func heightForAutoCompletionView() -> CGFloat {
        return 0.0
    }
    
    /**
     Returns the maximum height for the autocompletion view. Default is 140 pts.
     You can override this method to return a custom max height.
     
     - Returns: The autocompletion view's max height.
     */
    func maximumHeightForAutoCompletionView() -> CGFloat {
        var maxHeight = MYPAutoCompletionViewDefaultHeight
        
        if self.isAutoCompleting {
            var scrollHeight = self.scrollViewHeightC.constant
            scrollHeight -= self.myp_topBarsHeight()
            
            if scrollHeight < maxHeight {
                maxHeight = scrollHeight
            }
        }
        
        return maxHeight
    }
    
    /**
     Cancels and hides the autocompletion view, animated.
     */
    func cancelAutoCompletion() {
        self.myp_invalidateAutoCompletion()
        self.myp_hideAutoCompletionViewIfNeeded()
    }
    
    /**
     Accepts the autocompletion, replacing the detected word with a new string, keeping the prefix.
     This method is a convinience of -acceptAutoCompletionWithString:keepPrefix:
     
     - Parameters:
         - string: The string to be used for replacing autocompletion placeholders.
     */
    func acceptAutoCompletion(with string: String?) {
        self.acceptAutoCompletion(with: string, keepPrefix: true)
    }
    
    /**
     Accepts the autocompletion, replacing the detected word with a new string, and optionally replacing the prefix too.
     
     - Parameters:
         - string: The string to be used for replacing autocompletion placeholders.
         - keepPrefix: YES if the prefix shouldn't be overidden.
     */
    func acceptAutoCompletion(with string: String?, keepPrefix: Bool) {
        if string?.isEmpty ?? false {
            return
        }
        
        var location = self.foundPrefixRange.location
        if keepPrefix {
            location += self.foundPrefixRange.length
        }
        
        var length = self.foundWord?.count ?? 0
        if !keepPrefix {
            length += self.foundPrefixRange.length
        }
        
        let range = NSRange(location: location, length: length)
        let insertionRange = self.textView.myp_insert(text: string!, in: range)
        
        self.textView.selectedRange = NSRange(location: insertionRange.location, length: 0)
        
        self.textView.myp_scrollToCaretPosition(animated: false)
        
        self.cancelAutoCompletion()
    }
    
    private func myp_processtextForAutoCompletion() {
        let text: String = self.textView.text
        if (!self.isAutoCompleting && text.count == 0) || self.isTransitioning || !self.shouldProcessTextForAutoCompletion() {
            return
        }
        
        self.textView.look(for: self.registeredPrefixes) { (prefix, word, wordRange) in
            if prefix?.count ?? 0 > 0 && word?.count ?? 0 > 0 {
                // Captures the detected symbol prefix
                self.foundPrefix = prefix!
                
                // Removes the found prefix, or not.
                let index = word!.index(word!.startIndex, offsetBy: prefix!.count)
                self.foundWord = String(word![index...])
                
                // Used later for replacing the detected range with a new string alias returned in -acceptAutoCompletionWithString:
                self.foundPrefixRange = NSMakeRange(wordRange
                    .location, prefix!.count)
                
                self.myp_handleProcessedWord(word!, wordRange: wordRange)
            }
            else {
                self.cancelAutoCompletion()
            }
        }
    }
    
    private func myp_handleProcessedWord(_ word: String, wordRange: NSRange) {
        // Cancel auto-completion if the cursor is placed before the prefix
        if self.textView.selectedRange.location <= self.foundPrefixRange.location {
            self.cancelAutoCompletion()
            return
        }
        
        if self.foundPrefix?.count ?? 0 > 0 {
            if wordRange.length == 0 || wordRange.length != word.count {
                self.cancelAutoCompletion()
                return
            }
            
            if word.count > 0 {
                // If the prefix is still contained in the word, cancels
                if !self.foundWord!.contains(self.foundPrefix!) {
                    self.cancelAutoCompletion()
                    return
                }
            }
            else {
                self.cancelAutoCompletion()
                return
            }
        }
        else {
            self.cancelAutoCompletion()
            return
        }
        
        self.didChangeAutoCompletionPrefix(self.foundPrefix, andWord: self.foundWord)
    }
    
    private func myp_hideAutoCompletionViewIfNeeded() {
        if self.isAutoCompleting {
            self.showAutoCompletionView(false)
        }
    }
    
    private func myp_invalidateAutoCompletion() {
        self.foundPrefix = nil
        self.foundWord = nil
        self.foundPrefixRange = NSMakeRange(0, 0)
        
        self.autoCompletionView.contentOffset = .zero
    }
    
    //MARK: text cache
    /**
     Returns the key to be associated with a given text to be cached. Default is nil.
     To enable text caching, you must override this method to return valid key.
     The text view will be populated automatically when the view controller is configured.
     You don't need to call super since this method doesn't do anything.
     
     - Returns: The string key for which to enable text caching.
     */
    func keyForTextCaching() -> String? {
        // No implementation here. Meant to be overriden in subclass.
        return nil
    }
    
    private func myp_keyForPersistency() -> String? {
        let key = self.keyForTextCaching()
        
        if key == nil {
            return nil
        }
        
        return MYPTextInputVCDomain + "." + key!
    }
    
    /**
     Removes all the cached text from disk.
     */
    class func clearAllCachedText() {
        var cachedKeys = [String]()
        
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.contains(MYPTextInputVCDomain) {
                cachedKeys.append(key)
            }
        }
        
        if cachedKeys.count == 0 {
            return
        }
        
        for key in cachedKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        UserDefaults.standard.synchronize()
    }
    
    /**
     Removes the current view controller's cached text.
     To enable this, you must return a valid key string in -keyForTextCaching.
     */
    func clearCachedText() {
        self.myp_cacheAttributedTextToDisk(nil)
    }
    
    /**
     Caches text to disk.
     */
    @objc func cacheTextView() {
        self.myp_cacheAttributedTextToDisk(self.textView.attributedText)
    }
    
    private func myp_cacheAttributedTextToDisk(_ attributedText: NSAttributedString?) {
        let key = self.myp_keyForPersistency()
        if key == nil || key?.count == 0 {
            return
        }
        
        var cachedAttributedText = NSAttributedString(string: "")
        
        let obj = UserDefaults.standard.object(forKey: key!)
        
        if obj != nil {
            if obj is String {
                cachedAttributedText = NSAttributedString(string: obj as! String)
            }
            else if obj is Data {
                cachedAttributedText = NSKeyedUnarchiver.unarchiveObject(with: obj as! Data) as! NSAttributedString
            }
        }
        
        // Caches text only if its a valid string and not already cached
        if attributedText?.length ?? 0 > 0 && attributedText != cachedAttributedText {
            let data = NSKeyedArchiver.archivedData(withRootObject: attributedText!)
            UserDefaults.standard.set(data, forKey: key!)
        }
        // Clears cache only if it exists
        else if attributedText?.length == 0 && cachedAttributedText.length > 0 {
            UserDefaults.standard.removeObject(forKey: key!)
        }
        else {
            // Skips so it doesn't hit 'synchronize' unnecessarily
            return
        }
        
        UserDefaults.standard.synchronize()
    }
    
    private func myp_cacheTextToDisk(_ text: String) {
        let key = self.myp_keyForPersistency()
        if key == nil || key?.count == 0 {
            return
        }
        
        let attributedText = NSAttributedString(string: text)
        self.myp_cacheAttributedTextToDisk(attributedText)
    }
    
    //MARK: delegate methods requiring super
    /** UITextViewDelegate */
    open func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if !(textView is MYPTextView) {
            return true
        }
        
        let textView = textView as! MYPTextView
        
        let newWordInserted = !(text.rangeOfCharacter(from: .whitespacesAndNewlines)?.isEmpty ?? true)
        
        // Records text for undo for every new word
        if newWordInserted {
            textView.myp_prepareForUndo(description: "Word Change")
        }
        
        if text == "\n" {
            textView.myp_insertNewLineBreak()
            
            return false
        }
        else {
            let dict = ["text": text, "range": range] as [String : Any]
            NotificationCenter.default.post(name: Notification.Name.MYPTextInputTask.MYPTextViewTextWillChangeNotification, object: self, userInfo: dict)
            
            return true
        }
    }
    
    open func textViewDidChange(_ textView: UITextView) {
        // Keep to avoid unnecessary crashes. Was meant to be overriden in subclass while calling super.
    }
    
    open func textViewDidChangeSelection(_ textView: UITextView) {
        // Keep to avoid unnecessary crashes. Was meant to be overriden in subclass while calling super.
    }
    
    open func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        return true
    }
    
    open func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        return true
    }
    
    open func textViewDidBeginEditing(_ textView: UITextView) {
        // No implementation here. Meant to be overriden in subclass.
    }
    
    open func textViewDidEndEditing(_ textView: UITextView) {
        // No implementation here. Meant to be overriden in subclass.
    }
    
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
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
