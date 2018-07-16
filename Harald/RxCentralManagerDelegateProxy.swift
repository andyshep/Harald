//
//  RxCBCentralManagerDelegateProxy.swift
//  Harald
//
//  Created by Andrew Shepard on 4/21/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import CoreBluetooth
import RxSwift
import RxCocoa

extension CBCentralManager: HasDelegate {
    public typealias Delegate = CBCentralManagerDelegate
}

public final class RxCBCentralManagerDelegateProxy
    : DelegateProxy<CBCentralManager, CBCentralManagerDelegate>
    , DelegateProxyType
    , CBCentralManagerDelegate {
    
    // MARK: Events
    
    internal lazy var centralManagerStateSubject = PublishSubject<CBManagerState>()
    internal lazy var peripheralConnectionErrorSubject = PublishSubject<(CBPeripheral, Error)>()
    
    // MARK: Fields
    
    private let bag = DisposeBag()
    
    // MARK: Lifecycle
    
    private init(parent: CBCentralManager) {
        super.init(parentObject: parent, delegateProxy: RxCBCentralManagerDelegateProxy.self)
    }
    
    // MARK: <DelegateProxyType>
    
    public static func registerKnownImplementations() {
        self.register { (parent) -> RxCBCentralManagerDelegateProxy in
            return RxCBCentralManagerDelegateProxy(parent: parent)
        }
    }
    
    public static func currentDelegate(for object: CBCentralManager) -> CBCentralManagerDelegate? {
        return object.delegate
    }

    public static func setCurrentDelegate(_ delegate: CBCentralManagerDelegate?, to object: CBCentralManager) {
        object.delegate = delegate
    }
    
    // MARK: <CBCentralManagerDelegate>
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralManagerStateSubject.onNext(central.state)
    }
}
