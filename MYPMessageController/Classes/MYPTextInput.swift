//
//  MYPTextInput.swift
//  MYPTextInputVC
//
//  Created by wakary redou on 2018/4/20.
//  Copyright © 2018年 wakary redou. All rights reserved.
//

import UIKit

/**
 Classes that adopt the MYPTextInput protocol interact with the text input system and thus acquire features such as text processing.
 All these methods are already implemented in MYPTextInput+IMP.swift
 */
protocol MYPTextInput: UITextInput {
    /**
     - Searches for any matching string prefix at the text input's caret position.
     - When nothing found, the completion block returns nil values.
     - This implementation is internally performed on a background thread and forwarded to the main thread once completed.
     
     - Parameters:
         - prefixes: A set of prefixes to search for.
         - completion: A completion block called whenever the text processing finishes, successfuly or not. Required.
     - Returns: void
     */
    func look(for prefixes: Set<String>?, completion: @escaping (_ prefix: String?, _ word: String?, _ wordRange: NSRange) -> Void)
    
    /**
     Finds the word close to the caret's position, if any.
     
     - Parameters:
         - range: Returns the range of the found word.
     - Returns: The found word.
     */
    func word(atCaret range: inout NSRange) -> String?
    
    /**
     Finds the word close to specific range.
     
     - Parameters:
         - range: The range to be used for searching the word.
         - rangePointer: returns the range of the found word.
     - Returns: The found word.
     */
    func word(at range: NSRange, rangeInText rangePointer: inout NSRange) -> String?
    
}

extension MYPTextInput {
    func look(for prefixes: Set<String>?, completion: @escaping (_ prefix: String?, _ word: String?, _ wordRange: NSRange) -> Void) {
        
        if (prefixes?.count ?? 0) == 0 {
            return
        }
        var wordRange = NSRange()
        let word = self.word(atCaret: &wordRange)
        
        if (word?.count ?? 0) > 0 {
            for prefix in prefixes! {
                if word!.hasPrefix(prefix) {
                    completion(prefix, word, wordRange)
                    return
                }
            }
        }
        
        completion(nil, nil, NSRange(location: 0, length: 0))
        
    }
    
    func word(atCaret range: inout NSRange) -> String? {
        return word(at: myp_caretRange(), rangeInText: &range)
    }
    
    func word(at range: NSRange, rangeInText rangePointer: inout NSRange) -> String? {
        
        let location = Int(range.location)
        
        if location == NSNotFound {
            return nil
        }
        
        let text = myp_text()
        
        // Aborts in case minimum requieres are not fufilled
        if (text?.count ?? 0) == 0 || location < 0 || Int((range.location + range.length)) > (text?.count ?? 0) {
            rangePointer = NSRange(location: 0, length: 0)
            return nil
        }
        
        //let leftPortion = (text! as NSString).substring(to: location)
        let index: String.Index = text!.index(text!.startIndex, offsetBy: location)
        let leftPortion = String(text![...index])
        let leftComponents = leftPortion.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        let leftWordPart = leftComponents.last
        
        //let rightPortion = (text! as NSString).substring(from: location)
        let rightPortion = String(text![index...])
        let rightComponents = rightPortion.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        let rightPart = rightComponents.first
        
        if location > 0 {
            //let characterBeforeCursor = (text as NSString?)?.substring(with: NSRange(location: location - 1, length: 1))
            let beforeIndex = text!.index(text!.startIndex, offsetBy: location - 1)
            let characterBeforeCursor = String(text![beforeIndex...index])
            let whitespaceRange: NSRange? = (characterBeforeCursor as NSString?)?.rangeOfCharacter(from: CharacterSet.whitespaces)
            
            if Int(whitespaceRange?.length ?? 0) == 1 {
                // At the start of a word, just use the word behind the cursor for the current word
                rangePointer = NSRange(location: location, length: rightPart?.count ?? 0)
                
                return rightPart
            }
        }
        
        // In the middle of a word, so combine the part of the word before the cursor, and after the cursor to get the current word
        rangePointer = NSRange(location: location - (leftWordPart?.count ?? 0), length: (leftWordPart?.count ?? 0) + (rightPart?.count ?? 0))
        
        var word = leftWordPart ?? "" + (rightPart ?? "")
        let linebreak = "\n"
        
        // If a break is detected, return the last component of the string
        if Int((word as NSString).range(of: linebreak).location) != NSNotFound {
            if let aWord = (text as NSString?)?.range(of: word) {
                rangePointer = aWord
            }
            word = word.components(separatedBy: linebreak).last ?? ""
        }
        return word
    }
    
    private func myp_text() -> String? {
        
        var textRange: UITextRange? = nil
        let aDocument = self.beginningOfDocument
        let aDocument1 = self.endOfDocument
        textRange = self.textRange(from: aDocument, to: aDocument1)
        
        if let aRange = textRange {
            return self.text(in: aRange)
        }
        return nil
    }
    
    private func myp_caretRange() -> NSRange {
        
        let beginning: UITextPosition? = self.beginningOfDocument
        let selectedRange: UITextRange? = self.selectedTextRange
        let selectionStart: UITextPosition? = selectedRange?.start
        let selectionEnd: UITextPosition? = selectedRange?.end
        var location: Int? = nil
        if let aBeginning = beginning, let aStart = selectionStart {
            location = self.offset(from: aBeginning, to: aStart)
        }
        var length: Int? = nil
        if let aStart = selectionStart, let anEnd = selectionEnd {
            length = self.offset(from: aStart, to: anEnd)
        }
        return NSRange(location: location ?? 0, length: length ?? 0)
    }
}
