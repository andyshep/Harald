//
//  BluetoothService.swift
//  Harald
//
//  Created by Andrew Shepard on 2/24/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import CoreBluetooth
import RxSwift

class BluetoothService: NSObject {
    
    var peripherials: Observable<[CBPeripheral]> {
        return discoveredPeripherials.asObservable()
    }
    
    private var discoveredPeripherials = Variable<[CBPeripheral]>([])
    
    lazy var centralManager: CBCentralManager = {
        return CBCentralManager(delegate: self, queue: nil)
    }()
    
    public func startScanning() {
        centralManager.scanForPeripherals(withServices: nil)
    }
}

extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("unknown state")
        case .resetting:
            print("retting")
        case .unsupported:
            print("unsupported")
        case .unauthorized:
            print("unauth")
        case .poweredOff:
            print("off")
        case .poweredOn:
            print("on")
            startScanning()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if !discoveredPeripherials.value.contains(peripheral) {
            discoveredPeripherials.value.append(peripheral)
        }
    }
}
