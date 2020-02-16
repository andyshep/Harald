//
//  PeripheralsViewController.swift
//  Harald
//
//  Created by Andrew Shepard on 2/24/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Cocoa
import CoreBluetooth
import RxSwift
import RxCocoa

class PeripheralsViewController: NSViewController {
    
    public let reloadEvent = PublishSubject<Void>()
    
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var statusTextField: NSTextField!
    
    @objc private var discovered: [DiscoveredPeripheral] = []
    
    private let bag = DisposeBag()
    
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
            .asDriver(onErrorDriveWith: Driver.never())
            .drive(onNext: { [weak self] _ in
                guard let this = self else { return }
                
                this.closeActiveConnections()
                this.manager?.stopScan()
                
                this.willChangeValue(for: \.discovered)
                this.discovered = []
                this.didChangeValue(for: \.discovered)
                
                this.manager?.scanForPeripherals(withServices: nil)
            })
            .disposed(by: bag)
    }
}

extension PeripheralsViewController {
    func bind(to manager: CBCentralManager) {
        manager.rx.discoveredPeripheral
            .map { DiscoveredPeripheral(discovery: $0) }
            .asDriver(onErrorDriveWith: Driver.never())
            .drive(onNext: { [weak self] (discovery) in
                guard let this = self else { return }
                guard let _ = discovery.peripheral.name else { return }
                
                if !this.discovered.contains(discovery) {
                    this.willChangeValue(for: \.discovered)
                    this.discovered.append(discovery)
                    this.didChangeValue(for: \.discovered)
                }
            })
            .disposed(by: bag)
        
        manager.rx.state
            .startWith(CBManagerState.unknown)
            .filter { $0 == .poweredOn }
            // once the manager is powered on, begin periodic scanning
            .take(1)
            // start a 15 second period timer
            .flatMapLatest { _ -> Observable<Int> in
                return Observable<Int>.timer(.seconds(0), period: .seconds(15), scheduler: MainScheduler.instance)
            }
            // begin scanning whenever to timer fires
            .do(onNext: { [weak self] (_) in
                self?.manager?.scanForPeripherals(withServices: nil)
            })
            // each time we start scanning, start another one-time 10 second timer
            .flatMapLatest({ _ -> Observable<Int> in
                return Observable<Int>.timer(.seconds(10), scheduler: MainScheduler.instance)
            })
            // stop scanning once to second timer fires
            .do(onNext: { [weak self] (_) in
                self?.manager?.stopScan()
            })
            // subscribe (and repeat)
            .subscribe()
            .disposed(by: bag)
    }
    
    func bind(to arrayController: NSArrayController) {
        arrayController
            .rx
            .observeWeakly([AnyObject].self, "arrangedObjects", options: [.initial, .new])
            .map { [weak self] _ -> Int in
                guard let controller = self?.peripheralsController else { return 0 }
                guard let objects = controller.arrangedObjects as? [AnyObject] else { return 0 }
                return objects.count
            }
            .map { discoveryDescriptor(with: $0) }
            .asDriver(onErrorJustReturn: "No peripherals discovered")
            .drive(onNext: { [weak self] (result) in
                self?.statusTextField.stringValue = result
            })
            .disposed(by: bag)
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
