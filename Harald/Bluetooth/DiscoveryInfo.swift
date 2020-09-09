//
//  DiscoveryInfo.swift
//  Harald
//
//  Created by Andrew Shepard on 9/5/20.
//  Copyright © 2020 Andrew Shepard. All rights reserved.
//

import Foundation
import CoreBluetooth
import Combine

public struct DiscoveryInfo {
    public typealias AdPacket = [String: AnyHashable]
    
    let peripheral: CBPeripheral
    let packet: AdPacket
    let rssi: Double
    let timestamp: Date
    
    init(peripheral: CBPeripheral, packet: AdPacket, rssi: Double, timestamp: Date) {
        self.peripheral = peripheral
        self.packet = packet
        self.rssi = rssi
        self.timestamp = timestamp
    }
    
    init(_ other: DiscoveryInfo, rssi: Double, packet: AdPacket, timestamp: Date) {
        var existingPacket = other.packet
        existingPacket.addItems(from: packet)
        
        self.init(peripheral: other.peripheral, packet: existingPacket, rssi: rssi, timestamp: timestamp)
    }
}

extension Array where Element == DiscoveryInfo {
    mutating func refresh(using discovery: DiscoveryInfo) {
        guard contains(where: { $0.peripheral == discovery.peripheral }) else {
            return append(discovery)
        }
        
        if let index = firstIndex(where: { $0.peripheral == discovery.peripheral }) {
            let updated = DiscoveryInfo(
                self[index],
                rssi: discovery.rssi,
                packet: discovery.packet,
                timestamp: Date()
            )
            
            remove(at: index)
            insert(updated, at: index)
        }
        
    }
    
    func refreshing(with discovery: DiscoveryInfo) -> [DiscoveryInfo] {
        guard count >= 0 else { return [discovery] }
        
        var existing = self
        if let index = existing.firstIndex(where: { $0.peripheral == discovery.peripheral }) {
            let updated = DiscoveryInfo(
                self[index],
                rssi: discovery.rssi,
                packet: discovery.packet,
                timestamp: Date()
            )
            
            existing.remove(at: index)
            existing.insert(updated, at: index)
        } else {
            existing.append(discovery)
        }
        
        return existing
    }
    
    func filterDiscoveries(past interval: TimeInterval = 45.0) -> [DiscoveryInfo] {
        let now = Date()
        return filter { (info) -> Bool in
            return info.timestamp.addingTimeInterval(interval) >= now
        }
    }
}

private extension Dictionary where Value: Equatable {
    mutating func addItems(from other: [Key: Value]) {
        other.forEach { (key, value) in
            if let found = self[key] {
                if found != value {
                    self[key] = value
                }
            } else {
                self[key] = value
            }
        }
    }
}
