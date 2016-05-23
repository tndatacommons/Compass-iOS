//
//  AppDelegate.swift
//  Compass
//
//  Created by Ismael Alonso on 4/7/16.
//  Copyright © 2016 Tennessee Data Commons. All rights reserved.
//

import UIKit
import Just
import Locksmith
import CoreData


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, GGLInstanceIDDelegate, GCMReceiverDelegate{
    
    var window: UIWindow?
    
    //GCM variables
    var gcmSenderId: String?
    var registrationToken: String?
    var registrationOptions = [String: AnyObject]()


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool{
        //For some reason, the line group that follows this one won't work if I don't do this first.
        //  It is nonsense (good job, Google), but it works.
        var configureError:NSError?;
        GGLContext.sharedInstance().configureWithError(&configureError);
        //I ain't even remotely comfortable having this here...
        assert(configureError == nil, "Error configuring Google services: \(configureError)");
        
        //Get the GCM Sender ID.
        print("Retrieving GCM Sender ID...");
        gcmSenderId = GGLContext.sharedInstance().configuration.gcmSenderID;
        print("GCM Sender ID retrieved: \(gcmSenderId)");
        
        //Fire the notification registration process.
        let settings: UIUserNotificationSettings = UIUserNotificationSettings(forTypes: [.Alert, .Sound], categories: nil);
        application.registerUserNotificationSettings(settings);
        application.registerForRemoteNotifications();
        
        return true;
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData){
        print("didRegister Called");
        
        //Create a config and set a delegate that implements the GGLInstaceIDDelegate protocol.
        let instanceIDConfig = GGLInstanceIDConfig.defaultConfig();
        instanceIDConfig.delegate = self;
        
        //Start the GGLInstanceID shared instance with that config and request a registration
        //  token to enable reception of notifications
        GGLInstanceID.sharedInstance().startWithConfig(instanceIDConfig)
        registrationOptions = [kGGLInstanceIDRegisterAPNSOption: deviceToken,
                               kGGLInstanceIDAPNSServerTypeSandboxOption: true];
        
        register();
    }
    
    func registrationHandler(registrationToken: String!, error: NSError!){
        print("GCM Token: \(registrationToken)");
        if (registrationToken != nil){
            //The method calls to NotificationUtil will handle the specific cases
            NotificationUtil.setRegistrationToken(registrationToken);
            NotificationUtil.sendRegistrationToken();
        }
        else if (error != nil){
            print(error.description);
        }
    }
    
    func onTokenRefresh(){
        print("onTokenRefresh()");
        register();
    }
    
    private func register(){
        GGLInstanceID.sharedInstance()
            .tokenWithAuthorizedEntity(gcmSenderId, scope: kGGLInstanceIDScopeGCM,
                                       options: registrationOptions, handler: registrationHandler);
    }
    
    func applicationDidBecomeActive( application: UIApplication) {
        // Connect to the GCM server to receive non-APNS notifications
        GCMService.sharedInstance().connectWithHandler({(error:NSError?) -> Void in
            
        })
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        GCMService.sharedInstance().disconnect()
    }
    
    func application( application: UIApplication,
                      didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        print("Notification received: \(userInfo)")
        // This works only if the app started the GCM service
        GCMService.sharedInstance().appDidReceiveMessage(userInfo);
        // Handle the received message
        NSNotificationCenter.defaultCenter().postNotificationName("onMessageReceived", object: nil,
                                                                  userInfo: userInfo)
        /*
        Deal with this later
 
        let notification = UILocalNotification()
        notification.alertBody = "I just got a notification through GCM" // text that will be displayed in the notification
        notification.alertAction = "open" // text that is displayed after "slide to..." on the lock screen - defaults to "slide to view"
        notification.fireDate = NSDate().dateByAddingTimeInterval(1000) // todo item due date (when notification will be fired)
        notification.soundName = UILocalNotificationDefaultSoundName // play default sound
        notification
        UIApplication.sharedApplication().scheduleLocalNotification(notification)*/
    }
    
    func application( application: UIApplication,
                      didReceiveRemoteNotification userInfo: [NSObject : AnyObject],
                                                   fetchCompletionHandler handler: (UIBackgroundFetchResult) -> Void) {
        print("Notification received: \(userInfo)")
        // This works only if the app started the GCM service
        GCMService.sharedInstance().appDidReceiveMessage(userInfo);
        // Handle the received message
        // Invoke the completion handler passing the appropriate UIBackgroundFetchResult value
        NSNotificationCenter.defaultCenter().postNotificationName("onMessageReceived", object: nil,
                                                                  userInfo: userInfo)
        handler(UIBackgroundFetchResult.NoData);
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    //This is all native stuff, mostly core data, which I ain't sure we need. I also don't know what it does. yet.
    //  I am separating it because it is nagging the crap out of me.

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }

    // MARK: - Core Data stack

    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "org.tndata.Compass" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("Compass", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("SingleViewCoreData.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason

            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
    }()

    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }

}

