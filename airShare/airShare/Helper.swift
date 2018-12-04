//
//  Helper.swift
//  AirShare 2.0
//
//  Created by Tyler Gaffaney on 12/3/18.
//  Copyright © 2018 Tyler Gaffaney Inc. All rights reserved.
//

import Foundation
import UIKit

enum Types {
    case document
    case photo
    case video
    case camera
}

class Helper {
    
    static func askForName(vc: UIViewController, callback: @escaping ()->()){
        var textField: UITextField?
        
        // create alertController
        let alertController = UIAlertController(title: "Device Name", message: "Please enter a device name", preferredStyle: .alert)
        
        alertController.addTextField { (pTextField) in
            pTextField.placeholder = "Noah's iPhone"
            pTextField.clearButtonMode = .whileEditing
            pTextField.borderStyle = .none
            textField = pTextField
        }
        
        // create Ok button
        alertController.addAction(UIAlertAction(title: "Okay", style: .default, handler: { (pAction) in
            // when user taps OK, you get your value here
            if let inputValue = textField?.text {
                if inputValue != "" {
                    Helper.set(name: inputValue)
                    alertController.dismiss(animated: true, completion: nil)
                    callback()
                }
            }
        }))
        
        // show alert controller
        DispatchQueue.main.async {
            vc.present(alertController, animated: true, completion: nil)
        }
        
    }
    
    private static func set(name: String){
        let standard = UserDefaults.standard
        standard.set(name, forKey: "my_device_name")
    }
    
    static func getName() -> String?{
        let standard = UserDefaults.standard
        return standard.string(forKey: "my_device_name")
    }
    
    static func getNameFor(id: String) -> String?{
        let standard = UserDefaults.standard
        var test = standard.string(forKey:"id_" + id)
        return test
    }
    
    static func set(name: String, id: String){
        if(name == "Someone"){
            print("NOOOOOOOOOOO")
        }
        let standard = UserDefaults.standard
        standard.set(name, forKey: "id_" + id)
    }
}

public extension UIImage {
    public convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}
