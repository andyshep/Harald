//
//  CBCentralManager+Combine.swift
//  Harald
//
//  Created by Andrew Shepard on 2/18/20.
//  Copyright © 2020 Andrew Shepard. All rights reserved.
//

import Foundation
import Combine
import CoreBluetooth
import os.log

public struct DiscoveryInfo {
    public typealias AdPacket = [String: Any]
    
    let peripheral: CBPeripheral
    let packet: AdPacket
    let rssi: Double
}

extension CBCentralManager {
    
    public typealias StatePublisher = AnyPublisher<CBManagerState, Never>
    public typealias PeripheralPublisher = AnyPublisher<CBPeripheral, Error>
    public typealias DiscoveryInfoPublisher = AnyPublisher<Result<DiscoveryInfo, Error>, Never>
    
    /// Emits with state changes from the `CBCentalManager`. Initially set the `.unknown`
    public var statePublisher: StatePublisher {
        return proxy.statePublisher
    }
    
    /// Emits with discovered peripherals from the `CBCentralManager`. The manager must be scanning before
    /// peripherals will emit.
    public var peripheralPublisher: DiscoveryInfoPublisher {
        return proxy.peripheralPublisher
    }
    
    /// Emits with information about the connected peripheral. Private `PassthroughSubject` used to handle
    /// delegate callbacks from `centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)`
    public func connect(to peripheral: CBPeripheral) -> PeripheralPublisher {
        return proxy.connect(to: peripheral)
    }
    
    private var proxy: CentralManagerProxy {
        get {
            guard let value = objc_getAssociatedObject(self, &_centralManagerProxyKey) as? CentralManagerProxy else {
                let proxy = CentralManagerProxy(manager: self)
                objc_setAssociatedObject(self, &_centralManagerProxyKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return proxy
            }
            return value
        }
    }
}

private var _centralManagerProxyKey: UInt8 = 0
private class CentralManagerProxy: NSObject {
    
    var statePublisher: AnyPublisher<CBManagerState, Never> {
        return _statePublisher.eraseToAnyPublisher()
    }
    private let _statePublisher = CurrentValueSubject<CBManagerState, Never>(CBManagerState.unknown)
    
    var peripheralPublisher: AnyPublisher<Result<DiscoveryInfo, Error>, Never> {
        return _peripheralPublisher.eraseToAnyPublisher()
    }
    private let _peripheralPublisher = PassthroughSubject<Result<DiscoveryInfo, Error>, Never>()
    
    private var peripheralConnectionPublisher: PassthroughSubject<CBPeripheral, Error>?
    
    private let manager: CBCentralManager
    
    init(manager: CBCentralManager) {
        self.manager = manager
        super.init()
        
        manager.delegate = self
    }
    
    deinit {
        manager.delegate = nil
    }
    
    func connect(to peripheral: CBPeripheral) -> AnyPublisher<CBPeripheral, Error> {
        peripheralConnectionPublisher?.send(completion: .finished)
        
        let publisher = PassthroughSubject<CBPeripheral, Error>()
        peripheralConnectionPublisher = publisher
        
        manager.connect(peripheral, options: nil)
        
        return publisher.eraseToAnyPublisher()
    }
}

// MARK: <CBCentralManagerDelegate>

extension CentralManagerProxy: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        os_log("%s: state changed to %d", log: OSLog.bluetooth, type: .debug, "\(#function)", central.state.rawValue)
        _statePublisher.send(central.state)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        os_log("%s: %@ found advertising with %@", log: OSLog.bluetooth, type: .debug, "\(#function)", peripheral, advertisementData)
        
        let discoveryInfo = DiscoveryInfo(
            peripheral: peripheral,
            packet: advertisementData,
            rssi: RSSI.doubleValue
        )
        _peripheralPublisher.send(.success(discoveryInfo))
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard let error = error else { return }
        guard let publisher = peripheralConnectionPublisher else { return }
        publisher.send(completion: .failure(error))
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        os_log("%s: connected to %@", log: .bluetooth, type: .debug, "\(#function)", peripheral)
        
        guard let publisher = peripheralConnectionPublisher else { return }
        publisher.send(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        os_log("%s: disconnected from %@", log: .bluetooth, type: .debug, "\(#function)", peripheral)
    }
}
