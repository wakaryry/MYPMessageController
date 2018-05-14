//
//  MYPTextView+MYPAddition.swift
//  MYPTextInputVC
//
//  Created by wakary redou on 2018/4/23.
//  Copyright © 2018年 wakary redou. All rights reserved.
//

import UIKit

extension MYPTextView {
    /**
     Clears the text.
     
     - Parameters:
         - shouldClearUndo: true if clearing the text should also clear the undo manager (if enabled).
     */
    func myp_clearText(shouldClearUndo: Bool) {
        self.attributedText = NSAttributedString()
        if self.isUndoManagerEnabled && shouldClearUndo {
            self.undoManager?.removeAllActions()
        }
    }
    
    /**
     Scrolls to the very end of the content size, animated.
     
     - Parameters:
         - animated: true if the scrolling should be animated.
     */
    func myp_textViewScrollToBottom(animated: Bool) {
        var rect = self.caretRect(for: (self.selectedTextRange?.end)!)
        rect.size.height += self.textContainerInset.bottom
        
        if animated {
            self.scrollRectToVisible(rect, animated: animated)
        }
        else {
            UIView.performWithoutAnimation {
                self.scrollRectToVisible(rect, animated: false)
            }
        }
    }
    
    /**
     Scrolls to the caret position, animated.
     
     - Parameters:
         - animated: true if the scrolling should be animated.
     */
    func myp_scrollToCaretPosition(animated: Bool) {
        if animated {
            self.scrollRangeToVisible(self.selectedRange)
        }
        else {
            UIView.performWithoutAnimation {
                self.scrollRangeToVisible(self.selectedRange)
            }
        }
    }
    
