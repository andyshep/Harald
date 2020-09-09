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
import OSLog

extension CBCentralManager {
    
    /// Emits with state changes from the `CBCentalManager`. Initially set the `.unknown`
    public var statePublisher: AnyPublisher<CBManagerState, Never> {
        return proxy.statePublisher
    }
    
    /// Emits with discovered peripherals from the `CBCentralManager`. The manager must be scanning before
    /// peripherals will emit.
    public var peripheralPublisher: AnyPublisher<Result<DiscoveryInfo, Error>, Never> {
        return proxy.peripheralPublisher
    }
    
    /// Emits with cached discovered peripherals from the `CBCentralManager`.
    public var peripheralCachePublisher: AnyPublisher<[DiscoveryInfo], Never> {
        return proxy.peripheralCachePublisher
    }
    
    /// Emits with information about the connected peripheral. Private `PassthroughSubject` used to handle
    /// delegate callbacks from `centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)`
    public func connect(to peripheral: CBPeripheral) -> AnyPublisher<CBPeripheral, Error> {
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
private final class CentralManagerProxy: NSObject {
    
    /// Internally handles state changes from `CBManager`
    var statePublisher: AnyPublisher<CBManagerState, Never> {
        return _statePublisher.eraseToAnyPublisher()
    }
    private let _statePublisher = CurrentValueSubject<CBManagerState, Never>(CBManagerState.unknown)
    
    /// Internally handles discovery changes from `CBManager`
    var peripheralPublisher: AnyPublisher<Result<DiscoveryInfo, Error>, Never> {
        return _peripheralPublisher.eraseToAnyPublisher()
    }
    private let _peripheralPublisher = PassthroughSubject<Result<DiscoveryInfo, Error>, Never>()
    
    /// Stores the publisher used to track active connection request
    private var peripheralConnectionPublisher: PassthroughSubject<CBPeripheral, Error>?
    
    /// Internally handles and caches discovery changes from `CBManager`
    var peripheralCachePublisher: AnyPublisher<[DiscoveryInfo], Never> {
        return _peripheralCachePublisher.eraseToAnyPublisher()
    }
    private let _peripheralCachePublisher = CurrentValueSubject<[DiscoveryInfo], Never>.init([])
    
    /// The internal `CBManager` proxy object
    private let manager: CBCentralManager
    
    private var cancellables = Set<AnyCancellable>()
    
    init(manager: CBCentralManager) {
        self.manager = manager
        super.init()
        
        manager.delegate = self
        
        peripheralPublisher
            .compactMap { result -> DiscoveryInfo? in
                switch result {
                case .success(let info):
                    guard let _ = info.peripheral.name else { return nil }
                    return info
                case .failure(_):
                    return nil
                }
            }
            .combineLatest(peripheralCachePublisher)
            .map { (discovery, previousDiscoveries) -> [DiscoveryInfo] in
                return previousDiscoveries
                    .refreshing(with: discovery)
                    .filterDiscoveries(past: 70.0)
            }
            .sink { (discoveries) in
                self._peripheralCachePublisher.send(discoveries)
            }
            .store(in: &cancellables)
    }
    
    deinit {
        manager.delegate = nil
        cancellables.cancel()
    }
    
    /// Opens a connection to a `CBPeripheral`
    /// - Parameter peripheral: The `CBPeripheral ` instance to open a connection to
    /// - Returns: A publisher to emits when a connection as been opened, or errors
    func connect(to peripheral: CBPeripheral) -> AnyPublisher<CBPeripheral, Error> {
        peripheralConnectionPublisher?.send(completion: .finished)
        
        let publisher = PassthroughSubject<CBPeripheral, Error>()
        peripheralConnectionPublisher = publisher
        
        manager.connect(peripheral, options: [:])
        
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
            packet: advertisementData as! [String: AnyHashable],
            rssi: RSSI.doubleValue,
            timestamp: Date()
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
