//
//  CentralManagerViewController.swift
//  BLEConnect
//
//  Created by Evan Stone on 8/12/16.
//  Copyright © 2016 Cloud City. All rights reserved.
//

import UIKit
import CoreBluetooth

class CentralManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var centralManager:CBCentralManager!
    var peripheral:CBPeripheral?
    var dataBuffer:NSMutableData!
    var scanAfterDisconnecting:Bool = true
    var peripherals : Set<CBPeripheral>?
    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        textView.text = ""
//        self.textView.layer.borderColor = UIColor.lightGray.cgColor
//        self.textView.layer.borderWidth = 1.0
//
//        rssiLabel.text = ""
//
//        // Create and start the central manager
//        // Without State Preservation and Restoration:
//        centralManager = CBCentralManager(delegate: self, queue: nil)
//
//        // With State Preservation and Restoration
//        //centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey : Device.centralRestoreIdentifier])
//
//        connectionIndicatorView.layer.backgroundColor = UIColor.red.cgColor
//        connectionIndicatorView.layer.cornerRadius = connectionIndicatorView.frame.height / 2
//    }
   
//    override func viewWillAppear(_ animated: Bool) {
//        self.textView.text = ""
//        dataBuffer = NSMutableData()
//    }
//
//    override func viewWillDisappear(_ animated: Bool) {
//        stopScanning()
//        scanAfterDisconnecting = false
//        disconnect()
//    }
    
    
    // MARK: Handling User Interactions
    
