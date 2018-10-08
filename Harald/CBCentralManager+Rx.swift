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

typealias AdvertisementPacket = [String: Any]
typealias Discovery = (peripheral: CBPeripheral, packet: AdvertisementPacket, rssi: NSNumber)

extension Reactive where Base: CBCentralManager {
    
    private enum CBCentralManagerRxError: Error {
        case signatureMismatch
    }
    
    var discoveredPeripheral: Observable<Discovery> {
        let selector = #selector(
            CBCentralManagerDelegate.centralManager(_:didDiscover:advertisementData:rssi:)
        )
        
        return RxCBCentralManagerDelegateProxy.proxy(for: base)
            .methodInvoked(selector)
            .map { params -> Discovery in
                guard
                    let peripheral = params[1] as? CBPeripheral,
                    let packet = params[2] as? [String: Any],
                    let rssi = params[3] as? NSNumber
                else {
                    throw CBCentralManagerRxError.signatureMismatch
                }
                
                return (peripheral: peripheral, packet: packet, rssi: rssi)
            }
            .catchError { error -> Observable<Discovery> in
                return Observable.error(error)
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
                guard let error = params[2] as? Error else {
                    return CBCentralManagerRxError.signatureMismatch
                }
                
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
                guard let connected = params[1] as? CBPeripheral else {
                    throw CBCentralManagerRxError.signatureMismatch
                }
                
                return connected
            }
            .filter { $0 == peripheral }
            .take(1)
            .asSingle()
            .catchError { (error) -> Single<CBPeripheral> in
                return Single.error(error)
            }
        
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
                guard let disconnected = params[1] as? CBPeripheral else {
                    throw CBCentralManagerRxError.signatureMismatch
                }
                
                return disconnected
            }
            .filter { $0 == peripheral }
            .take(1)
            .asObservable()
            .catchError { (error) -> Observable<CBPeripheral> in
                return Observable.error(error)
            }
        
        self.base.cancelPeripheralConnection(peripheral)
        
        return result
    }
}