    /**
     Inserts a line break at the caret's position.
     */
    func myp_insertNewLineBreak() {
        self.myp_insertTextAtCaretRange(text: "\n")
        
        // if the text view cannot expand anymore, scrolling to bottom are not animated to fix a UITextView issue scrolling twice.
        let animated = !self.isExpanding
        
        //Detected break. Should scroll to bottom if needed.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.125, execute: {() -> Void in
            self.myp_textViewScrollToBottom(animated: animated)
        })
    }
    
    /**
     Inserts a string at the caret's position.
     
     - Parameters:
         - text: The string to be appended to the current text.
     */
    func myp_insertTextAtCaretRange(text: String) {
        let range = self.myp_insert(text: text, in: self.selectedRange)
        self.selectedRange = NSRange(location: range.location, length: 0)
    }
    
    /**
     Insert a string at the caret's position with stylization from the attributes.
     
     - Parameters:
         - text: The string to be appended to the current text.
         - attributes: The attributes used to stylize the text.
     */
    func myp_insertTextAtCaretRange(text: String, with attributes: [NSAttributedStringKey : Any]?) {
        let range = self.myp_insert(text: text, with: attributes, in: self.selectedRange)
        self.selectedRange = NSMakeRange(range.location, 0)
    }
    
    /**
     Adds a string to a specific range.
     
     - Parameters:
         - text: The string to be appended to the current text.
         - range: The range where to insert text.
     
     - Returns: The range of the newly inserted text.
     */
    func myp_insert(text: String, in range: NSRange) -> NSRange {
        let attributedString = self.myp_defaultAttributedString(for: text)
        return self.myp_insert(attributedString: attributedString, in: range)
    }
    
    /**
     Adds a string to a specific range, with stylization from the attributes.
     
     - Parameters:
         - text: The string to be appended to the current text.
         - attributes: The attributes used to stylize the text.
         - range: The range where to insert text.
         - Returns: The range of the newly inserted text.
     */
    func myp_insert(text: String, with attributes: [NSAttributedStringKey : Any]?, in range: NSRange) -> NSRange {
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        return self.myp_insert(attributedString: attributedString, in: range)
    }
    
    /**
     Sets the text attributes for the attributed string in the provided range.
     
     - Parameters:
         - attributes: The attributes used to style NSAttributedString class.
         - range: The range of the text that needs to be stylized by the given attributes.
     - Returns: An attributed string.
     */
    func myp_set(attributes: [NSAttributedStringKey : Any]?, in range: NSRange) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: self.attributedText)
        attributedString.setAttributes(attributes, range: range)
        
        self.attributedText = attributedString
        return self.attributedText
    }
    
    /**
     Inserts an attributed string at the caret's position.
     
     - Parameters:
         - attributedText: The attributed string to be appended.
     */
    func myp_insertAttributedStringAtCaretRange(attributedString: NSAttributedString) {
        let range = self.myp_insert(attributedString: attributedString, in: self.selectedRange)
        self.selectedRange = NSMakeRange(range.location, 0)
    }
    
    /**
     Adds an attributed string to a specific range.
     
     - Parameters:
         - attributedString: The string to be appended to the current text.
         - range: The range where to insert text.
     - Returns: The range of the newly inserted text.
     */
    func myp_insert(attributedString: NSAttributedString, in range: NSRange) -> NSRange {
        if attributedString.length == 0 {
            return NSMakeRange(0, 0)
        }
        
        // Registers for undo management
        self.myp_prepareForUndo(description: "Attributed text appending")
        
        // Append the new string at the caret position
        if range.length == 0 {
            let leftAttributedString = self.attributedText.attributedSubstring(from: NSMakeRange(0, range.location))
            let rightAttributedString = self.attributedText.attributedSubstring(from: NSMakeRange(range.location, self.attributedText.length - range.location))
            
            let newAttributedString = NSMutableAttributedString()
            newAttributedString.append(leftAttributedString)
            newAttributedString.append(attributedString)
            newAttributedString.append(rightAttributedString)
            
            self.attributedText = newAttributedString
            return  NSMakeRange(range.location + attributedString.length, range.length) //range.location += attributedString.length
        }
        // Some text is selected, so we replace it with the new text
        else if range.location != NSNotFound && range.length > 0 {
            let mutableAttributedString = NSMutableAttributedString(attributedString: self.attributedText)
            mutableAttributedString.replaceCharacters(in: range, with: attributedString)
            
            self.attributedText = mutableAttributedString
            
            // TODO: we get a textView size bug in paste text. This fix? No!!!!
            // did not scroll to bottom and can not resize the textView when it's not reached maxNumberOfLines.
            //NotificationCenter.default.post(name: Notification.Name.UITextViewTextDidChange, object: self, userInfo: nil)
            
            return NSMakeRange(range.location + self.attributedText.length, range.length)
        }
        
        // No text has been inserted, but still return the caret range
        return self.selectedRange
    }
    
    /**
     Removes all attributed string attributes from the text view, for the given range.
     
     - Parameters:
         - range: The range to remove the attributes.
     */
    func myp_clearAllAttributes(in range: NSRange) {
        let mutableAttributedString = NSMutableAttributedString(attributedString: self.attributedText)
        
        mutableAttributedString.setAttributes(nil, range: range)
        
        self.attributedText = mutableAttributedString
    }
    
    /**
     Returns a default attributed string, using the text view's font and text color.
     
     - Parameters:
         - text: The string to be used for creating a new attributed string.
     - Returns: An attributed string.
     */
    func myp_defaultAttributedString(for text: String) -> NSAttributedString {
        var attributes = [NSAttributedStringKey : Any]()
        
        if let color = self.textColor {
            attributes[NSAttributedStringKey.foregroundColor] = color
        }
        
        if let ft = self.font {
            attributes[NSAttributedStringKey.font] = ft
        }
        return NSAttributedString(string: text, attributes: attributes)
    }
    
    /**
     Registers the current text for future undo actions.
     
     - Parameters:
         - description: A simple description associated with the Undo or Redo command.
     */
    func myp_prepareForUndo(description: String) {
        if !self.isUndoManagerEnabled {
            return
        }
        
        //let prepareInvocation = self.undoManager?.prepare(withInvocationTarget: self) as! MYPTextView
        //prepareInvocation.text = self.text
        undoManager?.registerUndo(withTarget: self, selector: #selector(setter: text), object: self.text)
        
        self.undoManager?.setActionName(description)
    }
}
