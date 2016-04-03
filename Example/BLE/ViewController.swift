//
//  ViewController.swift
//  BLE
//
//  Created by Ondrej Rafaj on 04/03/2016.
//  Copyright (c) 2016 Ondrej Rafaj. All rights reserved.
//

import UIKit
import SnapKit
import CoreBluetooth
import BLE


struct BLEUUIDs {
    internal static let RedBearDuoServiceUUID: String = "713D0000-503E-4C75-BA94-3148F18D941E"
    internal static let RedBearDuoWriteUUID: String = "713D0003-503E-4C75-BA94-3148F18D941E"
    internal static let RedBearDuoReadUUID: String = "713D0002-503E-4C75-BA94-3148F18D941E"
}


class ViewController: UIViewController, BLEDelegate {
    
    
    private let ble: BLE = BLE()
    
    private let scanButton: UIButton = UIButton()
    private let scanRedBearDuoButton: UIButton = UIButton()
    
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Enable debug mode
        self.ble.debugMode = true
        
        // Set delegate
        self.ble.delegate = self
        
        // Create interface
        self.createInterface()
    }

    // MARK: Actions
    
    private func enableButtons(enable: Bool) {
    
    }
    
    internal func didPressScanButton(sender: UIButton) {
        // Start scanning
        self.ble.startScanning(10) // Scan for 10 seconds
    }
    
    internal func didPressScanRBDButton(sender: UIButton) {
        // Start scanning
        self.ble.startScanning(10, serviceUUIDs: [BLEUUIDs.RedBearDuoServiceUUID]) // Scan for 10 seconds
    }
    
    // MARK: BLE delegate methods
    
    func bleDidFinishScanning(ble: BLE) {
        
    }
    
    func bleDidUpdateState(ble: BLE, state: CBCentralManagerState) {
        
    }
    
    func bleDidConnectToPeripheral(ble: BLE, peripheral: CBPeripheral) {
        
    }
    
    func bleDidDiscoverPeripherals(ble: BLE, peripherals: [CBPeripheral]) {
        for peripheral: CBPeripheral in peripherals {
            // Connect to peripheral
            self.ble.connectToPeripheral(peripheral)
        }
    }
    
    func bleFailedConnectToPeripheral(ble: BLE, peripheral: CBPeripheral) {
        
    }
    
    func bleDidDisconnectFromPeripheral(ble: BLE, peripheral: CBPeripheral) {
        
    }
    
    func bleDidReceiveData(ble: BLE, peripheral: CBPeripheral, characteristic: String, data: NSData?) {
        
    }
    
    // MARK: Create interface
    
    private func createInterface() {
        // Creating basic scan button
        self.scanButton.setTitle("Scan (results in console)", forState: .Normal)
        self.scanButton.backgroundColor = UIColor.lightGrayColor()
        self.scanButton.addTarget(self, action: #selector(ViewController.didPressScanButton(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(self.scanButton)
        
        self.scanButton.snp_makeConstraints { (make) in
            make.top.left.equalTo(40)
            make.right.equalTo(-40)
            make.height.equalTo(44)
        }
        
        // Create connect to redbear button
        self.scanRedBearDuoButton.setTitle("Scan & connect to RedBear Duo", forState: .Normal)
        self.scanRedBearDuoButton.backgroundColor = UIColor.lightGrayColor()
        self.scanRedBearDuoButton.addTarget(self, action: #selector(ViewController.didPressScanRBDButton(_:)), forControlEvents: .TouchUpInside)
        self.view.addSubview(self.scanRedBearDuoButton)
        
        self.scanRedBearDuoButton.snp_makeConstraints { (make) in
            make.top.equalTo(self.scanButton.snp_bottom).offset(20)
            make.left.equalTo(40)
            make.right.equalTo(-40)
            make.height.equalTo(44)
        }
    }

}

