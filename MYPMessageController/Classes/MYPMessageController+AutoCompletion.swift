//
//  MYPMessageController+AutoCompletion.swift
//  MYPMessageController
//
//  Created by wakary redou on 2018/5/16.
//

fileprivate let MYPAutoCompletionViewDefaultHeight: CGFloat = 140.0

// MARK: Auto Completion
extension MYPMessageController {
    /**
     Registers any string prefix for autocompletion detection, like for user mentions or hashtags autocompletion.
     The prefix must be valid string (i.e: '@', '#', '\', and so on).
     Prefixes can be of any length.
     */
    open func registerPrefixesForAutoCompletion(with prefixes: [String]?) {
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
    open func shouldProcessTextForAutoCompletion() -> Bool {
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
    open func shouldDisableTypingSuggestionForAutoCompletion() -> Bool {
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
    open func didChangeAutoCompletionPrefix(_ prefix: String?, andWord word: String?) {
        // override in subclass
    }
    
    /**
     Use this method to programatically show/hide the autocompletion view.
     Right before the view is shown, -reloadData is called. So avoid calling it manually.
     
     - Parameters:
     - show: true if the autocompletion view should be shown.
     */
    open func showAutoCompletionView(_ show: Bool) {
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
    open func showAutoCompletionView(withPrefix prefix: String, word: String, prefixRange: NSRange) {
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
    open func heightForAutoCompletionView() -> CGFloat {
        return 0.0
    }
    
    /**
     Returns the maximum height for the autocompletion view. Default is 140 pts.
     You can override this method to return a custom max height.
     
     - Returns: The autocompletion view's max height.
     */
    open func maximumHeightForAutoCompletionView() -> CGFloat {
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
    open func cancelAutoCompletion() {
        self.myp_invalidateAutoCompletion()
        self.myp_hideAutoCompletionViewIfNeeded()
    }
    
    /**
     Accepts the autocompletion, replacing the detected word with a new string, keeping the prefix.
     This method is a convinience of -acceptAutoCompletionWithString:keepPrefix:
     
     - Parameters:
     - string: The string to be used for replacing autocompletion placeholders.
     */
    open func acceptAutoCompletion(with string: String?) {
        self.acceptAutoCompletion(with: string, keepPrefix: true)
    }
    
    /**
     Accepts the autocompletion, replacing the detected word with a new string, and optionally replacing the prefix too.
     
     - Parameters:
     - string: The string to be used for replacing autocompletion placeholders.
     - keepPrefix: YES if the prefix shouldn't be overidden.
     */
    open func acceptAutoCompletion(with string: String?, keepPrefix: Bool) {
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
    
    internal func myp_processtextForAutoCompletion() {
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
    
    internal func myp_enableTypingSuggestionIfNeeded() {
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
    
    internal func myp_hideAutoCompletionViewIfNeeded() {
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
}
