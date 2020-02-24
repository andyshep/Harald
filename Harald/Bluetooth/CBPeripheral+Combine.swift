//
//  CBPeripheral+Combine.swift
//  Harald
//
//  Created by Andrew Shepard on 2/22/20.
//  Copyright © 2020 Andrew Shepard. All rights reserved.
//

import Foundation
import Combine
import CoreBluetooth

extension CBPeripheral {
    
    /// Publisher that emits a collection of  `CBService` objects or an `Error`.
    public typealias ServicesPublisher = AnyPublisher<[CBService], Error>
    
    /// Emits with the discovered services belonging to the `CBPeripheral`.
    public var discoveredServicesPublisher: ServicesPublisher {
        let publisher = proxy.discoveredServicesPublisher
        discoverServices(nil)
        return publisher
    }
    
    fileprivate var proxy: PeripheralProxy {
        get {
            guard let value = objc_getAssociatedObject(self, &_peripheralProxyKey) as? PeripheralProxy else {
                let proxy = PeripheralProxy(peripheral: self)
                objc_setAssociatedObject(self, &_peripheralProxyKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return proxy
            }
            return value
        }
    }
}

extension CBService {
    
    /// Publisher that emits a collection of  `CBCharacteristic` objects or an `Error`.
    public typealias CharacteristicsPublisher = AnyPublisher<(CBService, [CBCharacteristic]), Error>
    
    /// Emits with the discoverered charactertics belonging to the service
    var discoveredCharacteristics: CharacteristicsPublisher {
        let publisher = peripheral.proxy
            .discoveredCharacteristicsPublisher
        
        peripheral.discoverCharacteristics([], for: self)
        return publisher
    }
}

extension CBCharacteristic {
    
    /// Publisher that emits with the value of the `CBCharacteristic`
    typealias ValuePublisher = AnyPublisher<Data?, Never>
    
    /// Publisher that emits with the set of descriptors associated with the `CBCharacteristic`
    typealias CharacteristicDescriptorsPublisher = AnyPublisher<(CBCharacteristic, [CBDescriptor]), Never>
    
    /// Emits with the discovered characteristic descriptors
    var discoveredCharacteristicDescriptorsPublisher: CharacteristicDescriptorsPublisher {
        return service.peripheral.proxy
            .discoveredCharacteristicDescriptorsPublisher
    }
    
    /// Emits with the characteristic value
    var valuePublisher: ValuePublisher {
        let publisher = service.peripheral.proxy
            .updatedCharacteristicValuePublisher
            .filter { (characteristic) -> Bool in
                return self.uuid == characteristic.uuid
            }
            .map { (characteristic) -> Data? in
                return characteristic.value
            }
            .eraseToAnyPublisher()
        
        service.peripheral.readValue(for: self)
        return publisher
    }
}

private var _peripheralProxyKey: UInt8 = 0
private class PeripheralProxy: NSObject {
    
    var discoveredServicesPublisher: AnyPublisher<[CBService], Error> {
        return _discoveredServicesSubject.eraseToAnyPublisher()
    }
    private let _discoveredServicesSubject = PassthroughSubject<[CBService], Error>()
    
    var discoveredCharacteristicsPublisher: AnyPublisher<(CBService, [CBCharacteristic]), Error> {
        return _discoveredCharacteristicsSubject.eraseToAnyPublisher()
    }
    private let _discoveredCharacteristicsSubject = PassthroughSubject<(CBService, [CBCharacteristic]), Error>()
    
    var discoveredCharacteristicDescriptorsPublisher: AnyPublisher<(CBCharacteristic, [CBDescriptor]), Never> {
        return _discoveredCharacteristicDescriptorsSubject.eraseToAnyPublisher()
    }
    private let _discoveredCharacteristicDescriptorsSubject = PassthroughSubject<(CBCharacteristic, [CBDescriptor]), Never>()
    
    var updatedCharacteristicValuePublisher: AnyPublisher<CBCharacteristic, Never> {
        return _updatedCharacteristicValueSubject.eraseToAnyPublisher()
    }
    private let _updatedCharacteristicValueSubject = PassthroughSubject<CBCharacteristic, Never>()

    private let peripheral: CBPeripheral
    
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
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        _discoveredServicesSubject.send(peripheral.services ?? [])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let characteristics = service.characteristics ?? []
        _discoveredCharacteristicsSubject.send((service, characteristics))
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        let descriptors = characteristic.descriptors ?? []
        _discoveredCharacteristicDescriptorsSubject.send((characteristic, descriptors))
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        _updatedCharacteristicValueSubject.send(characteristic)
    }
}
