//
//  BLE.swift
//
//  Created by Ondrej Rafaj on 28/03/2016.
//  Copyright © 2016 manGoweb.cz. All rights reserved.
//

import Foundation
import CoreBluetooth


public protocol BLEDelegate {
    func bleDidUpdateState(ble: BLE, state: CBCentralManagerState)
    func bleDidDiscoverPeripherals(ble: BLE, peripherals: [CBPeripheral])
    func bleDidFinishScanning(ble: BLE)
    func bleDidConnectToPeripheral(ble: BLE, peripheral: CBPeripheral)
    func bleFailedConnectToPeripheral(ble: BLE, peripheral: CBPeripheral)
    func bleDidDisconnectFromPeripheral(ble: BLE, peripheral: CBPeripheral)
    func bleDidReceiveData(ble: BLE, peripheral: CBPeripheral, characteristic: String, data: NSData?)
}


public enum BLEError: ErrorType {
    case UUIDNotFoundInAvailableCharacteristics
}


public class BLE: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    public var debugMode: Bool = true
    
    public var delegate: BLEDelegate?
    
    public var serviceUUID: String? {
        get {
            if (self.serviceCBUUIDs != nil && self.serviceCBUUIDs?.count == 1) {
                let uuid: CBUUID = (self.serviceCBUUIDs?.first)! as CBUUID
                return uuid.UUIDString
            }
            else {
                return nil
            }
        }
        set (serviceUUID) {
            if (serviceUUID != nil) {
                self.serviceCBUUIDs = [CBUUID(string: serviceUUID!)]
            }
            else {
                self.serviceCBUUIDs = nil
            }
        }
    }
    
    // If not set, all characteristics will be discovered. This is a lengthy and expensive process
    public var characteristicsUUIDs: [String]? {
        get {
            if (self.usedCharacteristicsUUIDs != nil) {
                var uuidStrings: [String] = [String]()
                var i: Int = 0
                for uuid: CBUUID in self.usedCharacteristicsUUIDs! {
                    uuidStrings[i] = uuid.UUIDString
                    i += 1
                }
                return uuidStrings
            }
            else {
                return nil
            }
        }
        set (characteristicsUUIDs) {
            self.usedCharacteristicsUUIDs?.removeAll()
            
            if (characteristicsUUIDs != nil) {
                var i: Int = 0
                for uuid: String in characteristicsUUIDs! {
                    self.usedCharacteristicsUUIDs![i] = CBUUID(string: uuid)
                    i += 1
                }
            }
        }
    }
    
    private(set) public var peripherals: [CBPeripheral] = [CBPeripheral]()
    
    private var usedCharacteristicsUUIDs: [CBUUID]? = nil
    private var serviceCBUUIDs: [CBUUID]?
    private var centralManager: CBCentralManager!
    private var activePeripheral: CBPeripheral?
    private var characteristics: [String : CBCharacteristic] = [String : CBCharacteristic]()
    private var data: NSMutableData?
    private var rssiCompletionHandlers: [CBPeripheral: ((CBPeripheral, NSNumber?, NSError?) -> ())]?
    
    override public init() {
        super.init()
        
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
        self.data = NSMutableData()
    }
    
    @objc private func scanTimeout() {
        self.debugPrint("Finished scanning")
        self.centralManager.stopScan()
        
        self.delegate?.bleDidFinishScanning(self)
    }
    
    // MARK: Public methods
    
    public func startScanning(timeout: NSTimeInterval, serviceUUIDs: [NSString]? = nil) -> Bool {
        if self.centralManager.state != .PoweredOn {
            self.debugPrint("Unable to start scanning, device is powered off or not available")
            self.delegate?.bleDidFinishScanning(self)
            return false
        }
        
        if (self.centralManager.isScanning) {
            self.debugPrint("Already scanning for peripherals")
            self.delegate?.bleDidFinishScanning(self)
            return false
        }
        
        self.debugPrint("Scanning started")
        
        NSTimer.scheduledTimerWithTimeInterval(timeout, target: self, selector: #selector(BLE.scanTimeout), userInfo: nil, repeats: false)
        
        var services:[CBUUID] = []
        if (self.serviceUUID != nil) {
            services.append(CBUUID(string: self.serviceUUID!))
        }
        if (serviceUUIDs != nil && serviceUUIDs?.count > 0) {
            for i in 0 ..< serviceUUIDs!.count {
                let uuid: CBUUID = CBUUID(string: serviceUUIDs![i] as String)
                services.append(uuid)
            }
        }
        self.centralManager.scanForPeripheralsWithServices(services, options: nil)
        
        return true
    }
    
    public func connectToPeripheral(peripheral: CBPeripheral) -> Bool {
        if (self.centralManager.state != .PoweredOn) {
            self.debugPrint("Couldn´t connect to peripheral")
            return false
        }
        
        self.debugPrint("Connecting to \(peripheral.name!) - \(peripheral.identifier.UUIDString)")
        
        self.centralManager.connectPeripheral(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(bool: true)])
        
        return true
    }
    
    public func disconnectFromPeripheral(peripheral: CBPeripheral) -> Bool {
        if (self.centralManager.state != .PoweredOn) {
            self.debugPrint("BlueTooth is powered off or not available, can not disconnect peripheral")
            return false
        }
        
        self.centralManager.cancelPeripheralConnection(peripheral)
        
        return true
    }
    
    public func disconnectActivePeripheral() {
        if (self.activePeripheral != nil) {
            self.disconnectFromPeripheral(self.activePeripheral!)
        }
    }
    
    public func read(characteristicsUUID: String) throws {
        guard let char: CBCharacteristic = self.characteristics[characteristicsUUID] else {
            throw BLEError.UUIDNotFoundInAvailableCharacteristics
        }
        
        self.activePeripheral?.readValueForCharacteristic(char)
    }
    
    public func write(data: NSData, characteristicsUUID: String, writeType: CBCharacteristicWriteType = .WithoutResponse) throws {
        guard let char: CBCharacteristic = self.characteristics[characteristicsUUID] else {
            throw BLEError.UUIDNotFoundInAvailableCharacteristics
        }
        
        self.activePeripheral?.writeValue(data, forCharacteristic: char, type: writeType)
    }
    
    public func enableNotifications(enable: Bool, characteristicsUUID: String) throws {
        guard let char: CBCharacteristic = self.characteristics[characteristicsUUID] else {
            throw BLEError.UUIDNotFoundInAvailableCharacteristics
        }
        
        self.activePeripheral?.setNotifyValue(enable, forCharacteristic: char)
    }
    
    public func readRSSI(peripheral: CBPeripheral, completion: (peripheral: CBPeripheral, RSSI: NSNumber?, error: NSError?) -> ()) {
        self.rssiCompletionHandlers = [peripheral: completion]
        self.activePeripheral?.readRSSI()
    }
    
    // MARK: CBCentralManager delegate
    
    public func centralManagerDidUpdateState(central: CBCentralManager) {
        switch central.state {
        case .Unknown:
            self.debugPrint("Central manager state: Unknown")
            break
            
        case .Resetting:
            self.debugPrint("Central manager state: Resetting")
            break
            
        case .Unsupported:
            self.debugPrint("Central manager state: Unsupported")
            break
            
        case .Unauthorized:
            self.debugPrint("Central manager state: Unauthorized")
            break
            
        case .PoweredOff:
            self.debugPrint("Central manager state: Powered off")
            break
            
        case .PoweredOn:
            self.debugPrint("Central manager state: Powered on")
            break
        }
        
        self.delegate?.bleDidUpdateState(self, state: central.state)
    }
    
    public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        self.debugPrint("Found \(peripheral.name!): \(peripheral.identifier.UUIDString) RSSI: \(RSSI)")
        
        for i in 0 ..< self.peripherals.count {
            let p = self.peripherals[i] as CBPeripheral
            
            if (p.identifier.UUIDString == peripheral.identifier.UUIDString) {
                self.peripherals[i] = peripheral
                
                return
            }
        }
        
        self.peripherals.append(peripheral)
        
        self.delegate?.bleDidDiscoverPeripherals(self, peripherals: self.peripherals)
    }
    
    public func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        self.debugPrint("Could not connect to \(peripheral.name!) (\(peripheral.identifier.UUIDString)): \(error!.description)")
        
        self.delegate?.bleFailedConnectToPeripheral(self, peripheral: peripheral)
    }
    
    public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        self.debugPrint("Connected to \(peripheral.name!) \(peripheral.identifier.UUIDString)")
        
        self.activePeripheral = peripheral
        
        self.activePeripheral?.delegate = self
        self.activePeripheral?.discoverServices(self.serviceCBUUIDs)
        
        self.delegate?.bleDidConnectToPeripheral(self, peripheral: peripheral)
    }
    
    public func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        var text = "Disconnected from \(peripheral.name!) - \(peripheral.identifier.UUIDString)"
        
        if (error != nil) {
            text += ". Error: \(error!.description)"
        }
        
        self.debugPrint(text)
        
        self.activePeripheral?.delegate = nil
        self.activePeripheral = nil
        self.characteristics.removeAll(keepCapacity: false)
        
        self.delegate?.bleDidDisconnectFromPeripheral(self, peripheral: peripheral)
    }
    
    // MARK: Debugging
    
    private func debugPrint(message: String) {
        if (self.debugMode == true) {
            print(message)
        }
    }
    
    // MARK: CBPeripheral delegate
    
    public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if (error != nil) {
            self.debugPrint("Error discovering services for \(peripheral.name!): \(error!.description)")
            return
        }
        
        self.debugPrint("Found services for \(peripheral.name!): \(peripheral.services!)")
        
        for service: CBService in peripheral.services! {
            peripheral.discoverCharacteristics(self.usedCharacteristicsUUIDs, forService: service)
        }
    }
    
    public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if (error != nil) {
            self.debugPrint("Error discovering characteristics for \(peripheral.name!): \(error!.description)")
            return
        }
        
        self.debugPrint("Found characteristics for \(peripheral.name!): \(service.characteristics)")
        
        for characteristic in service.characteristics! {
            self.characteristics[characteristic.UUID.UUIDString] = characteristic
        }
    }
    
    public func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if (error != nil) {
            self.debugPrint("Error updating value on \(peripheral.name!): \(error!.description)")
            return
        }
        
        self.delegate?.bleDidReceiveData(self, peripheral: peripheral, characteristic: characteristic.UUID.UUIDString, data: characteristic.value)
    }
    
    public func peripheral(peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: NSError?) {
        if (self.rssiCompletionHandlers![peripheral] != nil) {
            self.rssiCompletionHandlers![peripheral]?(peripheral, RSSI, error)
            self.rssiCompletionHandlers![peripheral] = nil
        }
    }
    
}
