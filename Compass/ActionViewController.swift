//
//  ActionViewController.swift
//  Compass
//
//  Created by Ismael Alonso on 5/31/16.
//  Copyright © 2016 Tennessee Data Commons. All rights reserved.
//

import UIKit
import Just
import ObjectMapper


class ActionViewController: UIViewController{
    //Data
    var upcomingAction: UpcomingAction? = nil;
    
    //UI components
    @IBOutlet weak var hero: UIImageView!
    @IBOutlet weak var actionTitle: UILabel!
    @IBOutlet weak var behaviorTitle: UILabel!
    @IBOutlet weak var actionDescription: UILabel!
    @IBOutlet weak var rescheduleButton: UIButton!
    @IBOutlet weak var rewardHeader: UILabel!
    @IBOutlet weak var rewardContent: UILabel!
    @IBOutlet weak var rewardAuthor: UILabel!
    
    
    override func viewDidLoad(){
        Just.get(API.getActionUrl(upcomingAction!.getId()), headers: SharedData.getUser()!.getHeaderMap()) { (response) in
            if (response.ok){
                let action = Mapper<UserAction>().map(String(data: response.content!, encoding:NSUTF8StringEncoding)!);
                self.fetchCategory(action!.getPrimaryCategoryId());
            }
        };
    }
    
    private func fetchCategory(categoryId: Int){
        Just.get(API.getUserCategoryUrl(categoryId), headers: SharedData.getUser()!.getHeaderMap()) { (response) in
            if (response.ok){
                //let category = Mapper
            }
        }
    }
}