//
//  MYPMessageController+CollectionViewDelegate.swift
//  MYPTextInputVC
//
//  Created by wakary redou on 2018/5/9.
//  Copyright © 2018年 wakary redou. All rights reserved.
//

import UIKit

extension MYPMessageController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = UICollectionViewCell()
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 0
    }
    
    
}
