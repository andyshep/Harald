//
//  PeripheralsViewController.swift
//  Harald
//
//  Created by Andrew Shepard on 2/24/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Cocoa
import CoreBluetooth
import Combine
import OSLog

final class PeripheralsViewController: NSViewController {
    
    private var cancellables = Set<AnyCancellable>()
    
    public var reloadEvent = PassthroughSubject<Void, Never>()
    
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var statusTextField: NSTextField!
    
    @objc private var discovered: [DiscoveredPeripheral] = []
    
    public var searchTermChanged: AnySubscriber<String, Never> {
        return AnySubscriber(_searchTermChanged)
    }
    private let _searchTermChanged = PassthroughSubject<String, Never>()
    
    public var manager: CBCentralManager? {
        didSet {
            guard let manager = manager else { return }
            bind(to: manager)
        }
    }
    
    lazy var peripheralsController: NSArrayController = {
        let controller = NSArrayController()
        controller.bind(.contentArray, to: self, withKeyPath: "discovered")
        
        return controller
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.bind(.content, to: peripheralsController, withKeyPath: "arrangedObjects")
        tableView.bind(.selectionIndexes, to: peripheralsController, withKeyPath: "selectionIndexes")
        
        bind(to: peripheralsController)
        
        reloadEvent
            .sink { [weak self] _ in
                guard let this = self else { return }

                this.closeActiveConnections()
                this.manager?.stopScan()

                this.willChangeValue(for: \.discovered)
                this.discovered = []
                this.didChangeValue(for: \.discovered)

                this.manager?.scanForPeripherals(withServices: nil)
            }
            .store(in: &cancellables)
        
        _searchTermChanged
            .eraseToAnyPublisher()
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .map { string -> NSPredicate? in
                guard string.count != 0 else { return nil }
                return NSPredicate(format: "peripheral.displayName contains[c] %@", string)
            }
            .sink { [weak self] predicate in
                self?.peripheralsController.filterPredicate = predicate
            }
            .store(in: &cancellables)
    }
}

extension PeripheralsViewController {
    func bind(to manager: CBCentralManager) {
        manager.peripheralCachePublisher
            .map { $0.map { DiscoveredPeripheral(discovery: $0) } }
            .sink { [weak self] (discovery) in
                guard let this = self else { return }
                
                this.willChangeValue(for: \.discovered)
                this.discovered = discovery
                this.didChangeValue(for: \.discovered)
            }
            .store(in: &cancellables)
        
        manager.statePublisher
            .filter { $0 == .poweredOn }
            // once the manager is powered on, begin periodic scanning
            .prefix(1)
            // start a 25 second repeating timer
            .flatMap { _ -> AnyPublisher<Double, Never> in
                return RepeatableIntervalTimer(interval: 25.0)
                    .eraseToAnyPublisher()
            }
            // begin scanning whenever the timer fires
            .do(onNext: { [weak self] in
                os_log("%s: starting scan...", log: OSLog.bluetooth, type: .debug, "\(#function)")
                self?.manager?.scanForPeripherals(
                    withServices: nil,
                    options: [
                        CBCentralManagerScanOptionAllowDuplicatesKey: false,
                        CBConnectPeripheralOptionNotifyOnConnectionKey: true,
//                        CBConnectPeripheralOptionNotifyOnDisconnectionKey: false,
//                        CBConnectPeripheralOptionNotifyOnNotificationKey: false
                    ]
                )
            })
            // each time we start scanning, start another one-time 10 second timer
            .flatMap { _ -> AnyPublisher<Double, Never> in
                return SingleIntervalTimer(interval: 10.0)
                    .eraseToAnyPublisher()
            }
            // stop scanning once the second timer fires
            .do(onNext: { [weak self] in
                os_log("%s: stopping scan.", log: OSLog.bluetooth, type: .debug, "\(#function)")
                self?.manager?.stopScan()
            })
            .subscribe(andStoreIn: &cancellables)
    }
    
    func bind(to arrayController: NSArrayController) {
        arrayController
            .arrangedObjectsPublisher
            .map { [weak self] _ -> Int in
                guard let controller = self?.peripheralsController else { return 0 }
                guard let objects = controller.arrangedObjects as? [AnyObject] else { return 0 }
                return objects.count
            }
            .map { $0.discoveryDescriptor }
            .sink { [weak self] (result) in
                self?.statusTextField.stringValue = result
            }
            .store(in: &cancellables)
    }
}

extension PeripheralsViewController {
    private func closeActiveConnections() {
        guard let discovered = peripheralsController.selectedObjects.first as? DiscoveredPeripheral else { return }
        manager?.cancelPeripheralConnection(discovered.peripheral)
    }
}

private extension CBPeripheral {
    @objc var displayName: String {
        guard let name = name else { return "Unknown" }
        return name // .trimmingLowEnergyPrefix
    }
}

private extension Int {
    var discoveryDescriptor: String {
        switch self {
        case 0:
            return "No peripherals discovered"
        case 1:
            return "1 peripheral discovered"
        default:
            return "\(self) peripherals discovered"
        }
    }
}

private extension String {
    var trimmingLowEnergyPrefix: String {
        if prefix(3) == "LE-" {
            return String(dropFirst(3))
        } else {
            return self
        }
    }
}
