//
//  App.swift
//  App SWIFT CLASS
//
//  Created by Emre on 16.06.2020.
//  Copyright © 2020 Emre. All rights reserved.
//

import Foundation
import UIKit
import SwiftyJSON

extension String {
    func localize() -> String{
        return NSLocalizedString(self, comment: "")
    }
    func base64decode() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    func base64encode() -> String {
        return Data(self.utf8).base64EncodedString()
    }
}

class App {
    var appstoreID = "0"
    let url = "https://example.com/"
    var loginStoryboard = "Login"
    var loginController = "LoginViewController"
    let APP_OS = "ios"
    let APP_USER_AGENT = "App Browser"
    var APP_VERSION = ""
    var APP_DEVICE = ""
    var APP_APP = ""
    var APP_LANGUAGE = ""
    var auth = ""
    var sender: AnyObject
    let events = AppManager();
    var listeners = Dictionary<String, NSMutableArray>();
    
    init(_ sender: AnyObject,app: String) {
        self.sender = sender
        self.APP_APP = app
        self.APP_VERSION = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as! String
        self.APP_DEVICE = UIDevice.current.identifierForVendor!.uuidString
        self.APP_LANGUAGE = Locale.current.languageCode ?? "en"
        self.auth = UserDefaults.standard.string(forKey: "auth") ?? ""
        let controller = NSStringFromClass(type(of: self.sender)).components(separatedBy: ".")
        if(controller[1] != self.loginController){
            self.check()
        }
    }
    
    func check(){
        if (self.auth != "") {
            self.call(data: [], link: self.APP_APP, action: "check")
        } else {
            self.sender.dismiss(animated: true, completion: nil)
            self.sender.present(UIStoryboard(name: self.loginStoryboard, bundle: nil).instantiateViewController(withIdentifier: self.loginController), animated: true)
        }
    }
    
    func login(username: String, password: String){
        if(username == "" || password == ""){
            self.events.trigger(status: "false", action: "login", result: "Kullanıcı adı ve şifrenizi girmelisiniz");
        }else{
            let json = [
                "username": username,
                "password": password
            ]
            self.call(data: json, link: "auth", action: "login")
        }
    }
    
    func register(name: String, gsm: String){
        if(name == "" || gsm == ""){
            self.events.trigger(status: "false", action: "register", result: "Bir isim ve GSM numarası girmelisiniz");
        }else{
            let json = [
                "name": name,
                "gsm": gsm
            ]
            self.call(data: json, link: "auth", action: "register")
        }
    }
    
    func action(data: Any, action: String){
        self.call(data: data, link: APP_APP, action: action)
    }
    
    func call(data: Any, link: String, action: String){
        let json = [
            "request": [
                "action": action,
                "auth": self.auth
            ],
            "data": data
        ]
        let url = URL(string: self.url + link)!
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        var request = URLRequest(url: url)
        request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(APP_OS, forHTTPHeaderField: "X-App-Os")
        request.setValue(APP_APP, forHTTPHeaderField: "X-App-App")
        request.setValue(APP_VERSION, forHTTPHeaderField: "X-App-Version")
        request.setValue(APP_DEVICE, forHTTPHeaderField: "X-App-Device")
        request.setValue(APP_LANGUAGE, forHTTPHeaderField: "X-App-Language")
        request.setValue(APP_USER_AGENT, forHTTPHeaderField: "User-Agent")
        request.httpMethod = "POST"
        request.httpBody = jsonData
        print(self.url + link)
        print(String(data: jsonData!, encoding: String.Encoding.utf8) ?? "" as Any)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                error == nil else {
                return
            }

            let responseString = String(data: data, encoding: .utf8)
            print("response = \(responseString ?? "")")
            
            if let dataFromString = responseString!.data(using: .utf8, allowLossyConversion: false) {
                do {
                    let resultjson = try JSON(data: dataFromString)
                    let result = resultjson["result"]
                    let data = resultjson["data"]
                    DispatchQueue.main.async {
                    if(result["success"].bool!){
                        if(result["action"]=="login" && data["success"].bool!){
                            print("auth: \(data["data"]["auth"].string!)")
                            UserDefaults.standard.set(data["data"]["auth"].string!, forKey: "auth")
                            self.sender.dismiss(animated: true, completion: nil)
                        }
                        if(result["action"] != "check"){
                            if(data["success"].bool!){
                                self.events.trigger(status: "true", action: result["action"].string!, result: data["data"]);
                            }else{
                                self.events.trigger(status: "false", action: result["action"].string!, result: data["message"].string);
                            }
                        }
                    }else{
                        if(result["do"] != ""){
                                let alert = UIAlertController(title: "", message: result["message"].string, preferredStyle: UIAlertController.Style.alert)
                                switch result["do"] {
                                case "exit":
                                    alert.addAction(UIAlertAction(title: "Tamam", style:.default , handler: { (UIAlertAction) in
                                        exit(0)
                                    }))
                                    break
                                case "update":
                                    alert.addAction(UIAlertAction(title: "Tamam", style:.default , handler: { (UIAlertAction) in
                                        if(self.appstoreID != "0"){
                                            exit(0)
                                        }else{
                                            if let url = URL(string: "itms-apps://itunes.apple.com/app/id" + self.appstoreID),
                                                UIApplication.shared.canOpenURL(url){
                                                if #available(iOS 10.0, *) {
                                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                                } else {
                                                    UIApplication.shared.openURL(url)
                                                }
                                            }
                                        }
                                    }))
                                    break
                                case "logout":
                                    let defaults = UserDefaults.standard
                                    defaults.set("", forKey: "auth")
                                    let storyboard = UIStoryboard(name: self.loginStoryboard, bundle: nil)
                                    let loginVCtrl = storyboard.instantiateViewController(withIdentifier: self.loginController)
                                    self.sender.present(loginVCtrl, animated: true)
                                    break
                                default: break
                            }
                            self.sender.present(alert, animated: true, completion: nil)
                        }
                    }
                    }
                } catch {
                }
            }
        }
        task.resume()
    }
    
    func onFalse(function: @escaping ((String,Any?)->())) {
        self.events.listenTo(result: false, action: function);
    }
    func onTrue(function: @escaping ((String,Any?)->())) {
        self.events.listenTo(result: true, action: function);
    }
}

class AppManager {
    var listeners = Dictionary<String, NSMutableArray>();
    
    func listenTo(result:Bool, action: @escaping ((String,Any?)->())) {
        let newListener = AppListener(callback: action);
        addListener(eventName: result ? "true" : "false", newEventListener: newListener);
    }
    
    internal func addListener(eventName:String, newEventListener:AppListener) {
        if let listenerArray = self.listeners[eventName] {
            listenerArray.add(newEventListener);
        }
        else {
            self.listeners[eventName] = [newEventListener] as NSMutableArray;
        }
    }
    
    func trigger(status:String, action:String, result:Any? = nil) {
        if let actionObjects = self.listeners[status] {
            for actionObject in actionObjects {
                if let actionToPerform = actionObject as? AppListener {
                    if let methodToCall = actionToPerform.actionExpectsInfo {
                        methodToCall(action, result);
                    }
                    else if let methodToCall = actionToPerform.action {
                        methodToCall();
                    }
                }
            }
        }
    }
}

class AppListener {
    let action:(() -> ())?;
    let actionExpectsInfo:((String,Any?) -> ())?;
    
    init(callback: @escaping ((String,Any?) -> ()) ) {
        self.actionExpectsInfo = callback;
        self.action = nil;
    }
}
