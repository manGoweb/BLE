//
//  BLE.swift
//
//  Created by Ondrej Rafaj on 28/03/2016.
//  Copyright © 2016 manGoweb.cz. All rights reserved.
//

import Foundation
import CoreBluetooth


public protocol BLEDelegate {
    func bleDidUpdateState(ble: BLE, state: CBManagerState)
    func bleDidDiscoverPeripherals(ble: BLE, peripherals: [CBPeripheral])
    func bleDidFinishScanning(ble: BLE)
    func bleDidConnectToPeripheral(ble: BLE, peripheral: CBPeripheral)
    func bleFailedConnectToPeripheral(ble: BLE, peripheral: CBPeripheral)
    func bleDidDisconnectFromPeripheral(ble: BLE, peripheral: CBPeripheral)
    func bleDidReceiveData(ble: BLE, peripheral: CBPeripheral, characteristic: String, data: NSData?)
}


public enum BLEError: Error {
    case UUIDNotFoundInAvailableCharacteristics
}


public class BLE: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    public var debugMode: Bool = true
    
    public var delegate: BLEDelegate?
    
    public var serviceUUID: String? {
        get {
            if (self.serviceCBUUIDs != nil && self.serviceCBUUIDs?.count == 1) {
                let uuid: CBUUID = (self.serviceCBUUIDs?.first)! as CBUUID
                return uuid.uuidString
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
                    uuidStrings[i] = uuid.uuidString
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
        
        self.delegate?.bleDidFinishScanning(ble: self)
    }
    
    // MARK: Public methods
    
    public func startScanning(timeout: TimeInterval, serviceUUIDs: [NSString]? = nil) -> Bool {
        if self.centralManager.state != .poweredOn {
            self.debugPrint("Unable to start scanning, device is powered off or not available")
            self.delegate?.bleDidFinishScanning(ble: self)
            return false
        }
        
        if (self.centralManager.isScanning) {
            self.debugPrint("Already scanning for peripherals")
            self.delegate?.bleDidFinishScanning(ble: self)
            return false
        }
        
        self.debugPrint("Scanning started")
        
        Timer.scheduledTimer(timeInterval: timeout, target: self, selector: #selector(BLE.scanTimeout), userInfo: nil, repeats: false)
        
        var services:[CBUUID] = []
        if (self.serviceUUID != nil) {
            services.append(CBUUID(string: self.serviceUUID!))
        }
        if let uuids = serviceUUIDs, uuids.count > 0 {
            for i in 0 ..< serviceUUIDs!.count {
                let uuid: CBUUID = CBUUID(string: serviceUUIDs![i] as String)
                services.append(uuid)
            }
        }
        self.centralManager.scanForPeripherals(withServices: services, options: nil)
        
        return true
    }
    
    public func connectToPeripheral(peripheral: CBPeripheral) -> Bool {
        if (self.centralManager.state != .poweredOn) {
            self.debugPrint("Couldn´t connect to peripheral")
            return false
        }
        
        self.debugPrint("Connecting to \(peripheral.name) - \(peripheral.identifier.uuidString)")
        
        self.centralManager.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey : NSNumber(value: true)])
        
        return true
    }
    
    public func disconnectFromPeripheral(peripheral: CBPeripheral) -> Bool {
        if (self.centralManager.state != .poweredOn) {
            self.debugPrint("BlueTooth is powered off or not available, can not disconnect peripheral")
            return false
        }
        
        self.centralManager.cancelPeripheralConnection(peripheral)
        
        return true
    }
    
    public func disconnectActivePeripheral() {
        if (self.activePeripheral != nil) {
            _ = self.disconnectFromPeripheral(peripheral: self.activePeripheral!)
        }
    }
    
    public func read(characteristicsUUID: String) throws {
        guard let char: CBCharacteristic = self.characteristics[characteristicsUUID] else {
            throw BLEError.UUIDNotFoundInAvailableCharacteristics
        }
        
        self.activePeripheral?.readValue(for: char)
    }
    
    public func write(data: NSData, characteristicsUUID: String, writeType: CBCharacteristicWriteType = .withoutResponse) throws {
        guard let char: CBCharacteristic = self.characteristics[characteristicsUUID] else {
            throw BLEError.UUIDNotFoundInAvailableCharacteristics
        }
        
        self.activePeripheral?.writeValue(data as Data, for: char, type: writeType)
    }
    
    public func enableNotifications(enable: Bool, characteristicsUUID: String) throws {
        guard let char: CBCharacteristic = self.characteristics[characteristicsUUID] else {
            throw BLEError.UUIDNotFoundInAvailableCharacteristics
        }
        
        self.activePeripheral?.setNotifyValue(enable, for: char)
    }
    
    public func readRSSI(peripheral: CBPeripheral, completion: @escaping (CBPeripheral, NSNumber?, NSError?) -> ()) {
        self.rssiCompletionHandlers = [peripheral: completion]
        self.activePeripheral?.readRSSI()
    }
    
    // MARK: CBCentralManager delegate
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            self.debugPrint("Central manager state: Unknown")
            break
            
        case .resetting:
            self.debugPrint("Central manager state: Resetting")
            break
            
        case .unsupported:
            self.debugPrint("Central manager state: Unsupported")
            break
            
        case .unauthorized:
            self.debugPrint("Central manager state: Unauthorized")
            break
            
        case .poweredOff:
            self.debugPrint("Central manager state: Powered off")
            break
            
        case .poweredOn:
            self.debugPrint("Central manager state: Powered on")
            break
        }
        
        self.delegate?.bleDidUpdateState(ble: self, state: central.state)
    }
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.debugPrint("Found \(peripheral.name): \(peripheral.identifier.uuidString) RSSI: \(RSSI)")
        
        for i in 0 ..< self.peripherals.count {
            let p = self.peripherals[i] as CBPeripheral
            
            if (p.identifier.uuidString == peripheral.identifier.uuidString) {
                self.peripherals[i] = peripheral
                
                return
            }
        }
        
        self.peripherals.append(peripheral)
        
        self.delegate?.bleDidDiscoverPeripherals(ble: self, peripherals: self.peripherals)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.debugPrint("Could not connect to \(peripheral.name) (\(peripheral.identifier.uuidString)): \(error?.localizedDescription)")
        
        self.delegate?.bleFailedConnectToPeripheral(ble: self, peripheral: peripheral)
    }
    
    public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        self.debugPrint("Connected to \(peripheral.name) \(peripheral.identifier.uuidString)")
        
        self.activePeripheral = peripheral
        
        self.activePeripheral?.delegate = self
        self.activePeripheral?.discoverServices(self.serviceCBUUIDs)
        
        self.delegate?.bleDidConnectToPeripheral(ble: self, peripheral: peripheral)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        var text = "Disconnected from \(peripheral.name) - \(peripheral.identifier.uuidString)"
        
        if let e = error  {
            text += ". Error: \(e.localizedDescription)"
        }
        
        self.debugPrint(text)
        
        self.activePeripheral?.delegate = nil
        self.activePeripheral = nil
        self.characteristics.removeAll(keepingCapacity: false)
        
        self.delegate?.bleDidDisconnectFromPeripheral(ble: self, peripheral: peripheral)
    }
    
    // MARK: Debugging
    
    private func debugPrint(_ message: String) {
        if (self.debugMode == true) {
            print(message)
        }
    }
    
    // MARK: CBPeripheral delegate
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let e = error {
            self.debugPrint("Error discovering services for \(peripheral.name): \(e.localizedDescription)")
            return
        }
        
        self.debugPrint("Found services for \(peripheral.name): \(peripheral.services!)")
        
        for service: CBService in peripheral.services! {
            peripheral.discoverCharacteristics(self.usedCharacteristicsUUIDs, for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let e = error {
            self.debugPrint("Error discovering characteristics for \(peripheral.name): \(e.localizedDescription)")
            return
        }
        
        self.debugPrint("Found characteristics for \(peripheral.name): \(service.characteristics)")
        
        for characteristic in service.characteristics! {
            self.characteristics[characteristic.uuid.uuidString] = characteristic
            do {
                try enableNotifications(enable: true, characteristicsUUID: characteristic.uuid.uuidString)
            }
            catch {
                print("Error - \(characteristic.uuid.uuidString) not found in available characteristics")
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let e = error {
            self.debugPrint("Error updating value on \(peripheral.name): \(e.localizedDescription)")
            return
        }
        
        self.delegate?.bleDidReceiveData(ble: self, peripheral: peripheral, characteristic: characteristic.uuid.uuidString, data: characteristic.value as NSData?)
    }

    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if (self.rssiCompletionHandlers![peripheral] != nil) {
            self.rssiCompletionHandlers![peripheral]?(peripheral, RSSI, error as NSError?)
            self.rssiCompletionHandlers![peripheral] = nil
        }
    }
    
}
