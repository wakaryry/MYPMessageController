//
//  MYPMessageController+LifeCycle.swift
//  MYPMessageController
//
//  Created by wakary redou on 2018/5/16.
//

import Foundation

extension MYPMessageController {
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
        self.view.addSubview(self.emotionView)
        self.view.addSubview(self.moreView)
        
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
        
        let views = ["scrollView": scrollViewProxy!, "autoCompletionView": autoCompletionView, "textInputbar": textInputbar, "emotionView": emotionView, "moreView": moreView]
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[scrollView(0@750)]-0@999-[textInputbar(>=0)]|", options: [], metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=0)-[autoCompletionView(0@750)]-0@999-[textInputbar]", options: [], metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[textInputbar]-0-[emotionView(>=0)]", options: [], metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[textInputbar]-0-[moreView(>=0)]", options: [], metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[scrollView]|", options: [], metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[autoCompletionView]|", options: [], metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[textInputbar]|", options: [], metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[emotionView]|", options: [], metrics: nil, views: views))
        
        view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[moreView]|", options: [], metrics: nil, views: views))
        
        scrollViewHeightC = view.myp_constraint(for: .height, firstItem: scrollViewProxy, secondItem: nil)!
        autoCompletionViewHeightC = view.myp_constraint(for: .height, firstItem: autoCompletionView, secondItem: nil)!
        textInputbarHeightC = view.myp_constraint(for: .height, firstItem: textInputbar, secondItem: nil)!
        keyboardHeightC = view.myp_constraint(for: .bottom, firstItem: view, secondItem: textInputbar)!
        
        self.myp_updateViewConstraints()
        
    }
    
    internal func myp_updateViewConstraints() {
        self.textInputbarHeightC.constant = self.textInputbar.minimumInputbarHeight
        self.scrollViewHeightC.constant = self.myp_appropriateScrollViewHeight()
        self.keyboardHeightC.constant = self.myp_appropriateKeyboardHeight(from: CGRect.null)
        
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
}
