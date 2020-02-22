//
//  CentralManagerProxy.swift
//  Harald
//
//  Created by Andrew Shepard on 2/18/20.
//  Copyright © 2020 Andrew Shepard. All rights reserved.
//

import Foundation
import Combine
import CoreBluetooth

public struct DiscoveryInfo {
    public typealias AdPacket = [String: Any]
    
    let peripheral: CBPeripheral
    let packet: AdPacket
    let rssi: Double
}

public final class CentralManagerProxy: NSObject {
    
    /// Emits with state changes from the `CBCentalManager`. Initially set the `.unknown`
    public var statePublisher: AnyPublisher<CBManagerState, Never> {
        return _statePublisher.eraseToAnyPublisher()
    }
    private let _statePublisher = CurrentValueSubject<CBManagerState, Never>(CBManagerState.unknown)
    
    /// Emits with discovered peripherals from the `CBCentralManager`. The manager must be scanning before
    /// peripherals will emit.
    public var peripheralPublisher: AnyPublisher<Result<DiscoveryInfo, Error>, Never> {
        return _peripheralPublisher.eraseToAnyPublisher()
    }
    private let _peripheralPublisher = PassthroughSubject<Result<DiscoveryInfo, Error>, Never>()
    
    /// Emits with information about the connected peripheral. Private `PassthroughSubject` used to handle
    /// delegate callbacks from `centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)`
    private var peripheralConnectionPublisher: PassthroughSubject<CBPeripheral, Error>?
    
    /// The `CBCentralManager` associated with the proxy.
    let manager: CBCentralManager
    
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
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        _statePublisher.send(central.state)
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let discoveryInfo = DiscoveryInfo(
            peripheral: peripheral,
            packet: advertisementData,
            rssi: RSSI.doubleValue
        )
        _peripheralPublisher.send(.success(discoveryInfo))
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard let error = error else { return }
        guard let publisher = peripheralConnectionPublisher else { return }
        publisher.send(completion: .failure(error))
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let publisher = peripheralConnectionPublisher else { return }
        publisher.send(peripheral)
    }
}
