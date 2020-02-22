//
//  DiscoveredPeripheral.swift
//  Harald
//
//  Created by Andrew Shepard on 7/21/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import CoreBluetooth

typealias Packet = [String: Any]

@objc class DiscoveredPeripheral: NSObject {
    @objc let peripheral: CBPeripheral
    @objc let packet: Packet
    @objc let rssi: Double
    
    init(peripheral: CBPeripheral, packet: [String: Any], rssi: Double) {
        self.peripheral = peripheral
        self.packet = packet
        self.rssi = rssi
        super.init()
    }
    
    init(discovery: DiscoveryInfo) {
        self.peripheral = discovery.peripheral
        self.packet = discovery.packet
        self.rssi = discovery.rssi
        super.init()
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let discovered = object as? DiscoveredPeripheral else { return false }
        return discovered.peripheral.isEqual(to: self.peripheral)
    }
}
