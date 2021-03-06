//
//  MyGoalController.swift
//  Compass
//
//  Created by Ismael Alonso on 10/12/16.
//  Copyright © 2016 Tennessee Data Commons. All rights reserved.
//

import UIKit
import Just
import ObjectMapper
import Nuke
import Crashlytics


class MyGoalController: UIViewController, UIGestureRecognizerDelegate{
    //MARK: Data
    
    var delegate: MyGoalControllerDelegate?
    var userGoalId: Int!
    var userGoal: UserGoal? = nil
    var customActions = [CustomAction]()
    var selectedAction: CustomAction?
    var startTime: Double = 0
    var enterBackgroundTime: Double = -1
    
    
    //MARK: UI components
    
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var errorMessage: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var scrollViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var hero: UIImageView!
    @IBOutlet weak var goalTitle: UILabel!
    @IBOutlet weak var goalDescription: UILabel!
    @IBOutlet weak var customContentContainer: UIView!
    @IBOutlet weak var customContentIndicator: UIActivityIndicatorView!
    @IBOutlet var tableView: ContentWrapUITableView!
    
    var tableViewConstraints = [NSLayoutConstraint]()
    
    var newActionCell: UserGoalNewCustomActionCell? = nil
    
    var selectedField: UITextField? = nil
    var scrolledBy: CGFloat = 0
    
    
    //MARK: Initial load methods
    
