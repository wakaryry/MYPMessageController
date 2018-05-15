//
//  StoryboardVC.swift
//  MYPMessageController_Example
//
//  Created by wakary redou on 2018/5/14.
//  Copyright © 2018年 CocoaPods. All rights reserved.
//

import UIKit
import MYPMessageController

class StoryboardVC: MYPMessageController {
    
    var his = [
        "荣华梦一场，功名纸半张，是非海波千丈，马蹄踏碎禁街霜，听几度头鸡唱。尘土衣冠，江湖心量。出皇家麟凤网，慕夷齐首阳，叹韩彭未央。早纳纸风魔状。",
        "折梅逢驿使，寄与陇头人。江南无所有，聊赠一枝春。",
        "浪花有意千重雪，桃李无言一队春。",
        "燕子不归春事晚，一汀烟雨杏花寒。",
        "今夜偏知春气暖，虫声新透绿窗纱。",
        "况是青春日将暮，桃花乱落如红雨。",
        "耶溪采莲女，见客棹歌回。 笑入荷花去，佯羞不出来。",
        "砌下落花风起，罗衣特地春寒。",
        "我是梦中传彩笔，欲书花叶寄朝云。",
        "长安豪贵惜春残，争赏街西紫牡丹。别有玉盘承露冷，无人起就月中看。",
        "细雨湿衣看不见，闲花落地听无声。",
        "雨恨云愁，江南依旧称佳丽。水村渔市。一缕孤烟细。天际征鸿，遥认行如缀。平生事。此时凝睇。谁会凭阑意。",
        "竹摇清影罩幽窗，两两时禽噪夕阳。谢却海棠飞尽絮，困人天气日初长。",
        "世路如今已惯，此心到处悠然。寒光亭下水如天，飞起沙鸥一片。",
        "雪似梅花，梅花似雪。似和不似都奇绝。恼人风味阿谁知？请君问取南楼月。记得去年，探梅时节。老来旧事无人说。为谁醉倒为谁醒？到今犹恨轻离别。",
        "瑶草一何碧，春入武陵溪。溪上桃花无数，花上有黄鹂，我欲穿花寻路，直入白云深处，浩气展虹霓。只恐花深里，红露湿人衣。坐玉石，欹玉枕，拂金徽。谪仙何处，天人伴我白螺杯。我为灵芝仙草，不为朱唇丹脸，长啸亦何为！醉舞下山去，明月逐人归。"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "FXXXX")
        //cell.detailTextLabel?.text = his[indexPath.row]
        cell.textLabel?.text = his[indexPath.row]
        cell.transform = tableView.transform
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return his.count
    }
    
    override func didPressSendButton(sender: UIButton) {
        his.insert(self.textView.text, at: 0)
        self.tableView?.insertRows(at: [IndexPath(row: 0, section: 0)], with: UITableViewRowAnimation.bottom)
        //self.tableView?.reloadData()
        
        super.didPressSendButton(sender: sender)
    }
    
    @IBAction func toCode(_ sender: UIBarButtonItem) {
        self.navigationController?.pushViewController(ViewController(), animated: true)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
