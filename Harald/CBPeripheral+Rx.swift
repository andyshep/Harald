//
//  CBPeripheralDelegate+Rx.swift
//  Harald
//
//  Created by Andrew Shepard on 4/22/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import CoreBluetooth
import RxSwift
import RxCocoa

extension Reactive where Base: CBPeripheral {
    var delegate: DelegateProxy<CBPeripheral, CBPeripheralDelegate> {
        return RxCBPeripheralDelegateProxy.proxy(for: base)
    }
    
    var discoveredServices: Observable<[CBService]> {
        let proxy = RxCBPeripheralDelegateProxy.proxy(for: base)
        base.discoverServices(nil)
        return proxy
            .discoveredServicesSubject
            .asObservable()
            .share(replay: 1, scope: .whileConnected)
    }
}

extension Reactive where Base: CBService {
    var discoveredCharacteristics: Observable<(CBService, [CBCharacteristic])> {
        let proxy = RxCBPeripheralDelegateProxy.proxy(for: base.peripheral)
        base.peripheral.discoverCharacteristics([], for: base)
        return proxy
            .discoveredCharacteristicsSubject
            .asObservable()
            .share(replay: 1, scope: .whileConnected)
    }
}

extension Reactive where Base: CBCharacteristic {
    var discoveredCharacteristicDescriptors: Observable<(CBCharacteristic, [CBDescriptor])> {
        let proxy = RxCBPeripheralDelegateProxy.proxy(for: base.service.peripheral)
        return proxy
            .discoveredCharacteristicDescriptorsSubject
            .asObservable()
            .share(replay: 1, scope: .whileConnected)
    }
    
    var value: Single<Data?> {
        let proxy = RxCBPeripheralDelegateProxy.proxy(for: base.service.peripheral)
        base.service.peripheral.readValue(for: base)
        return proxy
            .updatedCharacteristicValueSubject
            .filter { characteristic -> Bool in
                self.base.uuid == characteristic.uuid
            }
            .flatMapLatest { (characteristic) -> Observable<Data?> in
                let value = characteristic.value
                return Observable.just(value)
            }
            .take(1)
            .asSingle()
    }
}