//    @IBAction func handleDisconnectButtonTapped(_ sender: AnyObject) {
//        // if we are currently connected, then disconnect, otherwise start scanning again.
//        if let _ = self.peripheral {
//            scanAfterDisconnecting = false
//            disconnect()
//        } else {
//            startScanning()
//        }
//    }
    
    override init() {
        super.init()
        
        dataBuffer = NSMutableData()
        peripherals = Set<CBPeripheral>()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // With State Preservation and Restoration
        //centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionRestoreIdentifierKey : Device.centralRestoreIdentifier])
    }
    
    // MARK: Central management methods
    
    func stopScanning() {
        centralManager.stopScan()
    }
    
    func startScanning() {
        if centralManager.isScanning {
            print("Central Manager is already scanning!!")
            return;
        }
        centralManager.scanForPeripherals(withServices: [CBUUID.init(string: Device.TransferService)], options: [CBCentralManagerScanOptionAllowDuplicatesKey:true])
        print("Scanning Started!")
    }
    
    /*
     Call this when things either go wrong, or you're done with the connection.
     This cancels any subscriptions if there are any, or straight disconnects if not.
     (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
     */
    func disconnect() {
        // verify we have a peripheral
        guard let peripheral = self.peripheral else {
            print("Peripheral object has not been created yet.")
            return
        }
        
        // check to see if the peripheral is connected
        if peripheral.state != .connected {
            print("Peripheral exists but is not connected.")
            self.peripheral = nil
            return
        }
        
        guard let services = peripheral.services else {
            // disconnect directly
            centralManager.cancelPeripheralConnection(peripheral)
            return
        }
        
        for service in services {
            // iterate through characteristics
            if let characteristics = service.characteristics {
                for characteristic in characteristics {
                    // find the Transfer Characteristic we defined in our Device struct
                    if characteristic.uuid == CBUUID.init(string: Device.TransferCharacteristic) {
                        // We can return after calling CBPeripheral.setNotifyValue because CBPeripheralDelegate's
                        // didUpdateNotificationStateForCharacteristic method will be called automatically
                        peripheral.setNotifyValue(false, for: characteristic)
                        return
                    }
                }
            }
        }
        
        // We have a connection to the device but we are not subscribed to the Transfer Characteristic for some reason.
        // Therefore, we will just disconnect from the peripheral
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    
    // MARK: CBCentralManagerDelegate Methods
    
    // State Preservation and Restoration
    // This is the FIRST delegate method that will be called when being relaunched -- not centralManagerDidUpdateState
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        
        //---------------------------------------------------------------------------
        // We don't need these, but it's good to know that they exist.
        //---------------------------------------------------------------------------
        // Retrive array of service UUIDs (represented by CBUUID objects) that 
        // contains all the services the central manager was scanning for at the time
        // the app was terminated by the system.
        //
        //let scanServices = dict[CBCentralManagerRestoredStateScanServicesKey]
        
        // Retrieve dictionary containing all of the peripheral scan options that 
        // were being used by the central manager at the time the app was terminated 
        // by the system.
        //
        //let scanOptions = dict[CBCentralManagerRestoredStateScanOptionsKey]
        //---------------------------------------------------------------------------
        
        /*
         Retrieve array of CBPeripheral objects containing all of the peripherals that were connected to the central manager
         (or that had a connection pending) at the time the app was terminated by the system.
         
         When possible, all the information about a peripheral is restored, including any discovered services, characteristics,
         characteristic descriptors, and characteristic notification states.
         */
        
        if let peripheralsObject = dict[CBCentralManagerRestoredStatePeripheralsKey] {
            let peripherals = peripheralsObject as! Array<CBPeripheral>
            if peripherals.count > 0 {
                // Just grab the first one in this case. If we had maintained an array of 
                // multiple peripherals then we would just add them to our array and set the delegate...
                peripheral = peripherals[0]
                peripheral?.delegate = self
            }
        }
    }
    
    
    /* 
     Invoked when the central manager’s state is updated.
     This is where we kick off the scanning if Bluetooth is turned on and is active.
     */
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Central Manager State Updated: \(central.state)")
        
        // We showed more detailed handling of this in Zero-to-BLE Part 2, so please refer to that if you would like more information.
        // We will just handle it the easy way here: if Bluetooth is on, proceed...
        if central.state != .poweredOn {
            self.peripheral = nil
            return
        }
        
        startScanning()
        
        //--------------------------------------------------------------
        // If the app has been restored with the peripheral in centralManager(_:, willRestoreState:),
        // we start subscribing to updates again to the Transfer Characteristic.
        //--------------------------------------------------------------
        // check for a peripheral object
        guard let peripheral = self.peripheral else {
            return
        }

        // see if that peripheral is connected
        guard peripheral.state == .connected else {
            return
        }

        // make sure the peripheral has services
        guard let peripheralServices = peripheral.services else {
            return
        }
        
        // we have services, but we need to check for the Transfer Service
        // (honestly, this may be overkill for our project but it demonstrates how to make this process more bulletproof...)
        // Also: Pardon the pyramid.
        let serviceUUID = CBUUID(string: Device.TransferService)
        if let serviceIndex = peripheralServices.index(where: {$0.uuid == serviceUUID}) {
            // we have the service, but now we check to see if we have a characteristic that we've subscribed to...
            let transferService = peripheralServices[serviceIndex]
            let characteristicUUID = CBUUID(string: Device.TransferCharacteristic)
            if let characteristics = transferService.characteristics {
                if let characteristicIndex = characteristics.index(where: {$0.uuid == characteristicUUID}) {
                    // Because this is a characteristic that we subscribe to in the standard workflow,
                    // we need to check if we are currently subscribed, and if not, then call the 
                    // setNotifyValue like we did before.
                    let characteristic = characteristics[characteristicIndex]
                    if !characteristic.isNotifying {
                       peripheral.setNotifyValue(true, for: characteristic)
                    }
                } else {
                    // if we have not discovered the characteristic yet, then call discoverCharacteristics, and the delegate method will get called as in the standard workflow...
                    peripheral.discoverCharacteristics([characteristicUUID], for: transferService)
                }
            }
        } else {
            // we have a CBPeripheral object, but we have not discovered the services yet,
            // so we call discoverServices and the delegate method will handle the rest...
            peripheral.discoverServices([serviceUUID])
        }
    }
    
    /*
     Invoked when the central manager discovers a peripheral while scanning.
     
     The advertisement data can be accessed through the keys listed in Advertisement Data Retrieval Keys.
     You must retain a local copy of the peripheral if any command is to be performed on it.
     In use cases where it makes sense for your app to automatically connect to a peripheral that is
     located within a certain range, you can use RSSI data to determine the proximity of a discovered
     peripheral device.
     
     central - The central manager providing the update.
     peripheral - The discovered peripheral.
     advertisementData - A dictionary containing any advertisement data.
     RSSI - The current received signal strength indicator (RSSI) of the peripheral, in decibels.

     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Discovered \(peripheral.name) at \(RSSI)")
        
        //Add peripherals to list
        peripherals?.insert(peripheral)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "updatePeripherals"), object: nil)
        
        // check to see if we've already saved a reference to this peripheral
        if self.peripheral != peripheral {
            self.peripheral = peripheral
            
            // connect to the peripheral
            print("Connecting to peripheral: \(peripheral)")
            centralManager?.connect(peripheral, options: nil)
        }
    }
    
    
    /*
     Invoked when a connection is successfully created with a peripheral.
     
     This method is invoked when a call to connectPeripheral:options: is successful.
     You typically implement this method to set the peripheral’s delegate and to discover its services.
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Peripheral Connected!!!")
        
//        connectionIndicatorView.layer.backgroundColor = UIColor.green.cgColor
        
        // Stop scanning
        centralManager.stopScan()
        print("Scanning Stopped!")

        // Clear any cached data...
        dataBuffer.length = 0
        
        // IMPORTANT: Set the delegate property, otherwise we won't receive the discovery callbacks, like peripheral(_:didDiscoverServices)
        peripheral.delegate = self
        
        // Now that we've successfully connected to the peripheral, let's discover the services.
        // This time, we will search for the transfer service UUID
        print("Looking for Transfer Service...")
        peripheral.discoverServices([CBUUID.init(string: Device.TransferService)])
    }
    
    
    /*
     Invoked when the central manager fails to create a connection with a peripheral.
     
     This method is invoked when a connection initiated via the connectPeripheral:options: method fails to complete.
     Because connection attempts do not time out, a failed connection usually indicates a transient issue,
     in which case you may attempt to connect to the peripheral again.
     */
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral) (\(error?.localizedDescription))")
//        connectionIndicatorView.layer.backgroundColor = UIColor.red.cgColor
        self.disconnect()
    }
    
    
    /*
     Invoked when an existing connection with a peripheral is torn down.
     
     This method is invoked when a peripheral connected via the connectPeripheral:options: method is disconnected.
     If the disconnection was not initiated by cancelPeripheralConnection:, the cause is detailed in error.
     After this method is called, no more methods are invoked on the peripheral device’s CBPeripheralDelegate object.
     
     Note that when a peripheral is disconnected, all of its services, characteristics, and characteristic descriptors are invalidated.
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // set our reference to nil and start scanning again...
        print("Disconnected from Peripheral")
//        connectionIndicatorView.layer.backgroundColor = UIColor.red.cgColor
        self.peripheral = nil
        if scanAfterDisconnecting {
            startScanning()
        }
    }
    
    
    //MARK: - CBPeripheralDelegate methods
    
    /*
     Invoked when you discover the peripheral’s available services.
     
     This method is invoked when your app calls the discoverServices: method.
     If the services of the peripheral are successfully discovered, you can access them
     through the peripheral’s services property.
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    // When the specified services are discovered, the peripheral calls the peripheral:didDiscoverServices: method of its delegate object.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        print("Discovered Services!!!")

        if error != nil {
            print("Error discovering services: \(error?.localizedDescription)")
            disconnect()
            return
        }
        
        // Core Bluetooth creates an array of CBService objects —- one for each service that is discovered on the peripheral.
        if let services = peripheral.services {
            for service in services {
                print("Discovered service \(service)")
                
                // If we found either the transfer service, discover the transfer characteristic
                if (service.uuid == CBUUID(string: Device.TransferService)) {
                    let transferCharacteristicUUID = CBUUID.init(string: Device.TransferCharacteristic)
                    peripheral.discoverCharacteristics([transferCharacteristicUUID], for: service)
                }
            }
        }
    }
    
    /*
     Invoked when you discover the characteristics of a specified service.
     
     If the characteristics of the specified service are successfully discovered, you can access
     them through the service's characteristics property.
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
            print("Error discovering characteristics: \(error?.localizedDescription)")
            return
        }
        
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                // Transfer Characteristic
                if characteristic.uuid == CBUUID(string: Device.TransferCharacteristic) {
                    // subscribe to dynamic changes
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }
    
    
    /*
     Invoked when you retrieve a specified characteristic’s value,
     or when the peripheral device notifies your app that the characteristic’s value has changed.
     
     This method is invoked when your app calls the readValueForCharacteristic: method,
     or when the peripheral notifies your app that the value of the characteristic for
     which notifications and indications are enabled has changed.
     
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("didUpdateValueForCharacteristic: \(Date())")
        1
        // if there was an error then print it and bail out
        if error != nil {
            print("Error updating value for characteristic: \(characteristic) - \(error?.localizedDescription)")
            return
        }
        
        // make sure we have a characteristic value
        guard let value = characteristic.value else {
            print("Characteristic Value is nil on this go-round")
            return
        }
        
        print("Bytes transferred: \(value.count)")
        
        // make sure we have a characteristic value
        guard let nextChunk = String(data: value, encoding: String.Encoding.utf8) else {
            print("Next chunk of data is nil.")
            return
        }
        
        print("Next chunk: \(nextChunk)")
        
        // If we get the EOM tag, we fill the text view
        if (nextChunk == Device.EOM) {
            if let message = String(data: dataBuffer as Data, encoding: String.Encoding.utf8) {
//                textView.text = message
                print("Final message: \(message)")
                
                // truncate our buffer now that we received the EOM signal!
                dataBuffer.length = 0
            }
        } else {
            dataBuffer.append(value)
            print("Next chunk received: \(nextChunk)")
            if let buffer = self.dataBuffer {
                print("Transfer buffer: \(String(data: buffer as Data, encoding: String.Encoding.utf8))")
            }
        }
    }
    
    /*
     Invoked when the peripheral receives a request to start or stop providing notifications 
     for a specified characteristic’s value.
     
     This method is invoked when your app calls the setNotifyValue:forCharacteristic: method.
     If successful, the error parameter is nil.
     If unsuccessful, the error parameter returns the cause of the failure.
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // if there was an error then print it and bail out
        if error != nil {
            print("Error changing notification state: \(error?.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            // notification started
            print("Notification STARTED on characteristic: \(characteristic)")
        } else {
            // notification stopped
            print("Notification STOPPED on characteristic: \(characteristic)")
            self.centralManager.cancelPeripheralConnection(peripheral)
        }

    }
}
