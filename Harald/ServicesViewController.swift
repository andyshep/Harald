//
//  ServicesViewController.swift
//  Harald
//
//  Created by Andrew Shepard on 4/14/18.
//  Copyright © 2018 Andrew Shepard. All rights reserved.
//

import Foundation
import AppKit
import CoreBluetooth
import Combine

class ServicesViewController: NSViewController {
    
    private enum GeneralError: Error {
        case peripheralProxyIsNil
    }
    
    private var cancellables: [AnyCancellable] = []
    private var peripheralCancellables: [AnyCancellable] = []
    
    // MARK: Inputs
    
    public let reloadEvent = PassthroughSubject<Void, Never>()
    public let exportEvent = PassthroughSubject<Void, Never>()
    
    // MARK: Public
    
    @IBOutlet weak var outlineView: NSOutlineView!
    
    public var manager: CBCentralManager?
    public var peripheral: CBPeripheral?
    
    lazy var servicesController: NSTreeController = {
        let controller = NSTreeController()
        
        controller.bind(NSBindingName.content, to: self, withKeyPath: "services")
        controller.childrenKeyPath = "characteristics"
        controller.leafKeyPath = "isLeaf"
        
        return controller
    }()
    
    @objc var services: [DataNode] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        outlineView.bind(.content, to: servicesController, withKeyPath: "arrangedObjects")
        outlineView.bind(.selectionIndexPaths, to: servicesController, withKeyPath: "selectionIndexPaths")
        
        outlineView.itemWillExpandPublisher
            .sink { [weak self] _ in
                self?.willChangeValue(for: \.services)
            }
            .store(in: &cancellables)
        
        outlineView.itemDidExpandPublisher
            .sink { [weak self] _ in
                self?.didChangeValue(for: \.services)
            }
            .store(in: &cancellables)
        
        reloadEvent
            .sink { [weak self] _ in
                self?.representedObject = nil
            }
            .store(in: &cancellables)
        
        exportEvent
            .sink { _ in
                // TODO: implement
            }
            .store(in: &cancellables)
    }
    
    override var representedObject: Any? {
        didSet {
            self.willChangeValue(for: \.services)
            self.services = []
            self.didChangeValue(for: \.services)
            
            guard let peripherial = representedObject as? CBPeripheral else {
                return
            }
            
            if let oldPeripheral = oldValue as? CBPeripheral {
                // close any previous connections
                manager?.cancelPeripheralConnection(oldPeripheral)
                
                if peripherial != oldPeripheral {
                    // update
                    bind(to: peripherial)
                } else {
                    print("not updating")
                }
            } else {
                // update
                bind(to: peripherial)
            }
        }
    }
}

private extension ServicesViewController {
    private func reloadServiceNodes(using services: [CBService]) {
        let nodes = services.compactMap { ServiceNode(service: $0) }
        
        self.willChangeValue(for: \.services)
        self.services = nodes
        self.didChangeValue(for: \.services)
    }
    
    private func updateCharacteristics(_ characteristics: [CBCharacteristic], for service: CBService) {
        // create the characteristic nodes
        let characteristics = characteristics.compactMap { characteristic -> CharacteristicNode in
            let node = CharacteristicNode(characteristic: characteristic)
            return node
        }
        
        let node = services.first { (node) -> Bool in
            guard let current = node as? ServiceNode else { return false }
            return current.service == service
        }
        
        guard let serviceNode = node as? ServiceNode else { return }
        
        serviceNode.willChangeValue(for: \ServiceNode.characteristics)
        serviceNode.characteristics = characteristics
        serviceNode.didChangeValue(for: \ServiceNode.characteristics)
    }
    
    private func bind(to peripheral: CBPeripheral) {
        peripheralCancellables.forEach { $0.cancel() }
        peripheralCancellables = []
        
        manager?.connect(to: peripheral)
            // once connected, ask the peripheral to discover *and* publish services
            .flatMap { peripheral -> AnyPublisher<[CBService], Error> in
                return peripheral.discoveredServicesPublisher
            }
            // set the initial response containing services without charactertics
            .do(onNext: { [weak self] (services) in
                self?.reloadServiceNodes(using: services)
            })
            // discover characteristics for each service by returning
            // an observable tuple stream of services and characteristics
            .flatMap { (services) -> AnyPublisher<(CBService, [CBCharacteristic]), Error> in
                let characteristics = services.compactMap { $0.discoveredCharacteristics }
                return Publishers.MergeMany(characteristics).eraseToAnyPublisher()
            }
            // update the service nodes with the characteristics (after they are discovered)
            .do(onNext: { [weak self] (service, characteristics) in
                guard let this = self else { return }
                
                // initiate a call to read each charactertistics value
                // this will come back later through another Rx pipeline
                characteristics.forEach { peripheral.readValue(for: $0) }

                this.updateCharacteristics(characteristics, for: service)
                this.outlineView.expandItem(nil, expandChildren: true)
            })
            .subscribe(andStoreIn: &cancellables)
    }
}
