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

class PeripheralsViewController: NSViewController {
    
//    public let reloadEvent = PublishSubject<Void>()
    
    private var cancelables: [AnyCancellable] = []
    
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var statusTextField: NSTextField!
    
    @objc private var discovered: [DiscoveredPeripheral] = []
    
    public var proxy: CentralManagerProxy? {
        didSet {
            guard let proxy = proxy else { return }
            bind(to: proxy)
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
        
//        reloadEvent
//            .asDriver(onErrorDriveWith: Driver.never())
//            .drive(onNext: { [weak self] _ in
//                guard let this = self else { return }
//
//                this.closeActiveConnections()
//                this.manager?.stopScan()
//
//                this.willChangeValue(for: \.discovered)
//                this.discovered = []
//                this.didChangeValue(for: \.discovered)
//
//                this.manager?.scanForPeripherals(withServices: nil)
//            })
//            .disposed(by: bag)
    }
}

extension PeripheralsViewController {
    func bind(to proxy: CentralManagerProxy) {
        
        proxy.peripheralPublisher
            .compactMap { (result) -> DiscoveredPeripheral? in
                switch result {
                case .success(let info):
                    return DiscoveredPeripheral(discovery: info)
                case .failure:
                    return nil
                }
            }
            .sink { [weak self] discovery in
                guard let this = self else { return }
                guard let _ = discovery.peripheral.name else { return }

                if !this.discovered.contains(discovery) {
                    this.willChangeValue(for: \.discovered)
                    this.discovered.append(discovery)
                    this.didChangeValue(for: \.discovered)
                }
            }
            .store(in: &cancelables)
        
        proxy.statePublisher
            .filter { $0 == .poweredOn }
            // once the manager is powered on, begin periodic scanning
            .prefix(1)
            // start a 25 second period timer
            .flatMap { _ -> AnyPublisher<Double, Never> in
                return RepeatableIntervalTimer(interval: 25.0)
                    .eraseToAnyPublisher()
            }
            // begin scanning whenever to timer fires
            .do(onNext: { [weak self] in
                print("starting scan...")
                self?.proxy?.manager.scanForPeripherals(withServices: nil)
            })
            // each time we start scanning, start another one-time 10 second timer
            .flatMapLatest { _ -> AnyPublisher<Double, Never> in
                return SingleIntervalTimer(interval: 10.0)
                    .eraseToAnyPublisher()
            }
            // stop scanning once the second timer fires
            .do(onNext: { [weak self] in
                print("stopping scan...")
                self?.proxy?.manager.stopScan()
            })
            // subscribe (and repeat)
            .sink(receiveValue: { _ in } )
            .store(in: &cancelables)
    }
    
    func bind(to arrayController: NSArrayController) {
        arrayController
            .arrangedObjectsPublisher
            .map { [weak self] _ -> Int in
                guard let controller = self?.peripheralsController else { return 0 }
                guard let objects = controller.arrangedObjects as? [AnyObject] else { return 0 }
                return objects.count
            }
            .map { discoveryDescriptor(with: $0) }
            .sink { [weak self] (result) in
                self?.statusTextField.stringValue = result
            }
            .store(in: &cancelables)
    }
}

extension PeripheralsViewController {
    private func closeActiveConnections() {
        guard let discovered = peripheralsController.selectedObjects.first as? DiscoveredPeripheral else { return }
        proxy?.manager.cancelPeripheralConnection(discovered.peripheral)
    }
}

private extension CBPeripheral {
    @objc var displayName: String {
        guard let name = self.name else {
            return "Unknown"
        }
        
        return name.trimmingLowEnergyPrefix
    }
}

private func discoveryDescriptor(with count: Int) -> String {
    switch count {
    case 0:
        return "No peripherals discovered"
    case 1:
        return "1 peripheral discovered"
    default:
        return "\(count) peripherals discovered"
    }
}

private extension String {
    var trimmingLowEnergyPrefix: String {
        if self.prefix(3) == "LE-" {
            return String(self.dropFirst(3))
        } else {
            return self
        }
    }
}
