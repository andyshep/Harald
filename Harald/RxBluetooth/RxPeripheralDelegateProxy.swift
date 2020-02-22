//
//  RxPeripheralDelegateProxy.swift
//  Harald
//
//  Created by Andrew Shepard on 4/22/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import CoreBluetooth
import RxSwift
import RxCocoa

extension CBPeripheral: HasDelegate {
    public typealias Delegate = CBPeripheralDelegate
}

public final class RxCBPeripheralDelegateProxy
    : DelegateProxy<CBPeripheral, CBPeripheralDelegate>
    , DelegateProxyType
    , CBPeripheralDelegate {
    
    // MARK: Events
    
    internal lazy var discoveredServicesSubject = PublishSubject<[CBService]>()
    internal lazy var discoveredCharacteristicsSubject = PublishSubject<(CBService, [CBCharacteristic])>()
    internal lazy var discoveredCharacteristicDescriptorsSubject = PublishSubject<(CBCharacteristic, [CBDescriptor])>()
    
    internal lazy var updatedCharacteristicValueSubject = PublishSubject<CBCharacteristic>()
    
    // MARK: Fields
    
    private let bag = DisposeBag()
    
    // MARK: Lifecycle
    
    private init(parent: CBPeripheral) {
        super.init(parentObject: parent, delegateProxy: RxCBPeripheralDelegateProxy.self)
        parent.delegate = self
    }

    // MARK: <DelegateProxyType>
    
    public static func registerKnownImplementations() {
        self.register { (parent) -> RxCBPeripheralDelegateProxy in
            return RxCBPeripheralDelegateProxy(parent: parent)
        }
    }
    
    public static func currentDelegate(for object: CBPeripheral) -> CBPeripheralDelegate? {
        return object.delegate
    }

    public static func setCurrentDelegate(_ delegate: CBPeripheralDelegate?, to object: CBPeripheral) {
        object.delegate = delegate
    }
    
    // MARK: <CBPeripheralDelegate>
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        discoveredServicesSubject.onNext(peripheral.services ?? [])
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let characteristics = service.characteristics ?? []
        discoveredCharacteristicsSubject.onNext((service, characteristics))
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        let descriptors = characteristic.descriptors ?? []
        discoveredCharacteristicDescriptorsSubject.onNext((characteristic, descriptors))
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        updatedCharacteristicValueSubject.onNext(characteristic)
    }
}
