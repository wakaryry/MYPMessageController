//
//  MYPMessageController+CacheText.swift
//  MYPMessageController
//
//  Created by wakary redou on 2018/5/16.
//

import Foundation

extension MYPMessageController {
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
    
    internal func myp_keyForPersistency() -> String? {
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
}
