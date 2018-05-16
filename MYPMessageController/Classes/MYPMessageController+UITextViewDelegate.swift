//
//  MYPMessageController+UITextViewDelegate.swift
//  MYPMessageController
//
//  Created by wakary redou on 2018/5/16.
//

import UIKit

extension MYPMessageController {
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
}
