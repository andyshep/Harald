//
//  CBCentralManager+Rx.swift
//  Harald
//
//  Created by Andrew Shepard on 4/22/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import CoreBluetooth
import RxSwift
import RxCocoa

extension Reactive where Base: CBCentralManager {
    
    var discoveredPeripheral: Observable<CBPeripheral> {
        let selector = #selector(
            CBCentralManagerDelegate.centralManager(_:didDiscover:advertisementData:rssi:)
        )
        
        return RxCBCentralManagerDelegateProxy.proxy(for: base)
            .methodInvoked(selector)
            .map { params -> CBPeripheral in
                let service = params[1] as! CBPeripheral
                return service
        }
    }
    
    var state: Observable<CBManagerState> {
        return RxCBCentralManagerDelegateProxy.proxy(for: base)
            .centralManagerStateSubject
            .asObservable()
    }
    
    var error: Observable<Error> {
        let selector = #selector(
            CBCentralManagerDelegate.centralManager(_:didFailToConnect:error:)
        )
        
        return RxCBCentralManagerDelegateProxy.proxy(for: base)
            .methodInvoked(selector)
            .map { params -> Error in
                let error = params[2] as! Error
                return error
            }
        
    }
    
    func connect(to peripheral: CBPeripheral) -> Single<CBPeripheral> {
        let selector = #selector(
            CBCentralManagerDelegate.centralManager(_:didConnect:)
        )
        
        let result = RxCBCentralManagerDelegateProxy.proxy(for: base)
            .methodInvoked(selector)
            .map { (params) -> CBPeripheral in
                let connected = params[1] as! CBPeripheral
                return connected
            }
            .filter { $0 == peripheral }
            .take(1)
            .asSingle()
        
        self.base.connect(peripheral, options: [:])
        
        return result
    }
    
    func disconnect(from peripheral: CBPeripheral) -> Observable<CBPeripheral> {
        let selector = #selector(
            CBCentralManagerDelegate.centralManager(_:didDisconnectPeripheral:error:)
        )
        
        let result = RxCBCentralManagerDelegateProxy.proxy(for: base)
            .methodInvoked(selector)
            .map { (params) -> CBPeripheral in
                let disconnected = params[1] as! CBPeripheral
                return disconnected
            }
            .filter { $0 == peripheral }
            .take(1)
            .asObservable()
        
        self.base.cancelPeripheralConnection(peripheral)
        
        return result
    }
}
