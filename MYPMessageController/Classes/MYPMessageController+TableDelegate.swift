//
//  MYPMessageController+TableDelegate.swift
//  MYPTextInputVC
//
//  Created by wakary redou on 2018/5/9.
//  Copyright © 2018年 wakary redou. All rights reserved.
//

import UIKit

extension MYPMessageController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
}
