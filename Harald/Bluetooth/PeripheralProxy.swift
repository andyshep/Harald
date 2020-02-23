//
//  PeripheralProxy.swift
//  Harald
//
//  Created by Andrew Shepard on 2/22/20.
//  Copyright © 2020 Andrew Shepard. All rights reserved.
//

import Foundation
import Combine
import CoreBluetooth

public final class PeripheralProxy: NSObject {
    
    public var discoveredServicesPublisher: AnyPublisher<[CBService], Error> {
        return _discoveredServicesSubject.eraseToAnyPublisher()
    }
    private let _discoveredServicesSubject = PassthroughSubject<[CBService], Error>()
    
    public var discoveredCharacteristicsPublisher: AnyPublisher<(CBService, [CBCharacteristic]), Never> {
        return _discoveredCharacteristicsSubject.eraseToAnyPublisher()
    }
    private let _discoveredCharacteristicsSubject = PassthroughSubject<(CBService, [CBCharacteristic]), Never>()
    
    public var discoveredCharacteristicDescriptorsPublisher: AnyPublisher<(CBCharacteristic, [CBDescriptor]), Never> {
        return _discoveredCharacteristicDescriptorsSubject.eraseToAnyPublisher()
    }
    private let _discoveredCharacteristicDescriptorsSubject = PassthroughSubject<(CBCharacteristic, [CBDescriptor]), Never>()
    
    public var updatedCharacteristicValuePublisher: AnyPublisher<CBCharacteristic, Never> {
        return _updatedCharacteristicValueSubject.eraseToAnyPublisher()
    }
    private let _updatedCharacteristicValueSubject = PassthroughSubject<CBCharacteristic, Never>()

    let peripheral: CBPeripheral
    
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        
        peripheral.delegate = self
    }
    
    deinit {
        peripheral.delegate = nil
    }
}

// MARK: <CBPeripheralDelegate>

extension PeripheralProxy: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        _discoveredServicesSubject.send(peripheral.services ?? [])
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let characteristics = service.characteristics ?? []
        _discoveredCharacteristicsSubject.send((service, characteristics))
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        let descriptors = characteristic.descriptors ?? []
        _discoveredCharacteristicDescriptorsSubject.send((characteristic, descriptors))
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        _updatedCharacteristicValueSubject.send(characteristic)
    }
}