    override func viewDidLoad(){
        super.viewDidLoad()
        
        //We need to know when the keyboard appears or goes away to adjust the scrollview's bottom
        //  constraint and scroll the view in order to have the text field being written to inside
        //  the screen
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: #selector(MyGoalController.keyboardWillShow(_:)),
            name: UIKeyboardWillShowNotification,
            object: nil
        )
        
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: #selector(MyGoalController.keyboardWillHide(_:)),
            name: UIKeyboardWillHideNotification,
            object: nil
        )
        
        //Tap to retry
        let goalTap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        goalTap.delegate = self
        errorMessage.addGestureRecognizer(goalTap)
        
        //At load time the table should have nothing, as CustomActions need to be fetched, so
        //  remove it from the view hierarchy
        for constraint in customContentContainer.constraints{
            if constraint.belongsTo(tableView){
                tableViewConstraints.append(constraint)
            }
        }
        tableView.removeFromSuperview()
        //Set both the delegate and the data source
        tableView.dataSource = self
        tableView.delegate = self
        
        //Automatic height calculation
        tableView.rowHeight = UITableViewAutomaticDimension
        
        //If the UserGoal is nil fetch it, otherwise display it and fetch the custom actions
        if userGoal == nil{
            fetchGoal()
        }
        else{
            populateUI()
            fetchCustomActions()
        }
        
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(
            self,
            selector: #selector(MyGoalController.appWillResignActive),
            name: UIApplicationWillResignActiveNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(MyGoalController.appWillTerminate),
            name: UIApplicationWillTerminateNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(MyGoalController.appWillEnterForeground),
            name: UIApplicationWillEnterForegroundNotification,
            object: nil
        )
    }
    
    deinit{
        //Remove keyboard observers in the destructor
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidAppear(animated: Bool){
        super.viewDidAppear(animated)
        startTime = NSDate().timeIntervalSince1970
    }
    
    override func viewWillDisappear(animated: Bool){
        recordTime()
        removeObservers()
        super.viewWillDisappear(animated)
    }
    
    func appWillResignActive(){
        enterBackgroundTime = NSDate().timeIntervalSince1970
    }
    
    func appWillTerminate(){
        if (enterBackgroundTime < 0){
            let now = NSDate().timeIntervalSince1970
            startTime += now-enterBackgroundTime
        }
        recordTime()
        removeObservers()
    }
    
    func appWillEnterForeground(){
        let now = NSDate().timeIntervalSince1970
        startTime += now-enterBackgroundTime
        enterBackgroundTime = -1
    }
    
    private func recordTime(){
        if userGoal != nil{
            let now = NSDate().timeIntervalSince1970
            let time = Int(now-startTime)
            print(time)
            Answers.logContentViewWithName(
                userGoal!.getTitle(),
                contentType: "Goal",
                contentId: "\(userGoal!.getId())",
                customAttributes: ["Duration": time]
            )
        }
    }
    
    private func removeObservers(){
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(
            self,
            name: UIApplicationWillResignActiveNotification,
            object: nil
        )
        notificationCenter.removeObserver(
            self,
            name: UIApplicationWillTerminateNotification,
            object: nil
        )
        notificationCenter.removeObserver(
            self,
            name: UIApplicationWillEnterForegroundNotification,
            object: nil
        )
    }
    
    func handleTap(sender: UITapGestureRecognizer?){
        if sender?.view == errorMessage{
            fetchGoal()
        }
    }
    
    private func fetchGoal(){
        //Switch component state
        loadingIndicator.hidden = false
        errorMessage.hidden = true
        scrollView.hidden = true
        
        //Fire the request
        let headerMap = SharedData.user.getHeaderMap()
        Just.get(API.URL.getUserGoal(userGoalId), headers: headerMap){ (response) in
            if response.ok{
                self.userGoal = Mapper<UserGoal>().map(response.contentStr)
                dispatch_async(dispatch_get_main_queue(), {
                    self.populateUI()
                })
                self.fetchCustomActions()
            }
            else{
                dispatch_async(dispatch_get_main_queue(), {
                    self.view.bringSubviewToFront(self.errorMessage)
                    self.loadingIndicator.hidden = true
                    self.errorMessage.hidden = false
                })
            }
        }
    }
    
    private func populateUI(){
        view.sendSubviewToBack(errorMessage)
        loadingIndicator.hidden = true
        errorMessage.hidden = true
        scrollView.hidden = false
        
        if let category = SharedData.getCategory(userGoal!.getPrimaryCategoryId()){
            setCategory(category)
        }
        goalTitle.text = userGoal!.getTitle()
        goalDescription.text = userGoal!.getDescription()
        customContentIndicator.hidden = false
    }
    
    @IBAction func removeGoal(){
        //There should always be a goal if the user is able to tap the button, but check in case
        if (userGoal != nil){
            //Delete request
            Just.delete(
                API.URL.deleteGoal(userGoal!),
                headers: SharedData.user.getHeaderMap()
            ){ (response) in }
            //Remove from the data set
            SharedData.feedData.removeGoal(userGoal!)
            //Pop this controller
            navigationController!.popViewControllerAnimated(true)
            //If there is a delegate, call the function
            if delegate != nil{
                delegate!.onGoalRemoved()
            }
        }
    }
    
    private func setCategory(category: CategoryContent){
        if category.getImageUrl().characters.count != 0{
            Nuke.taskWith(NSURL(string: category.getImageUrl())!){
                self.hero.image = $0.image
            }.resume()
        }
    }
    
    private func fetchCustomActions(){
        let headerMap = SharedData.user.getHeaderMap()
        Just.get(API.URL.getCustomActions(userGoal!), headers: headerMap){ (response) in
            if response.ok{
                self.customActions = Mapper<CustomActionList>().map(response.contentStr)!.results
            }
            dispatch_async(dispatch_get_main_queue(), {
                self.setCustomActions()
            })
        }
    }
    
    private func setCustomActions(){
        //Add the table back to the layout
        customContentContainer.addSubview(tableView)
        for constraint in tableViewConstraints{
            customContentContainer.addConstraint(constraint)
        }
        customContentIndicator.hidden = true
        tableView.hidden = false
        tableView.invalidateIntrinsicContentSize()
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    func keyboardWillShow(notification: NSNotification){
        let info = notification.userInfo as! [String: AnyObject]
        let keyboardSize = (info[UIKeyboardFrameBeginUserInfoKey] as! NSValue).CGRectValue().size
        scrollViewBottomConstraint.constant = keyboardSize.height
        
        //If there ain't a selected field set, that means that the selected field is the
        //  new action field, for now scroll all the times
        if selectedField == nil{
            let newY = scrollView.contentOffset.y+keyboardSize.height
            scrollView.setContentOffset(CGPointMake(0, newY), animated: true)
        }
        else{
            let abs = selectedField!.superview!.convertPoint(selectedField!.frame.origin, toView: nil)
            let windowHeight = UIScreen.mainScreen().bounds.height
            
            let fPos = windowHeight - keyboardSize.height - 30
            let blCornerYPos = abs.y + selectedField!.frame.height
            if blCornerYPos > fPos{
                scrolledBy = blCornerYPos - fPos
                print(scrollView.contentOffset)
                let newY = scrollView.contentOffset.y+scrolledBy
                print(newY)
                scrollView.setContentOffset(CGPointMake(0, newY), animated: true)
            }
        }
        
        view.layoutIfNeeded()
    }
    
    func keyboardWillHide(notification: NSNotification){
        scrollViewBottomConstraint.constant = 0
        view.layoutIfNeeded()
        scrolledBy = 0
        selectedField = nil
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?){
        if segue.identifier == "TriggerFromMyGoal"{
            let triggerController = segue.destinationViewController as! TriggerController
            triggerController.delegate = self
            if sender == nil{
                selectedAction = customActions[customActions.count-1]
                triggerController.action = selectedAction
            }
            else{
                let indexPath = tableView.indexPathForCell(sender as! UITableViewCell)
                selectedAction = customActions[indexPath!.row]
                triggerController.action = selectedAction
            }
        }
    }
}


extension MyGoalController: UITableViewDataSource{
    func numberOfSectionsInTableView(tableView: UITableView) -> Int{
        return 2
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0{
            return customActions.count
        }
        if section == 1{
            return 1
        }
        return 0
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell{
        if indexPath.section == 0{
            let cell = tableView.dequeueReusableCellWithIdentifier(
                "UserGoalCustomActionCell",
                forIndexPath: indexPath
            )
            cell.selectionStyle = UITableViewCellSelectionStyle.Default
            let actionCell = cell as! UserGoalCustomActionCell
            actionCell.setAction(self, title: customActions[indexPath.row].getTitle())
            return actionCell
        }
        else{
            let cell = tableView.dequeueReusableCellWithIdentifier(
                "UserGoalNewCustomActionCell",
                forIndexPath: indexPath
            )
            newActionCell = cell as? UserGoalNewCustomActionCell
            newActionCell?.delegate = self
            return newActionCell!
        }
    }
}


extension MyGoalController: UITableViewDelegate{
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath){
        if indexPath.section == 0{
            let cell = tableView.cellForRowAtIndexPath(indexPath) as! UserGoalCustomActionCell
            
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
            
            let sheet = UIAlertController(
                title: "Choose an option", message: "",
                preferredStyle: UIAlertControllerStyle.ActionSheet
            )
            sheet.addAction(UIAlertAction(title: "Edit", style: .Default){ action in
                self.selectedField = cell.customAction
                cell.edit()
            })
            sheet.addAction(UIAlertAction(title: "Reschedule", style: .Default){ action in
                self.performSegueWithIdentifier("TriggerFromMyGoal", sender: cell)
            })
            sheet.addAction(UIAlertAction(title: "Delete", style: .Destructive){ action in
                Just.delete(
                    API.URL.deleteAction(self.customActions[indexPath.row]),
                    headers: SharedData.user.getHeaderMap()
                ){ (response) in }
                
                self.customActions.removeAtIndex(indexPath.row)
                self.tableView.reloadData()
                self.tableView.sizeToFit()
                self.tableView.invalidateIntrinsicContentSize()
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
            })
            sheet.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
            
            presentViewController(sheet, animated: true, completion: nil);
        }
    }
    
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat{
        if indexPath.section == 0{
            return 46
        }
        if indexPath.section == 1{
            return 85
        }
        return 0
    }
}


extension MyGoalController: UserGoalCustomActionCellDelegate, UserGoalNewCustomActionCellDelegate{
    func onAddCustomAction(title: String){
        Just.post(
            API.URL.postCustomAction(),
            headers: SharedData.user.getHeaderMap(),
            json: API.BODY.postPutCustomAction(title, goal: userGoal!)
        ){ (response) in
            if response.ok{
                self.customActions.append(Mapper<CustomAction>().map(response.contentStr)!)
                
                dispatch_async(dispatch_get_main_queue(), {
                    CATransaction.begin()
                    CATransaction.setCompletionBlock(){
                        self.tableView.invalidateIntrinsicContentSize()
                        self.view.setNeedsLayout()
                        self.view.layoutIfNeeded()
                    }
                    self.tableView.reloadData()
                    self.tableView.sizeToFit()
                    CATransaction.commit()
                    
                    self.performSegueWithIdentifier("TriggerFromMyGoal", sender: nil)
                })
            }
            
            dispatch_async(dispatch_get_main_queue(), {
                self.newActionCell?.onActionSaveComplete(response.ok)
            })
        }
    }
    
    func onSaveCustomAction(cell: UserGoalCustomActionCell, newTitle: String){
        if let indexPath = tableView.indexPathForCell(cell){
            Just.put(
                API.URL.putCustomAction(customActions[indexPath.row]),
                headers: SharedData.user.getHeaderMap(),
                json: API.BODY.postPutCustomAction(newTitle, goal: userGoal!)
            ){ (response) in }
        }
    }
}


extension MyGoalController: TriggerControllerDelegate{
    func onTriggerSavedForAction(action: Action){
        if action.getTrigger() != nil{
            selectedAction?.setTrigger(action.getTrigger()!)
        }
    }
}


extension MyGoalController: UITextFieldDelegate{
    func textFieldShouldReturn(textField: UITextField) -> Bool{
        textField.resignFirstResponder()
        return true
    }
}


protocol MyGoalControllerDelegate{
    func onGoalRemoved()
}
