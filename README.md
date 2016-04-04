# BLE

[![CI Status](http://img.shields.io/travis/manGoweb/BLE.svg?style=flat)](https://travis-ci.org/manGoweb/BLE)
[![Version](https://img.shields.io/cocoapods/v/BLE.svg?style=flat)](http://cocoapods.org/pods/BLE)
[![License](https://img.shields.io/cocoapods/l/BLE.svg?style=flat)](http://cocoapods.org/pods/BLE)
[![Platform](https://img.shields.io/cocoapods/p/BLE.svg?style=flat)](http://cocoapods.org/pods/BLE)

Swift wrapper around CoreBluetooth. Library allows you to connect to BLE devices, read and write data to them


## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

```swift
private let ble: BLE = BLE()

// Enable debug mode
self.ble.debugMode = true

// Set delegate
self.ble.delegate = self

// Scan for all devices
self.ble.startScanning(10) // Scan for 10 seconds

// Scan for some UUIDs only
self.ble.startScanning(10, serviceUUIDs: ["713D0000-503E-4C75-BA94-3148F18D941E"]) // Scan for 10 seconds

// Write three values to one service
var buffer: [UInt8] = [1, 0, 100]
let data: NSData = NSData(bytes: buffer, length: 3)
try! self.ble?.write(data, characteristicsUUID: "713D0003-503E-4C75-BA94-3148F18D941E")
```
 
## Example application

![Screenshot 1](https://raw.githubusercontent.com/manGoweb/BLE/master/_orig/home.png "Screenshot 1")

## Requirements

Needs to run on a device, not simulator

## Installation

BLE is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "BLE"
```

## Author

Ondrej Rafaj, rafaj@mangoweb.cz

## License

BLE is available under the MIT license. See the LICENSE file for more info.
