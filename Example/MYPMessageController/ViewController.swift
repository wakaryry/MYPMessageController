//
//  ViewController.swift
//  MYPMessageController
//
//  Created by mayuping321@163.com on 05/14/2018.
//  Copyright (c) 2018 mayuping321@163.com. All rights reserved.
//

import UIKit
import MYPMessageController

class ViewController: UIViewController {

    @IBOutlet weak var textInputbar: MYPTextInputbarView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func dismissKeyboard(_ sender: UIBarButtonItem) {
        //self.textInputbar.
    }
    
    @IBAction func toCode(_ sender: UIBarButtonItem) {
    }
}

