//
//  MYPMoreView.swift
//  MYPMessageController
//
//  Created by wakary redou on 2018/5/18.
//

import Foundation

open class MYPMoreView: MYPXibView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        commonSetting()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        commonSetting()
    }
    
    override init() {
        super.init()
        
        commonSetting()
    }
    
    private func commonSetting() {
        
    }
}
